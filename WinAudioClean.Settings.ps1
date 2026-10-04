# Optional per-user settings. Importing this file defines helpers only.
# JSON is data, never PowerShell or a source of arbitrary FFmpeg arguments.
function Initialize-WacSettingsTypes {
    if ('WinAudioClean.SettingsJson' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace WinAudioClean
{
    public static class SettingsJson
    {
        // A bounded JSON reader retains integer token types and decoded object
        // keys. ConvertFrom-Json in supported hosts can erase duplicate keys.
        public static object Parse(string text) { return new Reader(text).Parse(); }
        private sealed class Reader
        {
            private readonly string text;
            private int position, tokens;
            public Reader(string value) { text = value; }
            private FormatException Invalid() { return new FormatException("Settings JSON is malformed."); }
            private void Space()
            {
                while (position < text.Length && (text[position] == ' ' || text[position] == '\t' ||
                    text[position] == '\r' || text[position] == '\n')) position++;
            }
            public object Parse()
            {
                object value = Value(0); Space();
                if (position != text.Length) throw Invalid();
                return value;
            }
            private object Value(int depth)
            {
                if (depth > 32 || ++tokens > 4096) throw new FormatException("Settings JSON is too complex.");
                Space(); if (position >= text.Length) throw Invalid();
                char c = text[position];
                if (c == '{') return Object(depth + 1);
                if (c == '[') return Array(depth + 1);
                if (c == '"') return String();
                if (c == 't') { Literal("true"); return true; }
                if (c == 'f') { Literal("false"); return false; }
                if (c == 'n') { Literal("null"); return null; }
                if (c == '-' || (c >= '0' && c <= '9')) return Number();
                throw Invalid();
            }
            private void Literal(string value)
            {
                if (position + value.Length > text.Length ||
                    System.String.CompareOrdinal(text, position, value, 0, value.Length) != 0) throw Invalid();
                position += value.Length;
            }
            private object Object(int depth)
            {
                var result = new Dictionary<string, object>(StringComparer.Ordinal);
                position++; Space();
                if (position < text.Length && text[position] == '}') { position++; return result; }
                while (true)
                {
                    Space(); if (position >= text.Length || text[position] != '"') throw Invalid();
                    string key = String(); Space();
                    if (position >= text.Length || text[position++] != ':') throw Invalid();
                    if (result.ContainsKey(key)) throw new FormatException("Settings JSON contains a duplicate key.");
                    result.Add(key, Value(depth)); Space();
                    if (position >= text.Length) throw Invalid();
                    char end = text[position++];
                    if (end == '}') return result;
                    if (end != ',') throw Invalid();
                }
            }
            private object Array(int depth)
            {
                var result = new List<object>(); position++; Space();
                if (position < text.Length && text[position] == ']') { position++; return result.ToArray(); }
                while (true)
                {
                    result.Add(Value(depth)); Space(); if (position >= text.Length) throw Invalid();
                    char end = text[position++];
                    if (end == ']') return result.ToArray();
                    if (end != ',') throw Invalid();
                }
            }
            private char Hex()
            {
                if (position + 4 > text.Length) throw Invalid();
                int value = 0;
                for (int n = 0; n < 4; n++)
                {
                    char c = text[position++];
                    int digit = c >= '0' && c <= '9' ? c - '0' :
                        c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1;
                    if (digit < 0) throw Invalid(); value = value * 16 + digit;
                }
                return (char)value;
            }
            private string String()
            {
                position++; var value = new StringBuilder();
                while (position < text.Length)
                {
                    char c = text[position++];
                    if (c == '"') return value.ToString();
                    if (c < 0x20) throw Invalid();
                    if (c != '\\') { value.Append(c); continue; }
                    if (position >= text.Length) throw Invalid();
                    char escape = text[position++];
                    switch (escape)
                    {
                        case '"': value.Append('"'); break;
                        case '\\': value.Append('\\'); break;
                        case '/': value.Append('/'); break;
                        case 'b': value.Append('\b'); break;
                        case 'f': value.Append('\f'); break;
                        case 'n': value.Append('\n'); break;
                        case 'r': value.Append('\r'); break;
                        case 't': value.Append('\t'); break;
                        case 'u':
                            char first = Hex();
                            if (Char.IsHighSurrogate(first))
                            {
                                if (position + 2 > text.Length || text[position++] != '\\' || text[position++] != 'u') throw Invalid();
                                char second = Hex(); if (!Char.IsLowSurrogate(second)) throw Invalid();
                                value.Append(first); value.Append(second);
                            }
                            else { if (Char.IsLowSurrogate(first)) throw Invalid(); value.Append(first); }
                            break;
                        default: throw Invalid();
                    }
                }
                throw Invalid();
            }
            private object Number()
            {
                int start = position;
                if (text[position] == '-') position++;
                if (position >= text.Length) throw Invalid();
                if (text[position] == '0') position++;
                else
                {
                    if (text[position] < '1' || text[position] > '9') throw Invalid();
                    while (position < text.Length && text[position] >= '0' && text[position] <= '9') position++;
                }
                bool integer = true;
                if (position < text.Length && text[position] == '.')
                {
                    integer = false; position++; int digits = position;
                    while (position < text.Length && text[position] >= '0' && text[position] <= '9') position++;
                    if (position == digits) throw Invalid();
                }
                if (position < text.Length && (text[position] == 'e' || text[position] == 'E'))
                {
                    integer = false; position++;
                    if (position < text.Length && (text[position] == '+' || text[position] == '-')) position++;
                    int digits = position;
                    while (position < text.Length && text[position] >= '0' && text[position] <= '9') position++;
                    if (position == digits) throw Invalid();
                }
                string number = text.Substring(start, position - start);
                if (integer)
                {
                    long value;
                    if (!Int64.TryParse(number, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out value))
                        throw new FormatException("Settings JSON integer is outside the supported range.");
                    return value;
                }
                double result;
                if (!Double.TryParse(number, NumberStyles.Float, CultureInfo.InvariantCulture, out result) ||
                    Double.IsNaN(result) || Double.IsInfinity(result))
                    throw new FormatException("Settings JSON numbers must be finite.");
                return result;
            }
        }
    }

    public static class SettingsFileIO
    {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern SafeFileHandle CreateFileW(string path, uint access, uint share,
            IntPtr security, uint disposition, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetFileInformationByHandleEx(SafeFileHandle file, int kind, IntPtr information, uint size);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetFileInformationByHandle(SafeFileHandle file, int kind, IntPtr information, uint size);
        public static FileStream Open(string path, bool createNew)
        {
            // OPEN_REPARSE_POINT inspects the leaf itself. A new temp retains
            // DELETE ownership and denies other writers/deleters through save.
            SafeFileHandle handle = CreateFileW(path, createNew ? 0xC0010000u : 0x80000000u,
                1u, IntPtr.Zero, createNew ? 1u : 3u, 0x00200080u, IntPtr.Zero);
            if (handle.IsInvalid)
            {
                int code = Marshal.GetLastWin32Error(); handle.Dispose();
                throw new IOException("Cannot open settings file (Win32 " + code + ").");
            }
            IntPtr information = Marshal.AllocHGlobal(24);
            try
            {
                if (!GetFileInformationByHandleEx(handle, 9, information, 8) || (Marshal.ReadInt32(information) & 0x410) != 0)
                    throw new IOException("Settings path must be an ordinary file, not a reparse point or directory.");
                if (!GetFileInformationByHandleEx(handle, 1, information, 24) || Marshal.ReadInt32(information, 16) != 1)
                    throw new IOException("Settings files with multiple filesystem links are unsupported.");
                return new FileStream(handle, createNew ? FileAccess.ReadWrite : FileAccess.Read);
            }
            catch { handle.Dispose(); throw; }
            finally { Marshal.FreeHGlobal(information); }
        }
        public static void Publish(FileStream stream, string destination, bool replace)
        {
            string leaf = Path.GetFileName(destination);
            if (String.IsNullOrEmpty(leaf) || leaf.IndexOf(':') >= 0)
                throw new IOException("Settings publication requires an ordinary filename.");
            // Match the existing IO helper's FILE_RENAME_INFO layout. The
            // destination directory stays pinned by the PowerShell caller.
            byte[] name = Encoding.Unicode.GetBytes(destination);
            int rootOffset = IntPtr.Size == 8 ? 8 : 4;
            int lengthOffset = rootOffset + IntPtr.Size;
            int nameOffset = lengthOffset + 4;
            int size = checked(nameOffset + name.Length + 2);
            IntPtr information = Marshal.AllocHGlobal(size);
            try
            {
                for (int index = 0; index < size; index++) Marshal.WriteByte(information, index, 0);
                Marshal.WriteByte(information, replace ? (byte)1 : (byte)0);
                Marshal.WriteIntPtr(information, rootOffset, IntPtr.Zero);
                Marshal.WriteInt32(information, lengthOffset, name.Length);
                Marshal.Copy(name, 0, IntPtr.Add(information, nameOffset), name.Length);
                if (!SetFileInformationByHandle(stream.SafeFileHandle, 3, information, (uint)size))
                    throw new IOException("Cannot publish settings atomically (Win32 " + Marshal.GetLastWin32Error() + ").");
            }
            finally { Marshal.FreeHGlobal(information); }
        }
    }
}
'@ -ErrorAction Stop
}

function Get-WacDefaultSettingsPath {
    $folder = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
    if ([string]::IsNullOrWhiteSpace($folder)) { throw 'The current user application-data folder is unavailable.' }
    [IO.Path]::Combine($folder, 'WinAudioClean', 'settings.json')
}

function Assert-WacSettingsPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $resolved = Resolve-WacFileSystemPath -Path $Path
    $cursor = $resolved; $leaf = $true
    while (-not [string]::IsNullOrEmpty($cursor)) {
        $attributes = $null
        try { $attributes = [IO.File]::GetAttributes($cursor) }
        catch [IO.FileNotFoundException] { $attributes = $null }
        catch [IO.DirectoryNotFoundException] { $attributes = $null }
        catch { throw 'Cannot inspect the settings path.' }
        if ($null -ne $attributes) {
            if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Settings paths cannot contain reparse points.'
            }
            $isDirectory = ($attributes -band [IO.FileAttributes]::Directory) -ne 0
            if (($leaf -and $isDirectory) -or (-not $leaf -and -not $isDirectory)) {
                throw 'Settings require an ordinary file beneath ordinary directories.'
            }
        }
        $leaf = $false; $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
    $resolved
}

function Get-WacSettingsNames {
    @('Mode', 'Preset', 'LoudnessMode', 'BitDepth', 'Mono', 'Rf64', 'OutputDirectory', 'AudioStreamIndex', 'CleaningOptions')
}

function ConvertTo-WacValidatedSettingsValues {
    param([Parameter(Mandatory = $true)][System.Collections.IDictionary]$Values,
        [switch]$Explicit, [switch]$AllowUnset)
    $result = @{}; $names = @(Get-WacSettingsNames)
    foreach ($key in $Values.Keys) {
        if ($key -isnot [string] -or $key -notin $names -or (-not $Explicit -and $key -cnotin $names)) {
            if ($Explicit) { continue }
            throw 'Unknown saved settings field.'
        }
        $name = @($names | Where-Object { $_ -ieq $key })[0]
        if ($result.ContainsKey($name)) { throw 'Duplicate settings field.' }
        $value = $Values[$key]
        if ($AllowUnset -and $name -in @('Mode', 'AudioStreamIndex') -and $null -eq $value) { continue }
        switch ($name) {
            { $_ -in @('Mode', 'Preset', 'LoudnessMode') } {
                $allowed = switch ($name) { 'Mode' { @('Raw', 'Zoom') } 'Preset' { @('Original', 'Gentle') } 'LoudnessMode' { @('Fast', 'Accurate') } }
                if ($value -isnot [string] -or $value -notin $allowed) { throw "Settings $name has an unsupported value." }
                $result[$name] = @($allowed | Where-Object { $_ -ieq $value })[0]
            }
            'BitDepth' {
                if (($value -isnot [string] -and $value -isnot [int] -and $value -isnot [long]) -or
                    [string]$value -cnotin @('16', '24')) { throw 'Settings BitDepth must be 16 or 24.' }
                $result[$name] = [string]$value
            }
            { $_ -in @('Mono', 'Rf64') } {
                if ($Explicit -and $value -is [Management.Automation.SwitchParameter]) { $value = [bool]$value }
                if ($value -isnot [bool]) { throw "Settings $name must be a Boolean." }
                $result[$name] = $value
            }
            'OutputDirectory' {
                if ($value -isnot [string]) { throw 'Settings OutputDirectory must be a filesystem path string.' }
                $result[$name] = Resolve-WacFileSystemPath -Path $value
            }
            'AudioStreamIndex' {
                $index = 0
                if (($value -isnot [string] -and $value -isnot [int] -and $value -isnot [long]) -or
                    [string]$value -cnotmatch '^[0-9]+$' -or
                    -not [int]::TryParse([string]$value, [Globalization.NumberStyles]::None,
                        [Globalization.CultureInfo]::InvariantCulture, [ref]$index)) {
                    throw 'Settings AudioStreamIndex must be a nonnegative integer through 2147483647.'
                }
                $result[$name] = $index.ToString([Globalization.CultureInfo]::InvariantCulture)
            }
            'CleaningOptions' {
                if ($value -isnot [System.Collections.IDictionary]) { throw 'Settings CleaningOptions must be a typed object.' }
                $options = @{}
                foreach ($option in $value.Keys) {
                    $optionNames = @('Declip', 'Declick', 'Denoise', 'Gate', 'HighpassHz', 'NoiseFloorDb',
                        'NoiseReductionDb', 'GateThresholdDb', 'GateRangeDb')
                    if ($option -isnot [string] -or ($Explicit -and $option -notin $optionNames) -or
                        (-not $Explicit -and $option -cnotin $optionNames)) {
                        throw 'Unknown or incorrectly cased cleaning settings field.'
                    }
                    $optionName = @($optionNames | Where-Object { $_ -ieq $option })[0]
                    if ($options.ContainsKey($optionName)) { throw 'Duplicate cleaning settings field.' }
                    $options[$optionName] = $value[$option]
                }
                $null = Get-WacCleaningSettings -Options $options
                $result[$name] = $options
            }
        }
    }
    $result
}

function Assert-WacSettingsCombination {
    param([System.Collections.IDictionary]$Values)
    $preset = if ($Values.Contains('Preset')) { $Values.Preset } else { 'Original' }
    $options = if ($Values.Contains('CleaningOptions')) { $Values.CleaningOptions } else { @{} }
    $null = Get-WacCleaningSettings -Preset $preset -Options $options
    if ($Values.Contains('Mode')) {
        $choice = if ($Values.Mode -eq 'Raw') { '1' } else { '2' }
        $null = Get-WacProcessingProfile -Choice $choice -Preset $preset -CleaningOptions $options
    }
}

function Read-WacSettings {
    param([Parameter(Mandatory = $true)][string]$Path)
    $resolved = Assert-WacSettingsPath -Path $Path
    if (-not [IO.File]::Exists($resolved)) { return @{} }
    Initialize-WacNativeFileIO
    Initialize-WacSettingsTypes
    $stream = $null
    try {
        $stream = [WinAudioClean.SettingsFileIO]::Open($resolved, $false)
        if ([WinAudioClean.NativeFileIO]::ResolvedPath($stream.SafeFileHandle) -ine $resolved) {
            throw 'Settings path changed or was redirected.'
        }
        if ($stream.Length -gt 65536) { throw 'Settings file exceeds the 64 KiB limit.' }
        $bytes = New-Object byte[] ([int]$stream.Length)
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $count = $stream.Read($bytes, $offset, $bytes.Length - $offset)
            if ($count -eq 0) { throw 'Settings file could not be read completely.' }
            $offset += $count
        }
        $start = if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { 3 } else { 0 }
        try { $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes, $start, $bytes.Length - $start) }
        catch { throw 'Settings file must contain valid UTF-8 JSON.' }
        try { $document = [WinAudioClean.SettingsJson]::Parse($text) }
        catch { throw ('Cannot read settings JSON: ' + $_.Exception.GetBaseException().Message) }
        if ($document -isnot [System.Collections.IDictionary]) { throw 'Settings JSON must be an object.' }
        if ($document.Count -ne 2 -or -not $document.ContainsKey('schemaVersion') -or -not $document.ContainsKey('settings')) {
            throw 'Settings JSON requires only schemaVersion and settings fields with exact casing.'
        }
        if ($document['schemaVersion'] -isnot [long] -or $document['schemaVersion'] -ne 1) {
            throw 'Unsupported settings schemaVersion; expected integer 1. Use -ResetSettings to restore defaults.'
        }
        $saved = $document['settings']
        if ($saved -isnot [System.Collections.IDictionary]) { throw 'The settings field must be an object.' }
        $map = [ordered]@{ mode = 'Mode'; preset = 'Preset'; loudnessMode = 'LoudnessMode'; bitDepth = 'BitDepth';
            mono = 'Mono'; rf64 = 'Rf64'; outputDirectory = 'OutputDirectory'; audioStreamIndex = 'AudioStreamIndex'; cleaningOptions = 'CleaningOptions' }
        $values = @{}
        foreach ($key in $saved.Keys) {
            if ($key -cnotin @($map.Keys)) { throw 'Unknown or incorrectly cased settings field.' }
            $value = $saved[$key]
            if ($key -in @('bitDepth', 'audioStreamIndex')) {
                if ($value -isnot [long]) { throw "Settings $key must be a JSON integer." }
            }
            $values[$map[$key]] = $value
        }
        $validated = ConvertTo-WacValidatedSettingsValues -Values $values
        Assert-WacSettingsCombination -Values $validated
        $validated
    } finally { if ($null -ne $stream) { $stream.Dispose() } }
}

function Resolve-WacSettings {
    param([System.Collections.IDictionary]$Explicit = @{}, [System.Collections.IDictionary]$Saved = @{})
    if ($null -eq $Explicit -or $null -eq $Saved) { throw 'Settings inputs must be dictionaries, not null.' }
    $savedValues = ConvertTo-WacValidatedSettingsValues -Values $Saved
    Assert-WacSettingsCombination -Values $savedValues
    $cliValues = ConvertTo-WacValidatedSettingsValues -Values $Explicit -Explicit
    $values = @{ Mode = $null; Preset = 'Original'; LoudnessMode = 'Fast'; BitDepth = '16'; Mono = $false; Rf64 = $false;
        OutputDirectory = Get-WacDefaultOutputDirectory; AudioStreamIndex = $null; CleaningOptions = @{} }
    $origins = @{}
    foreach ($name in @(Get-WacSettingsNames)) {
        $origins[$name] = 'BuiltIn'
        if ($savedValues.ContainsKey($name)) { $values[$name] = $savedValues[$name]; $origins[$name] = 'Saved' }
        if ($cliValues.ContainsKey($name)) { $values[$name] = $cliValues[$name]; $origins[$name] = 'CLI' }
    }
    $combination = @{}
    foreach ($name in $values.Keys) { if ($null -ne $values[$name]) { $combination[$name] = $values[$name] } }
    Assert-WacSettingsCombination -Values $combination
    [pscustomobject]@{ Values = $values; Origins = $origins }
}

function ConvertTo-WacSettingsJson {
    param([Parameter(Mandatory = $true)][System.Collections.IDictionary]$Values)
    $validated = ConvertTo-WacValidatedSettingsValues -Values $Values -AllowUnset
    Assert-WacSettingsCombination -Values $validated
    $settings = [ordered]@{}
    $map = [ordered]@{ Mode = 'mode'; Preset = 'preset'; LoudnessMode = 'loudnessMode'; BitDepth = 'bitDepth';
        Mono = 'mono'; Rf64 = 'rf64'; OutputDirectory = 'outputDirectory'; AudioStreamIndex = 'audioStreamIndex'; CleaningOptions = 'cleaningOptions' }
    foreach ($name in $map.Keys) {
        if (-not $validated.ContainsKey($name)) { continue }
        $value = $validated[$name]
        if ($name -in @('BitDepth', 'AudioStreamIndex')) { $value = [int]$value }
        if ($name -eq 'CleaningOptions') {
            $orderedOptions = [ordered]@{}
            foreach ($option in @('Declip', 'Declick', 'Denoise', 'Gate', 'HighpassHz', 'NoiseFloorDb',
                'NoiseReductionDb', 'GateThresholdDb', 'GateRangeDb')) {
                if ($value.Contains($option)) { $orderedOptions[$option] = $value[$option] }
            }
            $value = $orderedOptions
        }
        $settings[$map[$name]] = $value
    }
    $json = [ordered]@{ schemaVersion = 1; settings = $settings } | ConvertTo-Json -Depth 8 -Compress
    if ([Text.UTF8Encoding]::new($false, $true).GetByteCount($json) -gt 65536) { throw 'Settings JSON exceeds the 64 KiB limit.' }
    $json
}

function Publish-WacSettingsFile {
    param([Parameter(Mandatory = $true)][string]$TempPath,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][bool]$DestinationExists,
        [Parameter(Mandatory = $true)][IO.FileStream]$Writer,
        [Parameter(Mandatory = $true)][Microsoft.Win32.SafeHandles.SafeFileHandle]$Directory)
    $null = Assert-WacSettingsPath -Path $Path
    if ([WinAudioClean.NativeFileIO]::ResolvedPath($Writer.SafeFileHandle) -ine $TempPath -or
        [WinAudioClean.NativeFileIO]::ResolvedPath($Directory) -ine [IO.Path]::GetDirectoryName($Path)) {
        throw 'Settings publication ownership or directory changed.'
    }
    [WinAudioClean.SettingsFileIO]::Publish($Writer, $Path, $DestinationExists)
}

function Save-WacSettings {
    param([Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Values)
    # Serialize/validate before allocating directories or temporary files.
    $json = ConvertTo-WacSettingsJson -Values $Values
    $resolved = Assert-WacSettingsPath -Path $Path
    $parent = [IO.Path]::GetDirectoryName($resolved)
    $null = [IO.Directory]::CreateDirectory($parent)
    $null = Assert-WacSettingsPath -Path $resolved
    Initialize-WacNativeFileIO
    Initialize-WacSettingsTypes
    $directory = $null; $temp = $null; $tempPath = $null; $published = $false; $failure = $null; $cleanupFailed = $false
    try {
        $directory = [WinAudioClean.NativeFileIO]::OpenDirectory($parent)
        if ([WinAudioClean.NativeFileIO]::ResolvedPath($directory) -ine $parent) { throw 'Settings directory changed or was redirected.' }
        $destinationExists = [IO.File]::Exists($resolved)
        $tempPath = [IO.Path]::Combine($parent, ('.wac-settings-' + [guid]::NewGuid().ToString('N') + '.tmp'))
        $temp = [WinAudioClean.SettingsFileIO]::Open($tempPath, $true)
        $identity = [WinAudioClean.NativeFileIO]::Identity($temp.SafeFileHandle)
        $bytes = [Text.UTF8Encoding]::new($false, $true).GetBytes($json)
        $temp.Write($bytes, 0, $bytes.Length)
        $temp.Flush($true)
        if ([WinAudioClean.NativeFileIO]::Identity($temp.SafeFileHandle) -ne $identity -or
            [WinAudioClean.NativeFileIO]::ResolvedPath($temp.SafeFileHandle) -ine $tempPath) {
            throw 'Settings temporary-file ownership changed.'
        }
        Publish-WacSettingsFile -TempPath $tempPath -Path $resolved -DestinationExists $destinationExists -Writer $temp -Directory $directory
        $published = $true
    } catch { $failure = $_ }
    finally {
        if ($null -ne $temp) {
            if (-not $published) {
                try {
                    $ownedPath = [WinAudioClean.NativeFileIO]::ResolvedPath($temp.SafeFileHandle)
                    if ($ownedPath -ieq $resolved) {
                        # A publisher that failed after its atomic move committed
                        # the new file. Preserve it and report an advisory.
                        $published = $true; $failure = $null
                        Write-Warning 'Settings were saved, but a later publication check failed.'
                    } elseif ($ownedPath -ieq $tempPath) { [WinAudioClean.NativeFileIO]::DeleteOwned($temp) }
                    else { $cleanupFailed = $true }
                } catch { $cleanupFailed = $true }
            }
            try { $temp.Dispose() } catch { if ($published) { Write-Warning 'Settings were saved, but closing the settings handle failed.' } else { $cleanupFailed = $true } }
        }
        if ($null -ne $directory) {
            try { $directory.Dispose() } catch { if ($published) { Write-Warning 'Settings were saved, but closing the directory handle failed.' } else { $cleanupFailed = $true } }
        }
    }
    if ($cleanupFailed) { throw 'Settings save failed; the owned temporary file could not be cleaned up.' }
    if ($null -ne $failure) { throw $failure }
    $resolved
}
