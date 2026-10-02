BeforeDiscovery {
    $settingsPrecedenceCases = @(
        @{ Name = 'Mode'; SavedValue = 'Zoom'; ExplicitValue = 'Raw' }
        @{ Name = 'Preset'; SavedValue = 'Gentle'; ExplicitValue = 'Original' }
        @{ Name = 'LoudnessMode'; SavedValue = 'Accurate'; ExplicitValue = 'Fast' }
        @{ Name = 'BitDepth'; SavedValue = '24'; ExplicitValue = '16' }
        @{ Name = 'Mono'; SavedValue = $true; ExplicitValue = $false }
        @{ Name = 'Rf64'; SavedValue = $true; ExplicitValue = $false }
        @{ Name = 'OutputDirectory'; SavedValue = 'C:\settings saved output'; ExplicitValue = 'C:\settings CLI output' }
        @{ Name = 'AudioStreamIndex'; SavedValue = '3'; ExplicitValue = '0' }
        @{ Name = 'CleaningOptions'; SavedValue = @{ Gate = $false; HighpassHz = 60 }; ExplicitValue = @{} }
    )
    $invalidSettingsJson = @(
        @{ Case = 'truncated JSON'; Json = '{"schemaVersion":1,"settings":' }
        @{ Case = 'trailing content'; Json = '{"schemaVersion":1,"settings":{}} false' }
        @{ Case = 'root array'; Json = '[{"schemaVersion":1,"settings":{}}]' }
        @{ Case = 'root null'; Json = 'null' }
        @{ Case = 'missing schema'; Json = '{"settings":{}}' }
        @{ Case = 'unknown schema'; Json = '{"schemaVersion":2,"settings":{}}' }
        @{ Case = 'string schema'; Json = '{"schemaVersion":"1","settings":{}}' }
        @{ Case = 'boolean schema'; Json = '{"schemaVersion":true,"settings":{}}' }
        @{ Case = 'fractional schema'; Json = '{"schemaVersion":1.0,"settings":{}}' }
        @{ Case = 'missing settings'; Json = '{"schemaVersion":1}' }
        @{ Case = 'null settings'; Json = '{"schemaVersion":1,"settings":null}' }
        @{ Case = 'array settings'; Json = '{"schemaVersion":1,"settings":[]}' }
        @{ Case = 'unknown outer key'; Json = '{"schemaVersion":1,"settings":{},"private":true}' }
        @{ Case = 'wrong outer key case'; Json = '{"SchemaVersion":1,"settings":{}}' }
        @{ Case = 'duplicate outer key'; Json = '{"schemaVersion":1,"schemaVersion":1,"settings":{}}' }
        @{ Case = 'duplicate setting'; Json = '{"schemaVersion":1,"settings":{"mode":"Raw","mode":"Zoom"}}' }
        @{ Case = 'escaped duplicate setting'; Json = '{"schemaVersion":1,"settings":{"mode":"Raw","mo\u0064e":"Zoom"}}' }
        @{ Case = 'wrong setting key case'; Json = '{"schemaVersion":1,"settings":{"Mode":"Raw"}}' }
        @{ Case = 'case-coalescing settings keys'; Json = '{"schemaVersion":1,"settings":{"mode":"Raw","Mode":"Zoom"}}' }
        @{ Case = 'unknown setting'; Json = '{"schemaVersion":1,"settings":{"filterChain":"volume=100"}}' }
        @{ Case = 'invalid mode'; Json = '{"schemaVersion":1,"settings":{"mode":"Other"}}' }
        @{ Case = 'null mode'; Json = '{"schemaVersion":1,"settings":{"mode":null}}' }
        @{ Case = 'empty mode'; Json = '{"schemaVersion":1,"settings":{"mode":""}}' }
        @{ Case = 'boolean mode'; Json = '{"schemaVersion":1,"settings":{"mode":false}}' }
        @{ Case = 'invalid preset'; Json = '{"schemaVersion":1,"settings":{"preset":"Automatic"}}' }
        @{ Case = 'invalid loudness mode'; Json = '{"schemaVersion":1,"settings":{"loudnessMode":"Measured"}}' }
        @{ Case = 'string bit depth'; Json = '{"schemaVersion":1,"settings":{"bitDepth":"16"}}' }
        @{ Case = 'fractional bit depth'; Json = '{"schemaVersion":1,"settings":{"bitDepth":16.0}}' }
        @{ Case = 'unsupported bit depth'; Json = '{"schemaVersion":1,"settings":{"bitDepth":32}}' }
        @{ Case = 'boolean bit depth'; Json = '{"schemaVersion":1,"settings":{"bitDepth":true}}' }
        @{ Case = 'numeric mono'; Json = '{"schemaVersion":1,"settings":{"mono":0}}' }
        @{ Case = 'string mono'; Json = '{"schemaVersion":1,"settings":{"mono":"false"}}' }
        @{ Case = 'array RF64'; Json = '{"schemaVersion":1,"settings":{"rf64":[false]}}' }
        @{ Case = 'null RF64'; Json = '{"schemaVersion":1,"settings":{"rf64":null}}' }
        @{ Case = 'empty output directory'; Json = '{"schemaVersion":1,"settings":{"outputDirectory":""}}' }
        @{ Case = 'numeric output directory'; Json = '{"schemaVersion":1,"settings":{"outputDirectory":4}}' }
        @{ Case = 'URL output directory'; Json = '{"schemaVersion":1,"settings":{"outputDirectory":"https://invalid.example/audio"}}' }
        @{ Case = 'negative stream index'; Json = '{"schemaVersion":1,"settings":{"audioStreamIndex":-1}}' }
        @{ Case = 'string stream index'; Json = '{"schemaVersion":1,"settings":{"audioStreamIndex":"0"}}' }
        @{ Case = 'fractional stream index'; Json = '{"schemaVersion":1,"settings":{"audioStreamIndex":0.5}}' }
        @{ Case = 'decimal integer stream index'; Json = '{"schemaVersion":1,"settings":{"audioStreamIndex":0.0}}' }
        @{ Case = 'overflow stream index'; Json = '{"schemaVersion":1,"settings":{"audioStreamIndex":2147483648}}' }
        @{ Case = 'boolean stream index'; Json = '{"schemaVersion":1,"settings":{"audioStreamIndex":true}}' }
        @{ Case = 'null cleaning'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":null}}' }
        @{ Case = 'array cleaning'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":[]}}' }
        @{ Case = 'unknown cleaning option'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":{"Filter":"volume=100"}}}' }
        @{ Case = 'wrong cleaning key case'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":{"highpassHz":60}}}' }
        @{ Case = 'case-coalescing cleaning keys'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":{"Gate":true,"gate":false}}}' }
        @{ Case = 'duplicate cleaning option'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":{"Gate":true,"Gate":false}}}' }
        @{ Case = 'string cleaning number'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":{"HighpassHz":"60"}}}' }
        @{ Case = 'boolean cleaning number'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":{"HighpassHz":true}}}' }
        @{ Case = 'nonfinite cleaning number'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":{"HighpassHz":1e999}}}' }
        @{ Case = 'below cleaning bound'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":{"NoiseReductionDb":0}}}' }
        @{ Case = 'above cleaning bound'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":{"HighpassHz":201}}}' }
        @{ Case = 'numeric cleaning toggle'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":{"Gate":1}}}' }
        @{ Case = 'injected cleaning string'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":{"NoiseFloorDb":"-35,volume=100"}}}' }
        @{ Case = 'NaN JSON token'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":{"HighpassHz":NaN}}}' }
        @{ Case = 'Zoom Gentle conflict'; Json = '{"schemaVersion":1,"settings":{"mode":"Zoom","preset":"Gentle"}}' }
        @{ Case = 'Zoom cleaning conflict'; Json = '{"schemaVersion":1,"settings":{"mode":"Zoom","cleaningOptions":{"Gate":false}}}' }
        @{ Case = 'invalid disabled gate value'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":{"Gate":false,"GateRangeDb":1}}}' }
        @{ Case = 'invalid disabled denoise value'; Json = '{"schemaVersion":1,"settings":{"cleaningOptions":{"Denoise":false,"NoiseFloorDb":-10}}}' }
    )
}

BeforeAll {
    $settingsRepository = Split-Path $PSScriptRoot -Parent
    $settingsMain = Join-Path $settingsRepository 'WinAudioClean.ps1'
    . $settingsMain
    . (Join-Path $settingsRepository 'WinAudioClean.Settings.ps1')
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
    $settingsUtf8 = New-Object Text.UTF8Encoding($false)
    function New-WacSettingsTestPath {
        Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '.json')
    }
    function Write-WacSettingsTestJson {
        param([string]$Path, [string]$Json)
        [IO.File]::WriteAllText($Path, $Json, $settingsUtf8)
    }
    function Get-WacSettingsTestBytes {
        param([string]$Path)
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))
    }
}

Describe 'AC-049: explicit settings override saved values and built-in defaults' -Tag 'Settings', 'Unit' {
    It 'chooses the saved then explicit <Name> value with an attributable origin' -ForEach $settingsPrecedenceCases {
        $saved = @{}; $saved[$Name] = $SavedValue
        $resolvedSaved = Resolve-WacSettings -Explicit @{} -Saved $saved
        $resolvedSaved.Origins[$Name] | Should -BeExactly 'Saved'
        if ($Name -eq 'CleaningOptions') {
            $resolvedSaved.Values[$Name].Gate | Should -BeFalse
            $resolvedSaved.Values[$Name].HighpassHz | Should -Be 60
        } else { $resolvedSaved.Values[$Name] | Should -Be $SavedValue }
        $explicit = @{}; $explicit[$Name] = $ExplicitValue
        $resolvedExplicit = Resolve-WacSettings -Explicit $explicit -Saved $saved
        $resolvedExplicit.Origins[$Name] | Should -BeExactly 'CLI'
        if ($Name -eq 'CleaningOptions') {
            $resolvedExplicit.Values[$Name].Count | Should -Be 0
            $saved[$Name].Count | Should -Be 2
        } else { $resolvedExplicit.Values[$Name] | Should -Be $ExplicitValue }
    }

    It 'retains the exact built-in policy when every preference is omitted' {
        $resolved = Resolve-WacSettings -Explicit @{} -Saved @{}
        $resolved.Values.Mode | Should -BeNullOrEmpty
        $resolved.Values.AudioStreamIndex | Should -BeNullOrEmpty
        $resolved.Values.Preset | Should -BeExactly 'Original'
        $resolved.Values.LoudnessMode | Should -BeExactly 'Fast'
        $resolved.Values.BitDepth | Should -BeExactly '16'
        $resolved.Values.Mono | Should -BeFalse
        $resolved.Values.Rf64 | Should -BeFalse
        $resolved.Values.CleaningOptions.Count | Should -Be 0
        $resolved.Values.OutputDirectory | Should -BeExactly ([Environment]::GetFolderPath('MyMusic'))
        foreach ($key in $resolved.Values.Keys) { $resolved.Origins[$key] | Should -BeExactly 'BuiltIn' }
    }

    It 'computes the default path without reading or creating preferences' {
        $expected = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'WinAudioClean\settings.json'
        Get-WacDefaultSettingsPath | Should -BeExactly $expected
    }

    It 'returns omitted settings for a missing isolated file without creating its parent' {
        $parent = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        (Read-WacSettings -Path (Join-Path $parent 'missing.json')).Count | Should -Be 0
        Test-Path -LiteralPath $parent | Should -BeFalse
    }

    It 'maps all saved fields into app-compatible values without materializing defaults' {
        $path = New-WacSettingsTestPath
        Write-WacSettingsTestJson -Path $path -Json '{"schemaVersion":1,"settings":{"mode":"Raw","preset":"Gentle","loudnessMode":"Accurate","bitDepth":24,"mono":false,"rf64":true,"outputDirectory":"C:\\settings output","audioStreamIndex":3,"cleaningOptions":{"Gate":true,"HighpassHz":61.5}}}'
        $values = Read-WacSettings -Path $path
        $values.Count | Should -Be 9
        $values.Mode | Should -BeExactly 'Raw'
        $values.Preset | Should -BeExactly 'Gentle'
        $values.LoudnessMode | Should -BeExactly 'Accurate'
        $values.BitDepth | Should -BeExactly '24'
        $values.AudioStreamIndex | Should -BeExactly '3'
        $values.Mono | Should -BeOfType ([bool])
        $values.Mono | Should -BeFalse
        $values.Rf64 | Should -BeTrue
        $values.CleaningOptions.Gate | Should -BeTrue
        $values.CleaningOptions.HighpassHz | Should -Be 61.5
        Write-WacSettingsTestJson -Path $path -Json '{"schemaVersion":1,"settings":{}}'
        (Read-WacSettings -Path $path).Count | Should -Be 0
    }

    It 'rejects explicit empty <Name> instead of falling back to a saved value' -ForEach @(
        @{ Name = 'Mode'; Saved = 'Raw' }; @{ Name = 'Preset'; Saved = 'Original' }
        @{ Name = 'LoudnessMode'; Saved = 'Fast' }; @{ Name = 'BitDepth'; Saved = '16' }
        @{ Name = 'OutputDirectory'; Saved = 'C:\settings output' }; @{ Name = 'AudioStreamIndex'; Saved = '0' }
    ) {
        $saved = @{}; $saved[$Name] = $Saved
        $explicit = @{}; $explicit[$Name] = ''
        { Resolve-WacSettings -Explicit $explicit -Saved $saved } | Should -Throw
    }

    It 'validates an invalid saved field even when an explicit value would replace it' {
        { Resolve-WacSettings -Explicit @{ BitDepth = '16' } -Saved @{ BitDepth = '32' } } | Should -Throw
        { Resolve-WacSettings -Explicit @{ Mode = 'Raw' } -Saved @{ Mode = 'Zoom'; Preset = 'Gentle' } } | Should -Throw
    }

    It 'accepts explicit false SwitchParameter values and ignores non-preference main arguments' {
        $resolved = Resolve-WacSettings -Saved @{ Mono = $true; Rf64 = $true } -Explicit @{
            Mono = [Management.Automation.SwitchParameter]$false; Rf64 = [Management.Automation.SwitchParameter]$false
            inputPath = 'unused.wav'; NonInteractive = [Management.Automation.SwitchParameter]$true
            SettingsPath = (Join-Path $TestDrive 'unused.json'); ShowSettings = [Management.Automation.SwitchParameter]$true
        }
        $resolved.Values.Mono | Should -BeOfType ([bool])
        $resolved.Values.Mono | Should -BeFalse
        $resolved.Values.Rf64 | Should -BeFalse
        $resolved.Origins.Mono | Should -BeExactly 'CLI'
        $resolved.Values.Keys | Should -Not -Contain 'inputPath'
        $resolved.Values.Keys | Should -Not -Contain 'SettingsPath'
    }
}

Describe 'AC-051: saved JSON is bounded typed data rather than executable options' -Tag 'Settings', 'Unit' {
    It 'rejects <Case> while preserving the complete file bytes' -ForEach $invalidSettingsJson {
        $path = New-WacSettingsTestPath
        Write-WacSettingsTestJson -Path $path -Json $Json
        $before = Get-WacSettingsTestBytes -Path $path
        { Read-WacSettings -Path $path } | Should -Throw
        Get-WacSettingsTestBytes -Path $path | Should -BeExactly $before
    }

    It 'rejects <Case> byte encoding without rewriting it' -ForEach @(
        @{ Case = 'malformed UTF-8'; Bytes = [byte[]](0xC3, 0x28) }
        @{ Case = 'UTF-16 encoding'; Bytes = [byte[]](0xFF, 0xFE, 0x7B, 0, 0x7D, 0) }
        @{ Case = 'embedded NUL'; Bytes = [byte[]](0x7B, 0, 0x7D) }
    ) {
        $path = New-WacSettingsTestPath
        [IO.File]::WriteAllBytes($path, $Bytes)
        $before = Get-WacSettingsTestBytes -Path $path
        { Read-WacSettings -Path $path } | Should -Throw
        Get-WacSettingsTestBytes -Path $path | Should -BeExactly $before
    }

    It 'accepts the byte ceiling and rejects one byte beyond it' {
        $path = New-WacSettingsTestPath
        $json = '{"schemaVersion":1,"settings":{}}'
        [IO.File]::WriteAllText($path, ($json + (' ' * (65536 - $settingsUtf8.GetByteCount($json)))), $settingsUtf8)
        (Get-Item -LiteralPath $path).Length | Should -Be 65536
        (Read-WacSettings -Path $path).Count | Should -Be 0
        [IO.File]::AppendAllText($path, ' ', $settingsUtf8)
        { Read-WacSettings -Path $path } | Should -Throw
        (Get-Item -LiteralPath $path).Length | Should -Be 65537
    }

    It 'accepts one UTF-8 BOM and counts it in the byte limit' {
        $path = New-WacSettingsTestPath
        $bomUtf8 = New-Object Text.UTF8Encoding($true)
        [IO.File]::WriteAllText($path, '{"schemaVersion":1,"settings":{"mono":false}}', $bomUtf8)
        (Read-WacSettings -Path $path).Mono | Should -BeFalse
    }

    It 'rejects executable-looking settings without executing their text' {
        $path = New-WacSettingsTestPath
        $sentinel = Join-Path $TestDrive 'settings execution sentinel.txt'
        $expression = '$(Set-Content -LiteralPath ''' + $sentinel + ''' -Value executed)'
        $json = @{ schemaVersion = 1; settings = @{ cleaningOptions = @{ HighpassHz = $expression } } } | ConvertTo-Json -Depth 6
        Write-WacSettingsTestJson -Path $path -Json $json
        { Read-WacSettings -Path $path } | Should -Throw
        Test-Path -LiteralPath $sentinel | Should -BeFalse
    }

    It 'reports invalid settings without echoing private configuration contents' {
        $path = New-WacSettingsTestPath
        Write-WacSettingsTestJson -Path $path -Json '{"schemaVersion":1,"settings":{"preset":"PRIVATE_CONFIGURATION_SENTINEL"}}'
        $caught = $null
        try { $null = Read-WacSettings -Path $path } catch { $caught = $_ }
        $caught | Should -Not -BeNullOrEmpty
        $caught.Exception.Message | Should -Not -Match 'PRIVATE_CONFIGURATION_SENTINEL'
    }

    It 'serializes typed values and profile numbers invariantly in <Culture>' -ForEach @(
        @{ Culture = 'de-DE' }; @{ Culture = 'fi-FI' }
    ) {
        $oldCulture = [Threading.Thread]::CurrentThread.CurrentCulture
        try {
            [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo($Culture)
            $values = @{ Mode = 'Raw'; Preset = 'Gentle'; LoudnessMode = 'Accurate'; BitDepth = '24'; Mono = $false; Rf64 = $true
                AudioStreamIndex = '0'; CleaningOptions = @{ HighpassHz = 61.5; NoiseFloorDb = -35.25; NoiseReductionDb = 6.125 } }
            $json = ConvertTo-WacSettingsJson -Values $values
            $parsed = $json | ConvertFrom-Json
            ($parsed.settings.bitDepth -is [int] -or $parsed.settings.bitDepth -is [long]) | Should -BeTrue
            ($parsed.settings.audioStreamIndex -is [int] -or $parsed.settings.audioStreamIndex -is [long]) | Should -BeTrue
            $parsed.settings.bitDepth | Should -Be 24
            $parsed.settings.audioStreamIndex | Should -Be 0
            $json | Should -Match '61\.5'
            $json | Should -Not -Match '61,5|-35,25'
            $path = New-WacSettingsTestPath
            $null = Save-WacSettings -Path $path -Values $values
            $roundTrip = Read-WacSettings -Path $path
            $profile = Get-WacProcessingProfile -Choice 1 -Preset $roundTrip.Preset -CleaningOptions $roundTrip.CleaningOptions
            $profile.FilterChain | Should -BeExactly 'highpass=f=61.5,afftdn=nf=-35.25:nr=6.125,dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'
        } finally { [Threading.Thread]::CurrentThread.CurrentCulture = $oldCulture }
    }
}

Describe 'AC-051: atomic settings saves preserve old data on failed publication' -Tag 'Settings', 'Unit', 'OutputSafety' {
    It 'rejects a directory config path without changing its contents' {
        $path = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($path)
        $foreign = Join-Path $path 'foreign.txt'
        [IO.File]::WriteAllBytes($foreign, [byte[]](4, 5, 6))
        { Read-WacSettings -Path $path } | Should -Throw
        { Save-WacSettings -Path $path -Values @{ Mode = 'Raw' } } | Should -Throw
        Get-WacSettingsTestBytes -Path $foreign | Should -BeExactly 'BAUG'
        @(Get-ChildItem -LiteralPath $path -Force).Count | Should -Be 1
    }

    It 'rejects a config path through a junction without changing the target or foreign files' {
        $parent = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $target = Join-Path $parent 'target'
        $junction = Join-Path $parent 'junction'
        $null = [IO.Directory]::CreateDirectory($target)
        $path = Join-Path $target 'settings.json'
        Write-WacSettingsTestJson -Path $path -Json '{"schemaVersion":1,"settings":{"mode":"Zoom"}}'
        $before = Get-WacSettingsTestBytes -Path $path
        $null = New-Item -ItemType Junction -Path $junction -Target $target
        try {
            $redirected = Join-Path $junction 'settings.json'
            { Read-WacSettings -Path $redirected } | Should -Throw
            { Save-WacSettings -Path $redirected -Values @{ Mode = 'Raw' } } | Should -Throw
            Get-WacSettingsTestBytes -Path $path | Should -BeExactly $before
            @(Get-ChildItem -LiteralPath $target -Force).Count | Should -Be 1
        } finally { [IO.Directory]::Delete($junction) }
        Get-WacSettingsTestBytes -Path $path | Should -BeExactly $before
    }

    It 'preserves a foreign destination appearing after an initially absent target was reserved' {
        $parent = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($parent)
        $path = Join-Path $parent 'settings.json'
        $settingsOriginalPublisher = (Get-Command Publish-WacSettingsFile).ScriptBlock
        Mock Publish-WacSettingsFile {
            param($TempPath, $Path, $DestinationExists, $Writer, $Directory)
            $DestinationExists | Should -BeFalse
            [IO.File]::WriteAllBytes($Path, [byte[]](4, 5, 6))
            & $settingsOriginalPublisher -TempPath $TempPath -Path $Path -DestinationExists $DestinationExists -Writer $Writer -Directory $Directory
        }
        { Save-WacSettings -Path $path -Values @{ Mode = 'Raw' } } | Should -Throw '*Cannot publish settings atomically*'
        Get-WacSettingsTestBytes -Path $path | Should -BeExactly 'BAUG'
        @(Get-ChildItem -LiteralPath $parent -Force).Count | Should -Be 1
        Should -Invoke Publish-WacSettingsFile -Times 1 -Exactly
    }

    It 'replaces a valid config and resets it to an empty versioned document' {
        $path = New-WacSettingsTestPath
        $null = Save-WacSettings -Path $path -Values @{ Mode = 'Raw'; BitDepth = '24' }
        (Read-WacSettings -Path $path).BitDepth | Should -BeExactly '24'
        $null = Save-WacSettings -Path $path -Values @{}
        $parsed = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
        $parsed.schemaVersion | Should -Be 1
        @($parsed.settings.PSObject.Properties).Count | Should -Be 0
        [IO.File]::ReadAllBytes($path)[0] | Should -Be 0x7B
    }

    It 'preserves old bytes and a foreign temporary during <Failure>' -ForEach @(
        @{ Failure = 'publication error'; Cancel = $false }; @{ Failure = 'interrupted publication'; Cancel = $true }
    ) {
        $parent = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($parent)
        $path = Join-Path $parent 'settings.json'
        Write-WacSettingsTestJson -Path $path -Json '{"schemaVersion":1,"settings":{"mode":"Zoom"}}'
        $foreign = Join-Path $parent '.foreign-settings.tmp'
        [IO.File]::WriteAllBytes($foreign, [byte[]](4, 5, 6))
        $before = Get-WacSettingsTestBytes -Path $path
        Mock Publish-WacSettingsFile {
            if ($Cancel) { throw (New-Object System.OperationCanceledException -ArgumentList 'settings publication interrupted') }
            throw 'settings publication failed'
        }
        { Save-WacSettings -Path $path -Values @{ Mode = 'Raw' } } | Should -Throw
        Get-WacSettingsTestBytes -Path $path | Should -BeExactly $before
        Get-WacSettingsTestBytes -Path $foreign | Should -BeExactly 'BAUG'
        @(Get-ChildItem -LiteralPath $parent -Force).Count | Should -Be 2
        Should -Invoke Publish-WacSettingsFile -Times 1 -Exactly
    }

    It 'preserves a locked old target and removes its own temporary after replacement fails' {
        $parent = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($parent)
        $path = Join-Path $parent 'settings.json'
        Write-WacSettingsTestJson -Path $path -Json '{"schemaVersion":1,"settings":{"mode":"Zoom"}}'
        $before = Get-WacSettingsTestBytes -Path $path
        $held = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        try { { Save-WacSettings -Path $path -Values @{ Mode = 'Raw' } } | Should -Throw }
        finally { $held.Dispose() }
        Get-WacSettingsTestBytes -Path $path | Should -BeExactly $before
        @(Get-ChildItem -LiteralPath $parent -Force).Count | Should -Be 1
    }

    It 'denies non-owner delete, rename and write while publication retains the owned temporary handle' {
        $parent = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($parent)
        $path = Join-Path $parent 'settings.json'
        Write-WacSettingsTestJson -Path $path -Json '{"schemaVersion":1,"settings":{"mode":"Zoom"}}'
        $before = Get-WacSettingsTestBytes -Path $path
        $foreign = Join-Path $parent '.foreign-settings.tmp'
        [IO.File]::WriteAllBytes($foreign, [byte[]](4, 5, 6))
        Mock Publish-WacSettingsFile {
            param($TempPath, $Path, $DestinationExists, $Writer, $Directory)
            $Writer.CanWrite | Should -BeTrue
            Test-Path -LiteralPath $TempPath | Should -BeTrue
            { [IO.File]::Delete($TempPath) } | Should -Throw
            { [IO.File]::Move($TempPath, ($TempPath + '.foreign')) } | Should -Throw
            { [IO.File]::WriteAllText($TempPath, 'foreign replacement') } | Should -Throw
            throw 'settings ownership publication fault'
        }
        { Save-WacSettings -Path $path -Values @{ Mode = 'Raw' } } | Should -Throw '*settings ownership publication fault*'
        Get-WacSettingsTestBytes -Path $path | Should -BeExactly $before
        Get-WacSettingsTestBytes -Path $foreign | Should -BeExactly 'BAUG'
        @(Get-ChildItem -LiteralPath $parent -Force).Count | Should -Be 2
        Should -Invoke Publish-WacSettingsFile -Times 1 -Exactly
    }

    It 'rejects invalid new settings before changing the previous config' {
        $path = New-WacSettingsTestPath
        Write-WacSettingsTestJson -Path $path -Json '{"schemaVersion":1,"settings":{"mode":"Zoom"}}'
        $before = Get-WacSettingsTestBytes -Path $path
        { Save-WacSettings -Path $path -Values @{ BitDepth = '32' } } | Should -Throw
        Get-WacSettingsTestBytes -Path $path | Should -BeExactly $before
    }
}

Describe 'AC-049/050: isolated settings management is unattended and never starts media tools' -Tag 'Settings', 'EntryPoint', 'Runtime' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'fixtures\New-NativeProcessFixture.ps1')
        $settingsShell = (Get-Process -Id $PID).Path
        $settingsNative = New-WacTestNativeExecutable -OutputPath (Join-Path $TestDrive 'settings native fixture.exe')
        function New-WacSettingsSandbox {
            param([switch]$WithoutSettings)
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $null = [IO.Directory]::CreateDirectory($root)
            foreach ($name in @('WinAudioClean.ps1', 'WinAudioClean.IO.ps1')) {
                Copy-Item -LiteralPath (Join-Path $settingsRepository $name) -Destination $root
            }
            if (-not $WithoutSettings) { Copy-Item -LiteralPath (Join-Path $settingsRepository 'WinAudioClean.Settings.ps1') -Destination $root }
            foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) { Copy-Item -LiteralPath $settingsNative -Destination (Join-Path $root $name) }
            $settingsInput = Join-Path $root 'synthetic input [1].wav'
            [IO.File]::WriteAllBytes($settingsInput, [byte[]](1, 2, 3, 4))
            $driver = Join-Path $root 'Invoke-SettingsCase.ps1'
            $driverCode = @'
param([string]$App, [string]$Config, [string]$InputFile, [string]$OutputFolder, [string]$Case)
$options = @{ SettingsPath = $Config; NonInteractive = $true }
switch ($Case) {
    'show' { $options.ShowSettings = $true }
    'save show' { $options.SaveSettings = $true; $options.ShowSettings = $true; $options.Mode = 'Raw'; $options.Preset = 'Gentle'; $options.BitDepth = '24'; $options.Mono = $false; $options.OutputDirectory = $OutputFolder; $options.CleaningOptions = @{ HighpassHz = 61.5; Gate = $false } }
    'reset show' { $options.ResetSettings = $true; $options.ShowSettings = $true }
    'ignore show' { $options.ShowSettings = $true; $options.IgnoreSavedSettings = $true }
    'save and reset' { $options.SaveSettings = $true; $options.ResetSettings = $true }
    'show input' { $options.ShowSettings = $true; $options.inputPath = $InputFile }
    'show preview' { $options.ShowSettings = $true; $options.Preview = $true }
    'show preview range' { $options.ShowSettings = $true; $options.PreviewDurationSeconds = '10' }
    'show native path' { $options.ShowSettings = $true; $options.FfmpegPath = Join-Path (Split-Path $App) 'ffmpeg.exe' }
    'show diagnostic' { $options.ShowSettings = $true; $options.ExportDiagnostic = $Config }
    'reset mode' { $options.ResetSettings = $true; $options.Mode = 'Raw' }
    'empty explicit mode' { $options.ShowSettings = $true; $options.Mode = '' }
    'empty settings path' { $options.ShowSettings = $true; $options.SettingsPath = '' }
    'saved job' { $options.inputPath = $InputFile }
    'explicit job' { $options.inputPath = $InputFile; $options.Mode = 'Raw'; $options.Preset = 'Gentle'; $options.CleaningOptions = @{} }
    'ignore job' { $options.inputPath = $InputFile; $options.IgnoreSavedSettings = $true; $options.Mode = 'Zoom'; $options.OutputDirectory = $OutputFolder }
    'false switches job' { $options.inputPath = $InputFile; $options.Mono = $false; $options.Rf64 = $false }
    'missing mode' { $options.inputPath = $InputFile; $options.OutputDirectory = $OutputFolder }
    'legacy IO only bypass' { $options.Remove('SettingsPath'); $options.IgnoreSavedSettings = $true; $options.Mode = 'Zoom'; $options.OutputDirectory = $OutputFolder; & $App $InputFile @options; exit $LASTEXITCODE }
    default { throw 'Unknown settings test case.' }
}
& $App @options
exit $LASTEXITCODE
'@
            [IO.File]::WriteAllText($driver, $driverCode, (New-Object Text.UTF8Encoding($true)))
            [pscustomobject]@{ Root = $root; App = Join-Path $root 'WinAudioClean.ps1'; Driver = $driver; Input = $settingsInput
                Config = Join-Path $root 'isolated-settings.json'; Output = Join-Path $root 'new output'
                RenderArgv = Join-Path $root 'render-argv.json'; NativePid = Join-Path $root 'native-started.txt' }
        }
        function Invoke-WacSettingsCase {
            param($Sandbox, [string]$Case, [hashtable]$ExtraEnvironment = @{})
            $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -App {1} -Config {2} -InputFile {3} -OutputFolder {4} -Case {5}' -f
                (ConvertTo-WacTestQuotedArgument $Sandbox.Driver), (ConvertTo-WacTestQuotedArgument $Sandbox.App),
                (ConvertTo-WacTestQuotedArgument $Sandbox.Config), (ConvertTo-WacTestQuotedArgument $Sandbox.Input),
                (ConvertTo-WacTestQuotedArgument $Sandbox.Output), (ConvertTo-WacTestQuotedArgument $Case)
            $environment = @{ WAC_TEST_FFMPEG_OUTPUT = '1'; WAC_TEST_ARGV_PATH = $Sandbox.RenderArgv
                WAC_TEST_VERSION_PID_PATH = $Sandbox.NativePid; WAC_TEST_FILTERS_PID_PATH = $Sandbox.NativePid
                WAC_TEST_PROBE_PID_PATH = $Sandbox.NativePid; PSMODULEPATH = $null }
            foreach ($key in $ExtraEnvironment.Keys) { $environment[$key] = $ExtraEnvironment[$key] }
            Invoke-WacTestProcess -FilePath $settingsShell -Arguments $arguments -WorkingDirectory $Sandbox.Root -EnvironmentVariables $environment -TimeoutMilliseconds 40000
        }
        function Get-WacSettingsShownJson {
            param($Result)
            $lines = @($Result.StandardOutput -split '\r?\n' | Where-Object { $_.TrimStart().StartsWith('{') })
            $lines.Count | Should -Be 1 -Because $Result.StandardOutput
            $lines[0] | ConvertFrom-Json
        }
    }

    It 'shows omitted/default values without input, native startup, prompts or autosaving' {
        $sandbox = New-WacSettingsSandbox
        $result = Invoke-WacSettingsCase -Sandbox $sandbox -Case 'show'
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $shown = Get-WacSettingsShownJson -Result $result
        $shown.schemaVersion | Should -Be 1
        $shown.settings.preset | Should -BeExactly 'Original'
        $shown.settings.loudnessMode | Should -BeExactly 'Fast'
        $shown.settings.bitDepth | Should -Be 16
        $shown.origins.Preset | Should -BeExactly 'BuiltIn'
        $shown.effectiveCleaning | Should -BeNullOrEmpty
        $shown.effectiveFilterChain | Should -BeNullOrEmpty
        $shown.effectiveProfileReason | Should -BeExactly 'mode_not_selected'
        $result.StandardOutput | Should -Not -Match 'Enter selection|Choose an audio|Press any|Select Processing'
        Test-Path -LiteralPath $sandbox.Config | Should -BeFalse
        Test-Path -LiteralPath $sandbox.Output | Should -BeFalse
        Test-Path -LiteralPath $sandbox.NativePid | Should -BeFalse
        Test-Path -LiteralPath $sandbox.RenderArgv | Should -BeFalse
    }

    It 'explicitly saves typed chosen settings and shows their origins without media processing' {
        $sandbox = New-WacSettingsSandbox
        $result = Invoke-WacSettingsCase -Sandbox $sandbox -Case 'save show'
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $shown = Get-WacSettingsShownJson -Result $result
        $saved = Read-WacSettings -Path $sandbox.Config
        $saved.Mode | Should -BeExactly 'Raw'
        $saved.Preset | Should -BeExactly 'Gentle'
        $saved.BitDepth | Should -BeExactly '24'
        $saved.Mono | Should -BeFalse
        $saved.CleaningOptions.HighpassHz | Should -Be 61.5
        $shown.origins.Preset | Should -BeExactly 'CLI'
        $shown.effectiveCleaning.HighpassHz | Should -Be 61.5
        $shown.effectiveFilterChain | Should -BeExactly 'highpass=f=61.5,afftdn=nf=-35:nr=6,dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'
        $shown.effectiveProfileReason | Should -BeNullOrEmpty
        Test-Path -LiteralPath $sandbox.Output | Should -BeFalse
        Test-Path -LiteralPath $sandbox.NativePid | Should -BeFalse
        @(Get-ChildItem -LiteralPath $sandbox.Root -Filter '*.partial' -Force).Count | Should -Be 0
    }

    It 'resets a corrupt config without reading its content or starting native tools' {
        $sandbox = New-WacSettingsSandbox
        Write-WacSettingsTestJson -Path $sandbox.Config -Json 'this is not JSON'
        $result = Invoke-WacSettingsCase -Sandbox $sandbox -Case 'reset show'
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        (Read-WacSettings -Path $sandbox.Config).Count | Should -Be 0
        $persisted = Get-Content -Raw -LiteralPath $sandbox.Config | ConvertFrom-Json
        @($persisted.settings.PSObject.Properties).Count | Should -Be 0
        (Get-WacSettingsShownJson -Result $result).settings.preset | Should -BeExactly 'Original'
        Test-Path -LiteralPath $sandbox.NativePid | Should -BeFalse
    }

    It 'ignores a corrupt isolated config for Show without repairing or rewriting it' {
        $sandbox = New-WacSettingsSandbox
        Write-WacSettingsTestJson -Path $sandbox.Config -Json 'corrupt but ignored'
        $before = Get-WacSettingsTestBytes -Path $sandbox.Config
        $result = Invoke-WacSettingsCase -Sandbox $sandbox -Case 'ignore show'
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        (Get-WacSettingsShownJson -Result $result).origins.Preset | Should -BeExactly 'BuiltIn'
        Get-WacSettingsTestBytes -Path $sandbox.Config | Should -BeExactly $before
        Test-Path -LiteralPath $sandbox.NativePid | Should -BeFalse
    }

    It 'rejects <Case> with code 2 before native or preference/output changes' -ForEach @(
        @{ Case = 'save and reset' }; @{ Case = 'show input' }; @{ Case = 'show preview' }
        @{ Case = 'show preview range' }; @{ Case = 'show native path' }; @{ Case = 'show diagnostic' }
        @{ Case = 'reset mode' }; @{ Case = 'empty explicit mode' }; @{ Case = 'empty settings path' }
    ) {
        $sandbox = New-WacSettingsSandbox
        Write-WacSettingsTestJson -Path $sandbox.Config -Json '{"schemaVersion":1,"settings":{"mode":"Raw"}}'
        $before = Get-WacSettingsTestBytes -Path $sandbox.Config
        $result = Invoke-WacSettingsCase -Sandbox $sandbox -Case $Case
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        $result.StandardOutput | Should -Not -Match 'Enter selection|Choose an audio|Press any'
        Get-WacSettingsTestBytes -Path $sandbox.Config | Should -BeExactly $before
        Test-Path -LiteralPath $sandbox.Output | Should -BeFalse
        Test-Path -LiteralPath $sandbox.NativePid | Should -BeFalse
        Test-Path -LiteralPath $sandbox.RenderArgv | Should -BeFalse
    }

    It 'rejects a corrupt saved file before explicit CLI overrides, dependencies or output creation' {
        $sandbox = New-WacSettingsSandbox
        Write-WacSettingsTestJson -Path $sandbox.Config -Json '{"schemaVersion":1,"settings":{"preset":"unknown"}}'
        $before = Get-WacSettingsTestBytes -Path $sandbox.Config
        $result = Invoke-WacSettingsCase -Sandbox $sandbox -Case 'explicit job'
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        Get-WacSettingsTestBytes -Path $sandbox.Config | Should -BeExactly $before
        Test-Path -LiteralPath $sandbox.Output | Should -BeFalse
        Test-Path -LiteralPath $sandbox.NativePid | Should -BeFalse
    }

    It 'uses saved mode/output choices for a real unattended entry point without autosaving' {
        $sandbox = New-WacSettingsSandbox
        $null = Save-WacSettings -Path $sandbox.Config -Values @{ Mode = 'Zoom'; OutputDirectory = $sandbox.Output }
        $before = Get-WacSettingsTestBytes -Path $sandbox.Config
        $result = Invoke-WacSettingsCase -Sandbox $sandbox -Case 'saved job'
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $result.StandardOutput | Should -Not -Match 'Enter selection|Choose an audio|Press any|Select Processing'
        $argv = Get-Content -Raw -LiteralPath $sandbox.RenderArgv | ConvertFrom-Json
        $argv[[Array]::IndexOf($argv, '-af') + 1] | Should -BeExactly 'dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'
        $reportPaths = @(Get-ChildItem -LiteralPath $sandbox.Output -Filter 'WinAudioClean_*.json')
        $reportPaths.Count | Should -Be 1
        (Get-Content -Raw -LiteralPath $reportPaths[0].FullName | ConvertFrom-Json).settings.mode | Should -BeExactly 'Zoom'
        Get-WacSettingsTestBytes -Path $sandbox.Config | Should -BeExactly $before
        Get-WacSettingsTestBytes -Path $sandbox.Input | Should -BeExactly 'AQIDBA=='
    }

    It 'replaces saved cleaning wholly with an explicit empty dictionary before constructing the graph' {
        $sandbox = New-WacSettingsSandbox
        $null = Save-WacSettings -Path $sandbox.Config -Values @{ Mode = 'Raw'; Preset = 'Gentle'; OutputDirectory = $sandbox.Output
            CleaningOptions = @{ Gate = $true; Declip = $true } }
        $before = Get-WacSettingsTestBytes -Path $sandbox.Config
        $result = Invoke-WacSettingsCase -Sandbox $sandbox -Case 'explicit job'
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $argv = Get-Content -Raw -LiteralPath $sandbox.RenderArgv | ConvertFrom-Json
        $argv[[Array]::IndexOf($argv, '-af') + 1] | Should -BeExactly 'highpass=f=60,afftdn=nf=-35:nr=6,dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'
        Get-WacSettingsTestBytes -Path $sandbox.Config | Should -BeExactly $before
    }

    It 'runs an explicit job while ignoring corrupt saved settings without rewriting them' {
        $sandbox = New-WacSettingsSandbox
        Write-WacSettingsTestJson -Path $sandbox.Config -Json 'corrupt ignored audio settings'
        $before = Get-WacSettingsTestBytes -Path $sandbox.Config
        $result = Invoke-WacSettingsCase -Sandbox $sandbox -Case 'ignore job'
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        Test-Path -LiteralPath $sandbox.RenderArgv | Should -BeTrue
        Get-WacSettingsTestBytes -Path $sandbox.Config | Should -BeExactly $before
    }

    It 'passes explicit false switches through the main entry point over saved true values' {
        $sandbox = New-WacSettingsSandbox
        $null = Save-WacSettings -Path $sandbox.Config -Values @{ Mode = 'Zoom'; OutputDirectory = $sandbox.Output; Mono = $true; Rf64 = $true; BitDepth = '24' }
        $before = Get-WacSettingsTestBytes -Path $sandbox.Config
        $probeJson = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"pcm_s16le","channels":2,"channel_layout":"stereo","sample_rate":"48000","duration":"3"}]}'
        $result = Invoke-WacSettingsCase -Sandbox $sandbox -Case 'false switches job' -ExtraEnvironment @{ WAC_TEST_PROBE_STDOUT = $probeJson }
        $result.ExitCode | Should -Be 5 -Because 'the native fixture writes mono PCM16, so the requested stereo PCM24 output must fail format validation'
        $argv = Get-Content -Raw -LiteralPath $sandbox.RenderArgv | ConvertFrom-Json
        $argv[[Array]::IndexOf($argv, '-ac') + 1] | Should -BeExactly '2'
        $argv[[Array]::IndexOf($argv, '-rf64') + 1] | Should -BeExactly 'never'
        $argv[[Array]::IndexOf($argv, '-c:a') + 1] | Should -BeExactly 'pcm_s24le'
        $argv[[Array]::IndexOf($argv, '-af') + 1] | Should -Not -Match 'pan='
        Get-WacSettingsTestBytes -Path $sandbox.Config | Should -BeExactly $before
    }

    It 'fails missing unattended mode without prompting, rendering or saving defaults' {
        $sandbox = New-WacSettingsSandbox
        $result = Invoke-WacSettingsCase -Sandbox $sandbox -Case 'missing mode'
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        $result.StandardOutput | Should -Not -Match 'Enter selection|Choose an audio|Press any|Select Processing'
        Test-Path -LiteralPath $sandbox.RenderArgv | Should -BeFalse
        Test-Path -LiteralPath $sandbox.Config | Should -BeFalse
    }

    It 'uses the saved absolute stream index and rejects omitted selection without prompting' -ForEach @(
        @{ Selected = $true; ExpectedExit = 0 }; @{ Selected = $false; ExpectedExit = 2 }
    ) {
        $sandbox = New-WacSettingsSandbox
        $values = @{ Mode = 'Zoom'; OutputDirectory = $sandbox.Output }
        if ($Selected) { $values.AudioStreamIndex = '3' }
        $null = Save-WacSettings -Path $sandbox.Config -Values $values
        $before = Get-WacSettingsTestBytes -Path $sandbox.Config
        $probeJson = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"pcm_s16le","channels":1,"channel_layout":"mono","sample_rate":"48000","duration":"3"},{"index":3,"codec_type":"audio","codec_name":"pcm_s16le","channels":1,"channel_layout":"mono","sample_rate":"48000","duration":"3"}]}'
        $result = Invoke-WacSettingsCase -Sandbox $sandbox -Case 'saved job' -ExtraEnvironment @{ WAC_TEST_PROBE_STDOUT = $probeJson }
        $result.ExitCode | Should -Be $ExpectedExit -Because ($result.StandardOutput + $result.StandardError)
        $result.StandardOutput | Should -Not -Match 'Enter selection|Choose an audio|Press any|Select Processing'
        if ($Selected) {
            $argv = Get-Content -Raw -LiteralPath $sandbox.RenderArgv | ConvertFrom-Json
            $argv[[Array]::IndexOf($argv, '-map') + 1] | Should -BeExactly '0:3'
        } else {
            Test-Path -LiteralPath $sandbox.RenderArgv | Should -BeFalse
            @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*_Cleaned_*.wav').Count | Should -Be 0
        }
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.partial' -Force).Count | Should -Be 0
        Get-WacSettingsTestBytes -Path $sandbox.Config | Should -BeExactly $before
    }

    It 'retains positional legacy input with only main/IO when saved settings are explicitly ignored' {
        $sandbox = New-WacSettingsSandbox -WithoutSettings
        $result = Invoke-WacSettingsCase -Sandbox $sandbox -Case 'legacy IO only bypass'
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        Test-Path -LiteralPath (Join-Path $sandbox.Root 'WinAudioClean.Settings.ps1') | Should -BeFalse
        Test-Path -LiteralPath $sandbox.RenderArgv | Should -BeTrue
        Get-WacSettingsTestBytes -Path $sandbox.Input | Should -BeExactly 'AQIDBA=='
    }

    It 'dot-sources main/IO without loading settings or acting on management parameters' {
        $sandbox = New-WacSettingsSandbox -WithoutSettings
        Write-WacSettingsTestJson -Path $sandbox.Config -Json 'corrupt preferences must remain unread'
        $before = Get-WacSettingsTestBytes -Path $sandbox.Config
        $importDriver = Join-Path $sandbox.Root 'Import-SettingsSafety.ps1'
        $importCode = @'
param([string]$App, [string]$Config)
. $App -SettingsPath $Config -ShowSettings -SaveSettings
if (-not (Get-Command Get-WacProcessingProfile -ErrorAction SilentlyContinue)) { throw 'Main helpers unavailable.' }
if (Get-Command Read-WacSettings -ErrorAction SilentlyContinue) { throw 'Settings component unexpectedly imported.' }
Write-Output 'SETTINGS_IMPORT_SAFE'
'@
        [IO.File]::WriteAllText($importDriver, $importCode, (New-Object Text.UTF8Encoding($true)))
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -App {1} -Config {2}' -f
            (ConvertTo-WacTestQuotedArgument $importDriver), (ConvertTo-WacTestQuotedArgument $sandbox.App), (ConvertTo-WacTestQuotedArgument $sandbox.Config)
        $result = Invoke-WacTestProcess -FilePath $settingsShell -Arguments $arguments -WorkingDirectory $sandbox.Root
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $result.StandardOutput.Trim() | Should -BeExactly 'SETTINGS_IMPORT_SAFE'
        Get-WacSettingsTestBytes -Path $sandbox.Config | Should -BeExactly $before
        Test-Path -LiteralPath $sandbox.NativePid | Should -BeFalse
    }
}
