# Optional sequential orchestration. Importing defines helpers only.
# Explicit lists preserve repeats; optional folder snapshots supply skip reasons.
function Read-WacInputList {
    param([Parameter(Mandatory = $true)][string]$Path)
    $resolved = Assert-WacSettingsPath -Path $Path
    Initialize-WacNativeFileIO
    Initialize-WacSettingsTypes
    $stream = $null
    try {
        $stream = [WinAudioClean.SettingsFileIO]::Open($resolved, $false)
        if ([WinAudioClean.NativeFileIO]::ResolvedPath($stream.SafeFileHandle) -ine $resolved) {
            throw 'Input-list path changed or was redirected.'
        }
        if ($stream.Length -gt 1048576) { throw 'Input list exceeds the 1 MiB limit. Split it into smaller manifests.' }
        $bytes = [byte[]]::new([int]$stream.Length)
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $read = $stream.Read($bytes, $offset, $bytes.Length - $offset)
            if ($read -eq 0) { throw 'Input list could not be read completely.' }
            $offset += $read
        }
        $start = if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { 3 } else { 0 }
        try { $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes, $start, $bytes.Length - $start) }
        catch { throw 'Input list must contain valid UTF-8 JSON.' }
        try { $document = [WinAudioClean.SettingsJson]::Parse($text) }
        catch { throw ('Invalid input-list JSON: ' + $_.Exception.GetBaseException().Message) }
        if ($document -isnot [System.Collections.IDictionary] -or $document.Count -ne 2 -or
            -not $document.ContainsKey('schemaVersion') -or -not $document.ContainsKey('inputs') -or
            $document['schemaVersion'] -isnot [long] -or $document['schemaVersion'] -ne 1 -or
            $document['inputs'] -isnot [object[]]) {
            throw 'Input list requires exactly schemaVersion integer 1 and an inputs array.'
        }
        $inputs = $document['inputs']
        if ($inputs.Count -lt 1 -or $inputs.Count -gt 1024) { throw 'Input list requires 1 through 1024 paths. Split larger lists into manifests.' }
        foreach ($input in $inputs) {
            if ($input -isnot [string] -or [string]::IsNullOrWhiteSpace($input)) { throw 'Every input-list entry must be a nonempty path string.' }
        }
        $parent = [IO.Path]::GetDirectoryName($resolved)
        foreach ($input in $inputs) {
            # Keep invalid filesystem/provider/URL strings as per-item failures;
            # anchor only ordinary relative paths to the manifest's directory.
            if ($input -match '^[a-zA-Z]:|^[\\/]{2}|^[a-zA-Z][a-zA-Z0-9+.-]*:|::') { $input }
            elseif ($input -match '^[\\/]') { [IO.Path]::GetPathRoot($parent) + $input.TrimStart([char[]]'\/') }
            else { $parent.TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar + $input }
        }
    } finally { if ($null -ne $stream) { $stream.Dispose() } }
}

function Resolve-WacBatchInputs {
    param([Parameter(Mandatory = $true)][System.Collections.IDictionary]$Parameters)
    if (($Parameters.Keys -contains 'inputPath') -or
        (($Parameters.Keys -contains 'InputPaths') -eq ($Parameters.Keys -contains 'InputListPath'))) {
        throw 'Supply exactly one of InputPaths or InputListPath, without inputPath.'
    }
    if ($Parameters.Keys -contains 'InputListPath') { Read-WacInputList -Path $Parameters.InputListPath; return }
    $inputs = @($Parameters.InputPaths)
    if ($inputs.Count -lt 1 -or $inputs.Count -gt 1024) { throw 'InputPaths requires 1 through 1024 paths. Use smaller input-list manifests.' }
    foreach ($input in $inputs) {
        if ($input -isnot [string] -or [string]::IsNullOrWhiteSpace($input)) { throw 'Every InputPaths entry must be a nonempty path string.' }
    }
    $json = ConvertTo-Json -InputObject $inputs -Compress
    if ([Text.UTF8Encoding]::new($false, $true).GetByteCount($json) -gt 1048576) { throw 'InputPaths exceeds the 1 MiB limit. Split the list into smaller manifests.' }
    $inputs
}

function Add-WacBatchRecord {
    param([Parameter(Mandatory = $true)]$Writer, [Parameter(Mandatory = $true)]$Record)
    Assert-WacReportWriter -Writer $Writer
    if (-not $Writer.CreatedNew) { throw 'Batch results require an exclusively created journal.' }
    $content = ($Record | ConvertTo-Json -Depth 10 -Compress) + "`r`n"
    $bytes = $Writer.Encoding.GetBytes($content)
    $length = $Writer.Stream.Length
    try {
        $Writer.Stream.Position = $length
        $Writer.Stream.Write($bytes, 0, $bytes.Length)
        $Writer.Stream.Flush($true)
    } catch {
        $failure = $_
        try { $Writer.Stream.SetLength($length); $Writer.Stream.Flush($true) }
        catch { throw ('Batch journal append failed and its new suffix could not be rolled back: ' + $_.Exception.Message) }
        throw $failure
    }
}

function Invoke-WacBatchItem {
    param([Parameter(Mandatory = $true)][string]$ApplicationPath,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Arguments)
    $diagnostics = New-Object 'System.Collections.Generic.List[string]'
    $remaining = 4096
    $informationTail = ''
    $code = 4
    try {
        $global:LASTEXITCODE = 4
        & $ApplicationPath @Arguments 2>&1 6>&1 | ForEach-Object {
            if ($_ -is [Management.Automation.ErrorRecord]) {
                if ($remaining -gt 0) {
                    $message = $_.Exception.Message
                    $message = $message.Substring(0, [Math]::Min($remaining, $message.Length))
                    if ($message.Length -gt 0 -and [char]::IsHighSurrogate($message[$message.Length - 1])) { $message = $message.Substring(0, $message.Length - 1) }
                    $diagnostics.Add($message); $remaining -= $message.Length
                }
                Write-Error -Message $_.Exception.Message -ErrorAction Continue
            } elseif ($_ -is [Management.Automation.InformationRecord]) {
                $informationTail += ([string]$_.MessageData + "`n")
                if ($informationTail.Length -gt 4096) { $informationTail = $informationTail.Substring($informationTail.Length - 4096) }
                if ($_.MessageData -is [Management.Automation.HostInformationMessage]) {
                    $hostMessage = $_.MessageData
                    $relay = @{ Object = $hostMessage.Message; NoNewline = $hostMessage.NoNewLine }
                    if ($null -ne $hostMessage.ForegroundColor) { $relay.ForegroundColor = $hostMessage.ForegroundColor }
                    if ($null -ne $hostMessage.BackgroundColor) { $relay.BackgroundColor = $hostMessage.BackgroundColor }
                    Write-Host @relay
                } else {
                    # PS-prefixed tags are reserved by Write-Information.
                    Write-Information -MessageData $_.MessageData -InformationAction Continue
                }
            } else { Write-Host ([string]$_) }
        }
        $code = $LASTEXITCODE
        if ($code -ne 0 -and $diagnostics.Count -eq 0) {
            $message = "Application exited with code $code."
            $diagnostics.Add($message)
            $budget = 4096 - $message.Length
            $tail = $informationTail.Trim()
            if ($tail.Length -gt $budget) { $tail = $tail.Substring($tail.Length - $budget) }
            if ($tail.Length -gt 0 -and [char]::IsLowSurrogate($tail[0])) { $tail = $tail.Substring(1) }
            if ($tail) { $diagnostics.Add($tail) }
        }
    } catch {
        $message = $_.Exception.Message
        $bounded = $message.Substring(0, [Math]::Min($remaining, $message.Length))
        if ($bounded.Length -gt 0 -and [char]::IsHighSurrogate($bounded[$bounded.Length - 1])) { $bounded = $bounded.Substring(0, $bounded.Length - 1) }
        $diagnostics.Add($bounded)
        Write-Error -Message ('Batch item failed unexpectedly: ' + $message) -ErrorAction Continue
    }
    [pscustomobject]@{ ExitCode = [int]$code; Diagnostics = @($diagnostics.ToArray()) }
}

function Get-WacBatchExitCode {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Items, [switch]$Folder)
    if (@($Items | Where-Object { $_.status -eq 'CANCELLED' }).Count -gt 0) { return 130 }
    if (-not $Folder -and $Items.Count -eq 1) { return [int]$Items[0].exitCode }
    if (@($Items | Where-Object { $_.status -eq 'FAILED' }).Count -gt 0) { return 6 }
    if (@($Items | Where-Object { $_.status -eq 'WARNING' }).Count -gt 0) { return 7 }
    0
}

function Invoke-WacBatch {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Inputs,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Parameters,
        [Parameter(Mandatory = $true)]$ResolvedSettings,
        [Parameter(Mandatory = $true)][string]$ApplicationPath, $FolderQueue)
    $isFolder = $null -ne $FolderQueue
    if ($isFolder -and $FolderQueue.Entries.Count -ne $Inputs.Count) { throw 'Folder queue and input count differ.' }
    $hasPending = -not $isFolder -or @($FolderQueue.Entries | Where-Object { $_.Status -eq 'PENDING' }).Count -gt 0
    $options = @{}
    foreach ($name in $ResolvedSettings.Values.Keys) {
        if ($null -ne $ResolvedSettings.Values[$name]) { $options[$name] = $ResolvedSettings.Values[$name] }
    }
    $interactive = Test-WacInteractive -NonInteractive:([bool]$Parameters.NonInteractive)
    if ($hasPending -and -not $options.Mode -and -not $interactive) { throw 'A mode is required for unattended use. Supply -Mode Raw or -Mode Zoom, or save a mode.' }
    $outputFolder = Get-WacOutputDirectory -Path $options.OutputDirectory
    $options.OutputDirectory = $outputFolder
    $id = [guid]::NewGuid().ToString('N')
    $path = if ($Parameters.Keys -contains 'BatchResultPath') { Resolve-WacFileSystemPath -Path $Parameters.BatchResultPath }
        else { [IO.Path]::Combine($outputFolder, ('WinAudioClean_Batch_' + $id + '.jsonl')) }
    $directory = $null; $writer = $null
    $items = New-Object 'System.Collections.Generic.List[object]'
    $exitCode = 0; $cancelled = $false; $reportingComplete = $false
    $origins = @{}
    foreach ($name in $ResolvedSettings.Origins.Keys) { $origins[$name] = $ResolvedSettings.Origins[$name] }
    if ($hasPending -and -not $options.Mode) {
        Write-Host "Select one processing mode for all $($Inputs.Count) inputs: [1] Raw; [2] Zoom/Teams; [Q] Cancel."
        $options.Mode = Read-WacMode
        if (-not $options.Mode) { $cancelled = $true }
        else { $origins.Mode = 'Interactive' }
    }
    if (-not $cancelled) { Assert-WacSettingsCombination -Values $options }
    try {
        try {
            foreach ($input in $Inputs) {
                $candidate = $null
                try { $candidate = Resolve-WacFileSystemPath -Path $input }
                catch { $candidate = $null } # Ordinary per-item validation reports invalid paths.
                if ($candidate -and $candidate -ieq $path) { throw 'Batch result journal must differ from every requested input.' }
            }
            Initialize-WacNativeFileIO
            $directory = [WinAudioClean.NativeFileIO]::OpenDirectory([IO.Path]::GetDirectoryName($path))
            $writer = Open-WacReportWriter -Path $path -CreateNew
            if ([IO.Path]::GetDirectoryName($writer.Path) -ine [WinAudioClean.NativeFileIO]::ResolvedPath($directory)) {
                throw 'Batch result directory changed or was redirected.'
            }
            $path = $writer.Path
        } catch { Write-Error -Message ('Cannot create batch result journal: ' + $_.Exception.Message) -ErrorAction Continue; return [pscustomobject]@{ ExitCode = 5; ResultPath = $path; ReportingComplete = $false } }
        $displayOptions = @{}
        foreach ($name in $options.Keys) { $displayOptions[$name] = $options[$name] }
        $header = [ordered]@{ type = 'batch'; schemaVersion = $(if ($isFolder) { 2 } else { 1 }); batchId = $id; startedAt = [DateTime]::UtcNow.ToString('o')
            inputCount = $Inputs.Count; settings = (ConvertTo-WacSettingsJson -Values $displayOptions | ConvertFrom-Json).settings
            origins = $origins }
        if ($isFolder) {
            $header.selection = [ordered]@{ kind = 'folders'; directories = @($FolderQueue.Directories); recurse = [bool]$FolderQueue.Recurse
                extensions = @($FolderQueue.Extensions); capturedAt = $FolderQueue.CapturedAt }
        }
        Add-WacBatchRecord -Writer $writer -Record $header
        $options.IgnoreSavedSettings = $true
        if ($Parameters.Keys -contains 'NonInteractive') { $options.NonInteractive = [bool]$Parameters.NonInteractive }
        foreach ($name in @('FfmpegPath', 'FfprobePath')) { if ($Parameters.Keys -contains $name) { $options[$name] = $Parameters[$name] } }
        for ($index = 0; $index -lt $Inputs.Count; $index++) {
            $item = [ordered]@{ type = 'item'; index = $index + 1; inputPath = $Inputs[$index]
                status = 'NOT_STARTED'; exitCode = $null; diagnostics = @(); finishedAt = $null }
            $entry = $null
            if ($isFolder) {
                $entry = $FolderQueue.Entries[$index]
                $item.reasonCode = $entry.ReasonCode; $item.sourceIdentity = $entry.Identity
                $item.sourceLength = $entry.Length; $item.sourceLastWriteTimeUtc = $entry.LastWriteTimeUtc
                if ($entry.Status -in @('SKIPPED', 'FAILED')) {
                    $item.status = $entry.Status; $item.exitCode = $(if ($entry.Status -eq 'FAILED') { 2 } else { $null })
                    $item.diagnostics = @($entry.Diagnostics); $item.finishedAt = [DateTime]::UtcNow.ToString('o')
                    Write-Host ("{0}: {1} ({2})" -f $item.status, $item.inputPath, $item.reasonCode)
                }
            }
            if (-not $cancelled -and ($null -eq $entry -or $entry.Status -eq 'PENDING')) {
                Write-Host ("Processing input {0} of {1}: {2}" -f ($index + 1), $Inputs.Count, $Inputs[$index])
                $arguments = @{}
                foreach ($name in $options.Keys) { $arguments[$name] = $options[$name] }
                $arguments.inputPath = $Inputs[$index]
                $lease = $null; $result = $null
                try {
                    if ($isFolder) {
                        try { $lease = Open-WacQueuedInput -Entry $entry }
                        catch {
                            $item.reasonCode = 'source_changed'
                            $result = [pscustomobject]@{ ExitCode = 2; Diagnostics = @('Queued source is no longer available with its captured identity, size and modification time: ' + $_.Exception.GetBaseException().Message) }
                        }
                    }
                    if ($null -eq $result) { $result = Invoke-WacBatchItem -ApplicationPath $ApplicationPath -Arguments $arguments }
                } finally { if ($isFolder) { Close-WacQueuedInput -Lease $lease } }
                $item.exitCode = $result.ExitCode
                $item.diagnostics = @($result.Diagnostics)
                $item.status = switch ($result.ExitCode) { 0 { 'SUCCESS' } 7 { 'WARNING' } 130 { 'CANCELLED' } default { 'FAILED' } }
                if ($result.ExitCode -eq 130) { $cancelled = $true }
                $item.finishedAt = [DateTime]::UtcNow.ToString('o')
            }
            $items.Add($item)
            Add-WacBatchRecord -Writer $writer -Record $item
        }
        $exitCode = if ($cancelled) { 130 } else { Get-WacBatchExitCode -Items $items.ToArray() -Folder:$isFolder }
        $counts = [ordered]@{ success = 0; warning = 0; failed = 0; cancelled = 0; notStarted = 0 }
        if ($isFolder) { $counts.skipped = 0 }
        foreach ($item in $items) {
            $key = switch ($item.status) { 'SUCCESS' { 'success' } 'WARNING' { 'warning' } 'FAILED' { 'failed' } 'CANCELLED' { 'cancelled' } 'SKIPPED' { 'skipped' } default { 'notStarted' } }
            $counts[$key]++
        }
        $status = switch ($exitCode) { 0 { 'SUCCESS' } 7 { 'WARNING' } 130 { 'CANCELLED' } default { 'FAILED' } }
        Add-WacBatchRecord -Writer $writer -Record ([ordered]@{ type = 'summary'; status = $status; exitCode = $exitCode
            counts = $counts; finishedAt = [DateTime]::UtcNow.ToString('o'); reportingComplete = $true })
        $reportingComplete = $true
        if ($isFolder) { Write-Host ("Folder summary: {0} successful, {1} warning, {2} failed, {3} skipped, {4} cancelled, {5} not started." -f $counts.success, $counts.warning, $counts.failed, $counts.skipped, $counts.cancelled, $counts.notStarted) }
        Write-Host ('Batch results saved to: ' + $path)
    } catch {
        Write-Error -Message ('Batch stopped; result journal is incomplete. Prior outputs/results are retained: ' + $_.Exception.Message) -ErrorAction Continue
        $exitCode = 5
    } finally {
        if ($null -ne $writer) {
            try { Close-WacReportWriter -Writer $writer }
            catch { Write-Warning ('Batch journal handle could not be closed: ' + $_.Exception.Message) }
        }
        if ($null -ne $directory) {
            try { $directory.Dispose() }
            catch { Write-Warning ('Batch directory handle could not be closed: ' + $_.Exception.Message) }
        }
    }
    [pscustomobject]@{ ExitCode = $exitCode; ResultPath = $path; ReportingComplete = $reportingComplete }
}
