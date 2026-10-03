# Optional folder selection. Importing defines helpers only; no traversal occurs.
function Initialize-WacQueueFileIO {
    if ('WinAudioClean.QueueFileIO' -as [type]) { return }
    Initialize-WacNativeFileIO
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace WinAudioClean {
    public static class QueueFileIO {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern SafeFileHandle CreateFileW(string name, uint access, uint share,
            IntPtr security, uint disposition, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetFileInformationByHandleEx(SafeFileHandle file, int kind,
            IntPtr information, uint size);
        private static SafeFileHandle Open(string path, bool directory) {
            // OPEN_REPARSE_POINT inspects the named entry itself. Held ordinary
            // ancestors prevent a parent from being replaced during traversal.
            SafeFileHandle handle = CreateFileW(path, 0x80000000, directory ? 3u : 1u,
                IntPtr.Zero, 3, 0x00200000 | (directory ? 0x02000000u : 0u), IntPtr.Zero);
            if (handle.IsInvalid) {
                int code = Marshal.GetLastWin32Error(); handle.Dispose();
                throw new IOException("Cannot hold queue source: " + new Win32Exception(code).Message);
            }
            IntPtr info = Marshal.AllocHGlobal(8);
            try {
                if (!GetFileInformationByHandleEx(handle, 9, info, 8))
                    throw new IOException("Cannot inspect queue source attributes.");
                uint attributes = unchecked((uint)Marshal.ReadInt32(info));
                if ((attributes & 0x400) != 0) throw new IOException("Queue sources cannot traverse reparse points.");
                if (((attributes & 0x10) != 0) != directory) throw new IOException("Queue source has the wrong entry type.");
                return handle;
            } catch { handle.Dispose(); throw; }
            finally { Marshal.FreeHGlobal(info); }
        }
        public static SafeFileHandle OpenDirectory(string path) { return Open(path, true); }
        public static FileStream OpenInput(string path) {
            SafeFileHandle handle = Open(path, false);
            try { return new FileStream(handle, FileAccess.Read); }
            catch { handle.Dispose(); throw; }
        }
    }
}
'@
}

function Resolve-WacFolderSelection {
    param([Parameter(Mandatory = $true)][System.Collections.IDictionary]$Parameters)
    if (-not ($Parameters.Keys -contains 'InputDirectories') -or
        @('inputPath', 'InputPaths', 'InputListPath' | Where-Object { $Parameters.Keys -contains $_ }).Count -gt 0) {
        throw 'Supply InputDirectories without inputPath, InputPaths or InputListPath. Recurse requires InputDirectories.'
    }
    $directories = @($Parameters.InputDirectories)
    if ($directories.Count -lt 1 -or $directories.Count -gt 64) { throw 'InputDirectories requires 1 through 64 folders.' }
    foreach ($directory in $directories) {
        if ($directory -isnot [string] -or [string]::IsNullOrWhiteSpace($directory)) { throw 'Every InputDirectories entry must be a nonempty path string.' }
        $full = [IO.Path]::GetFullPath((Resolve-WacFileSystemPath -Path $directory))
        if ($full -ine [IO.Path]::GetPathRoot($full)) { $full = $full.TrimEnd([char[]]'\/') }
        $full
    }
}

function Add-WacQueueDirectory {
    param([Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Handles)
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    $chain = New-Object 'System.Collections.Generic.List[string]'
    $chain.Add($root)
    $current = $root
    foreach ($part in $full.Substring($root.Length).TrimEnd([char[]]'\/').Split([char[]]'\/', [StringSplitOptions]::RemoveEmptyEntries)) {
        $current = [IO.Path]::Combine($current, $part); $chain.Add($current)
    }
    foreach ($directory in $chain) {
        if ($Handles.Contains($directory)) { continue }
        if ($Handles.Count -ge 2048) { throw 'Folder queue exceeds 2048 held ancestor directories. Select a smaller tree.' }
        $handle = [WinAudioClean.QueueFileIO]::OpenDirectory($directory)
        try {
            $resolved = [WinAudioClean.NativeFileIO]::ResolvedPath($handle)
            if ($resolved.TrimEnd([char[]]'\/') -ine $directory.TrimEnd([char[]]'\/')) { throw 'Queue directory changed or was redirected.' }
            $Handles[$directory] = $handle
        } catch { $handle.Dispose(); throw }
    }
    $Handles[$current]
}

function Close-WacQueuedInput {
    param($Lease)
    if ($null -eq $Lease) { return }
    try { if ($null -ne $Lease.Stream) { $Lease.Stream.Dispose() } }
    finally { foreach ($handle in $Lease.DirectoryHandles.Values) { $handle.Dispose() } }
}

function Open-WacQueuedInput {
    param([Parameter(Mandatory = $true)]$Entry)
    Initialize-WacQueueFileIO
    $lease = [pscustomobject]@{ Stream = $null; DirectoryHandles = @{} }
    try {
        $null = Add-WacQueueDirectory -Path ([IO.Path]::GetDirectoryName($Entry.InputPath)) -Handles $lease.DirectoryHandles
        $lease.Stream = [WinAudioClean.QueueFileIO]::OpenInput($Entry.InputPath)
        $file = [IO.FileInfo]::new($Entry.InputPath)
        if ([WinAudioClean.NativeFileIO]::ResolvedPath($lease.Stream.SafeFileHandle) -ine $Entry.InputPath -or
            [WinAudioClean.NativeFileIO]::Identity($lease.Stream.SafeFileHandle) -ne $Entry.Identity -or
            $lease.Stream.Length -ne $Entry.Length -or $file.LastWriteTimeUtc.ToString('o') -ne $Entry.LastWriteTimeUtc) {
            throw 'Queued source changed after selection. Select the folder again to include its current contents.'
        }
        $lease
    } catch { Close-WacQueuedInput -Lease $lease; throw }
}

function Test-WacGeneratedArtifact {
    param([Parameter(Mandatory = $true)][string]$Name)
    $id = '[0-9a-f]{32}'
    $Name -match ('_Cleaned_[0-9]{8}-(?:[0-9]{4}|[0-9]{6}|[0-9]{9})_' + $id + '\.wav$') -or
        $Name -match ('_Preview_' + $id + '_(?:Original|Processed|CompareOriginal|CompareProcessed)\.wav$') -or
        $Name -match ('^WinAudioClean_(?:Preview_)?' + $id + '\.(?:json|txt)$') -or
        $Name -match ('^WinAudioClean_Batch_' + $id + '\.jsonl$') -or
        $Name -match ('^\.wac-' + $id + '\.partial$') -or
        $Name -match ('^\.wac-write-check-' + $id + '\.tmp$') -or
        $Name -match ('^\.wac-settings-' + $id + '\.tmp$') -or
        $Name -ieq 'WinAudioClean_Log.txt'
}

function New-WacFolderQueue {
    param([Parameter(Mandatory = $true)][string[]]$Directories,
        [Parameter(Mandatory = $true)][string]$OutputDirectory, [switch]$Recurse)
    $roots = @(Resolve-WacFolderSelection -Parameters @{ InputDirectories = $Directories })
    $destination = [IO.Path]::GetFullPath((Resolve-WacFileSystemPath -Path $OutputDirectory))
    Initialize-WacQueueFileIO
    $extensions = @('.aac', '.aif', '.aiff', '.avi', '.flac', '.m4a', '.mkv', '.mov', '.mp3', '.mp4', '.ogg', '.opus', '.wav', '.webm', '.wma')
    $handles = @{}; $visited = @{}; $identities = @{}; $generatedIdentities = @{}
    $entries = New-Object 'System.Collections.Generic.List[object]'
    $pending = New-Object 'System.Collections.Generic.Queue[string]'
    $pathBytes = 0
    # Entry count includes skips and failures; no silent truncation is permitted.
    $append = {
        param($Entry)
        if ($entries.Count -ge 1024) { throw 'Folder queue exceeds 1024 entries. Select smaller folders.' }
        $scriptBytes = [Text.UTF8Encoding]::new($false, $true).GetByteCount($Entry.InputPath)
        $pathBytes += $scriptBytes
        if ($pathBytes -gt 1048576) { throw 'Folder queue paths exceed the 1 MiB limit.' }
        $entries.Add($Entry)
    }
    $makeEntry = {
        param($Path, $Status, $Reason, $Message)
        [pscustomobject]@{ InputPath = $Path; Status = $Status; ReasonCode = $Reason
            Diagnostics = @($Message | Where-Object { $_ }); Identity = $null; Length = $null; LastWriteTimeUtc = $null }
    }
    try {
        # Validate every root before enumerating any; ancestors are opened without
        # following reparse points and held until the complete snapshot is built.
        $null = Add-WacQueueDirectory -Path $destination -Handles $handles
        foreach ($root in $roots) { $null = Add-WacQueueDirectory -Path $root -Handles $handles; $pending.Enqueue($root) }
        while ($pending.Count -gt 0) {
            $directory = $pending.Dequeue()
            $handle = Add-WacQueueDirectory -Path $directory -Handles $handles
            $identity = [WinAudioClean.NativeFileIO]::Identity($handle)
            if ($visited.ContainsKey($identity)) {
                . $append (& $makeEntry $directory 'SKIPPED' 'duplicate_directory' 'Folder was already selected; its contents are not queued again.'); continue
            }
            if ($visited.Count -ge 1024) { throw 'Folder queue exceeds 1024 visited directories. Select a smaller tree.' }
            $visited[$identity] = $true
            $children = New-Object 'System.Collections.Generic.List[string]'
            foreach ($child in [IO.Directory]::EnumerateFileSystemEntries($directory)) {
                if ($children.Count -ge 1024) { throw 'A selected folder exceeds 1024 immediate entries. Select smaller folders.' }
                $children.Add($child)
            }
            $sorted = $children.ToArray(); [Array]::Sort($sorted, [StringComparer]::Ordinal)
            foreach ($child in $sorted) {
                $attributes = [IO.File]::GetAttributes($child)
                if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                    . $append (& $makeEntry $child 'SKIPPED' 'reparse_point' 'Symbolic links, junctions and other reparse entries are not followed.'); continue
                }
                if (($attributes -band [IO.FileAttributes]::Directory) -ne 0) {
                    # Only exclude a proper descendant destination, never a root
                    # explicitly equal to it or located below an output ancestor.
                    if ($child.TrimEnd([char[]]'\/') -ieq $destination.TrimEnd([char[]]'\/') -and
                        @($roots | Where-Object { $destination.StartsWith($_.TrimEnd([char[]]'\/') + '\', [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0) {
                        . $append (& $makeEntry $child 'SKIPPED' 'output_directory' 'Destination subtree is excluded from folder discovery.')
                    } elseif (-not $Recurse) {
                        . $append (& $makeEntry $child 'SKIPPED' 'recursion_disabled' 'Nested folder skipped; use Recurse to include ordinary subfolders.')
                    } else { $null = Add-WacQueueDirectory -Path $child -Handles $handles; $pending.Enqueue($child) }
                    continue
                }
                $generated = Test-WacGeneratedArtifact -Name ([IO.Path]::GetFileName($child))
                if ($generated) { $entry = & $makeEntry $child 'SKIPPED' 'generated_artifact' 'Known WinAudioClean output, report or temporary filename is excluded.' }
                elseif ($extensions -notcontains [IO.Path]::GetExtension($child).ToLowerInvariant()) {
                    . $append (& $makeEntry $child 'SKIPPED' 'unsupported_extension' 'File extension is outside the supported folder selection list.'); continue
                } else { $entry = & $makeEntry $child 'PENDING' $null $null }
                $stream = $null
                try {
                    $stream = [WinAudioClean.QueueFileIO]::OpenInput($child)
                    $canonical = [WinAudioClean.NativeFileIO]::ResolvedPath($stream.SafeFileHandle)
                    if ($canonical -ine $child) { throw 'Queue input changed or was redirected.' }
                    $entry.InputPath = $canonical
                    $entry.Identity = [WinAudioClean.NativeFileIO]::Identity($stream.SafeFileHandle)
                    $entry.Length = $stream.Length
                    $entry.LastWriteTimeUtc = [IO.FileInfo]::new($canonical).LastWriteTimeUtc.ToString('o')
                    if ($generated) { $generatedIdentities[$entry.Identity] = $true }
                    elseif ($identities.ContainsKey($entry.Identity)) {
                        $entry.Status = 'SKIPPED'; $entry.ReasonCode = 'duplicate_file'; $entry.Diagnostics = @('File identity was already selected; aliases are not queued again.')
                    } else { $identities[$entry.Identity] = $true }
                } catch {
                    if (-not $generated) { $entry.Status = 'FAILED'; $entry.ReasonCode = 'source_unavailable'; $entry.Diagnostics = @('Cannot hold selected source: ' + $_.Exception.GetBaseException().Message) }
                } finally { if ($null -ne $stream) { $stream.Dispose() } }
                . $append $entry
            }
        }
        foreach ($entry in $entries) {
            if ($entry.Status -eq 'PENDING' -and $generatedIdentities.ContainsKey($entry.Identity)) {
                $entry.Status = 'SKIPPED'; $entry.ReasonCode = 'generated_artifact'; $entry.Diagnostics = @('File identity also belongs to a known WinAudioClean generated filename in this selection.')
            }
        }
        [pscustomobject]@{ Entries = @($entries.ToArray()); Directories = $roots; Recurse = [bool]$Recurse
            Extensions = $extensions; CapturedAt = [DateTime]::UtcNow.ToString('o') }
    } finally { foreach ($handle in $handles.Values) { $handle.Dispose() } }
}
