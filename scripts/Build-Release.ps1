#requires -Version 5.1
<#
.SYNOPSIS
Builds an unpublished tool-only package from the current clean Git revision.
.PARAMETER Revision
The exact forty-character lowercase commit ID. It must equal clean HEAD.
.PARAMETER OutputDirectory
An ordinary destination directory. Existing output files are never replaced.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$Revision,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$gitPath = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source

function Assert-ReleaseDirectory {
    param([string]$Directory, [switch]$AllowMissing)
    $current = [IO.Path]::GetFullPath($Directory)
    while ($current) {
        try { $attributes = [IO.File]::GetAttributes($current) }
        catch [IO.FileNotFoundException] {
            if (-not $AllowMissing) { throw 'A required directory is missing.' }
            $current = [IO.Path]::GetDirectoryName($current)
            continue
        }
        catch [IO.DirectoryNotFoundException] {
            if (-not $AllowMissing) { throw 'A required directory is missing.' }
            $current = [IO.Path]::GetDirectoryName($current)
            continue
        }
        if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
            ($attributes -band [IO.FileAttributes]::Directory) -eq 0) {
            throw 'Directory ancestry must contain ordinary directories without reparse points.'
        }
        $current = [IO.Path]::GetDirectoryName($current)
    }
}

function ConvertTo-ReleaseArgument {
    param([string]$Value)
    if ($Value -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-ReleaseGit {
    param([string[]]$Arguments)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $gitPath
    $start.WorkingDirectory = $repoRoot
    $allArguments = @('--no-optional-locks', '-c', 'core.fsmonitor=false') + $Arguments
    $start.Arguments = ($allArguments | ForEach-Object { ConvertTo-ReleaseArgument $_ }) -join ' '
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $buffer = [IO.MemoryStream]::new()
    $started = $false
    $stdoutReader = $null
    $stderrReader = $null
    try {
        $started = $process.Start()
        if (-not $started) { throw 'Git did not start.' }
        $stdoutReader = $process.StandardOutput
        $stderrReader = $process.StandardError
        # Never pass committed payload bytes through PowerShell native text conversion.
        $copy = $stdoutReader.BaseStream.CopyToAsync($buffer)
        $errors = $stderrReader.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) { throw 'Git exceeded its bounded execution time.' }
        if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($copy, $errors), 5000)) {
            throw 'Git output did not close within its bounded execution time.'
        }
        if ($process.ExitCode -ne 0) { throw 'Git could not read the requested clean source.' }
        return [pscustomobject]@{ Bytes = $buffer.ToArray() }
    } finally {
        try {
            if ($started -and -not $process.HasExited) {
                $process.Kill()
                [void]$process.WaitForExit(5000)
            }
        } finally {
            try { if ($stdoutReader) { $stdoutReader.Dispose() } }
            finally {
                try { if ($stderrReader) { $stderrReader.Dispose() } }
                finally { $buffer.Dispose(); $process.Dispose() }
            }
        }
    }
}

function Get-ReleaseState {
    $head = $utf8.GetString((Invoke-ReleaseGit @('rev-parse', '--verify', 'HEAD^{commit}')).Bytes).Trim()
    $tree = $utf8.GetString((Invoke-ReleaseGit @('rev-parse', '--verify', 'HEAD^{tree}')).Bytes).Trim()
    if ($head -cnotmatch '^[0-9a-f]{40}$' -or $tree -cnotmatch '^[0-9a-f]{40}$') {
        throw 'The repository must use forty-character Git source identities.'
    }
    $status = Invoke-ReleaseGit @('status', '--porcelain=v1', '--untracked-files=all', '-z')
    if ($status.Bytes.Length -ne 0) { throw 'A clean checkout is required, including nonignored untracked files.' }
    return [pscustomobject]@{ Commit = $head; Tree = $tree }
}

function Get-ReleaseVersion {
    param([byte[]]$MainBytes)
    $text = $utf8.GetString($MainBytes)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -ne 0) { throw 'The committed main script does not parse.' }
    $assignments = @($ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
        $node.Left.VariablePath.UserPath -match '(^|:)scriptVersion$'
    }, $false))
    if ($assignments.Count -ne 1 -or
        $assignments[0].Left.VariablePath.UserPath -ine 'scriptVersion' -or
        $assignments[0].Operator -ne [Management.Automation.Language.TokenKind]::Equals -or
        $assignments[0].Right -isnot [Management.Automation.Language.CommandExpressionAst] -or
        $assignments[0].Right.Expression -isnot [Management.Automation.Language.StringConstantExpressionAst]) {
        throw 'The version requires exactly one literal scriptVersion assignment.'
    }
    $version = $assignments[0].Right.Expression.Value
    if ($version.Length -gt 32 -or $version -cnotmatch '^[0-9]+\.[0-9]+(?:\.[0-9]+){0,2}$') {
        throw 'The literal application version must be a safe numeric dotted version.'
    }
    return $version
}

function Get-ReleaseSha256 {
    param([byte[]]$Bytes)
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hash.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $hash.Dispose() }
}

function ConvertTo-ReleaseJson {
    param([string]$Version, [string]$Commit, [string]$Tree, [object[]]$Payload, [string]$ZipSha256)
    # These fields are fixed or validated ASCII; explicit LF serialization is identical on both hosts.
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('{')
    $lines.Add('  "schema_version": 1,')
    $lines.Add('  "application": "WinAudioClean",')
    $lines.Add('  "version": "' + $Version + '",')
    $lines.Add('  "source_commit": "' + $Commit + '",')
    $lines.Add('  "source_tree": "' + $Tree + '",')
    $lines.Add('  "payload": [')
    for ($index = 0; $index -lt $Payload.Count; $index++) {
        $item = $Payload[$index]
        $length = $item.bytes.ToString([Globalization.CultureInfo]::InvariantCulture)
        $suffix = if ($index -lt $Payload.Count - 1) { ',' } else { '' }
        $lines.Add('    {"path": "' + $item.path + '", "bytes": ' + $length + ', "sha256": "' + $item.sha256 + '"}' + $suffix)
    }
    $lines.Add('  ]' + $(if ($ZipSha256) { ',' } else { '' }))
    if ($ZipSha256) { $lines.Add('  "zip_sha256": "' + $ZipSha256 + '"') }
    $lines.Add('}')
    return ($lines -join "`n") + "`n"
}

Assert-ReleaseDirectory $repoRoot
$topLevel = $utf8.GetString((Invoke-ReleaseGit @('rev-parse', '--show-toplevel')).Bytes).Trim()
if (-not [string]::Equals([IO.Path]::GetFullPath($topLevel), $repoRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The builder must reside in the root repository scripts directory.'
}
$before = Get-ReleaseState
if ($before.Commit -cne $Revision) { throw 'Revision must equal the current clean HEAD.' }

[string[]]$payloadPaths = @(
    'WinAudioClean.ps1', 'WinAudioClean.Batch.ps1', 'WinAudioClean.IO.ps1',
    'WinAudioClean.Launcher.ps1', 'WinAudioClean.Output.ps1', 'WinAudioClean.Preview.ps1',
    'WinAudioClean.Queue.ps1', 'WinAudioClean.Settings.ps1', 'WinAudioClean.bat',
    'WinAudioClean.ico', 'LICENSE', 'README.md', 'docs/PORTABLE_PACKAGE.md',
    'THIRD_PARTY_NOTICES.md', 'docs/SUPPORT.md', 'docs/SECURITY.md', 'docs/codex/winaudioclean/DATA_FORMATS.md'
)
[Array]::Sort($payloadPaths, [StringComparer]::Ordinal)
$blobs = @{}
$payload = @()
foreach ($path in $payloadPaths) {
    $entry = $utf8.GetString((Invoke-ReleaseGit @('ls-tree', '-z', $Revision, '--', $path)).Bytes)
    if ($entry -cnotmatch ('\A100(?:644|755) blob [0-9a-f]{40}\t' + [regex]::Escape($path) + '\x00\z')) {
        throw 'Every allowlisted payload entry must be a committed ordinary Git blob.'
    }
    $bytes = (Invoke-ReleaseGit @('cat-file', 'blob', ($Revision + ':' + $path))).Bytes
    $blobs[$path] = $bytes
    $payload += [pscustomobject]@{ path = $path; bytes = $bytes.Length; sha256 = Get-ReleaseSha256 $bytes }
}
$version = Get-ReleaseVersion $blobs['WinAudioClean.ps1']
$baseName = 'WinAudioClean-' + $version + '-' + $Revision.Substring(0, 12) + '-tool-only'
$zipName = $baseName + '.zip'
$checksumName = $baseName + '.sha256'
$provenanceName = $baseName + '.provenance.json'
$outputProvider = $null
$outputDrive = $null
$outputRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory, [ref]$outputProvider, [ref]$outputDrive)
if ($outputProvider.Name -ne 'FileSystem') { throw 'OutputDirectory must use the filesystem provider.' }
$outputRoot = [IO.Path]::GetFullPath($outputRoot)
Assert-ReleaseDirectory $outputRoot -AllowMissing
[void][IO.Directory]::CreateDirectory($outputRoot)
Assert-ReleaseDirectory $outputRoot
foreach ($name in @($zipName, $checksumName, $provenanceName)) {
    foreach ($existing in [IO.Directory]::EnumerateFileSystemEntries($outputRoot)) {
        if ([string]::Equals([IO.Path]::GetFileName($existing), $name, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'A release output already exists; choose a new destination without replacing it.'
        }
    }
}
# Output beneath the source tree must be ignored, so the builder cannot dirty its own source guard.
$repoPrefix = $repoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if ($outputRoot.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase) -or
    [string]::Equals($outputRoot, $repoRoot, [StringComparison]::OrdinalIgnoreCase)) {
    foreach ($name in @($zipName, $checksumName, $provenanceName)) {
        $relative = (Join-Path $outputRoot $name).Substring($repoRoot.Length + 1).Replace('\', '/')
        [void](Invoke-ReleaseGit @('check-ignore', '--quiet', '--no-index', '--', $relative))
    }
}

$manifestText = ConvertTo-ReleaseJson $version $before.Commit $before.Tree $payload
$blobs['PACKAGE-MANIFEST.json'] = $utf8.GetBytes($manifestText)
[string[]]$zipPaths = @($payloadPaths) + @('PACKAGE-MANIFEST.json')
[Array]::Sort($zipPaths, [StringComparer]::Ordinal)
# Framework ZipArchive NoCompression uses deflate blocks; Core uses Stored.
# Write canonical Stored ZIP32 headers explicitly to preserve cross-host bytes.
if (-not ('WacReleaseStoredZipV1' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Text;

public static class WacReleaseStoredZipV1
{
    private sealed class Entry
    {
        public byte[] Name;
        public uint Size, Crc, Offset;
    }
    private static readonly uint[] CrcTable = CreateCrcTable();
    private static uint[] CreateCrcTable()
    {
        uint[] table = new uint[256];
        for (uint index = 0; index < 256; index++)
        {
            uint value = index;
            for (int bit = 0; bit < 8; bit++)
                value = (value & 1) != 0 ? 0xEDB88320U ^ (value >> 1) : value >> 1;
            table[index] = value;
        }
        return table;
    }
    private static uint Crc(byte[] bytes)
    {
        uint value = 0xFFFFFFFFU;
        for (int index = 0; index < bytes.Length; index++)
            value = CrcTable[(value ^ bytes[index]) & 255] ^ (value >> 8);
        return value ^ 0xFFFFFFFFU;
    }
    public static void Write(Stream output, string[] paths, IDictionary payload)
    {
        if (paths.Length > UInt16.MaxValue) throw new InvalidDataException("ZIP32 entry limit exceeded.");
        var entries = new List<Entry>();
        using (var writer = new BinaryWriter(output, new UTF8Encoding(false), true))
        {
            foreach (string path in paths)
            {
                byte[] bytes = (byte[])payload[path];
                var entry = new Entry {
                    Name = Encoding.UTF8.GetBytes(path), Size = checked((uint)bytes.Length),
                    Crc = Crc(bytes), Offset = checked((uint)output.Position)
                };
                if (entry.Name.Length > UInt16.MaxValue) throw new InvalidDataException("ZIP32 name limit exceeded.");
                entries.Add(entry);
                writer.Write(0x04034B50U);
                writer.Write((ushort)20); writer.Write((ushort)2048); writer.Write((ushort)0);
                writer.Write((ushort)0); writer.Write((ushort)33); // 1980-01-01 00:00:00.
                writer.Write(entry.Crc); writer.Write(entry.Size); writer.Write(entry.Size);
                writer.Write((ushort)entry.Name.Length); writer.Write((ushort)0);
                writer.Write(entry.Name); writer.Write(bytes);
            }
            uint centralOffset = checked((uint)output.Position);
            foreach (Entry entry in entries)
            {
                writer.Write(0x02014B50U);
                writer.Write((ushort)20); writer.Write((ushort)20); writer.Write((ushort)2048);
                writer.Write((ushort)0); writer.Write((ushort)0); writer.Write((ushort)33);
                writer.Write(entry.Crc); writer.Write(entry.Size); writer.Write(entry.Size);
                writer.Write((ushort)entry.Name.Length); writer.Write((ushort)0); writer.Write((ushort)0);
                writer.Write((ushort)0); writer.Write((ushort)0); writer.Write(0U); writer.Write(entry.Offset);
                writer.Write(entry.Name);
            }
            uint centralSize = checked((uint)(output.Position - centralOffset));
            if (output.Position > UInt32.MaxValue - 22L)
                throw new InvalidDataException("ZIP32 archive size limit exceeded.");
            writer.Write(0x06054B50U);
            writer.Write((ushort)0); writer.Write((ushort)0);
            writer.Write((ushort)entries.Count); writer.Write((ushort)entries.Count);
            writer.Write(centralSize); writer.Write(centralOffset); writer.Write((ushort)0);
        }
    }
}
'@
}
$zipPath = Join-Path $outputRoot $zipName
Assert-ReleaseDirectory $outputRoot
$zipFile = [IO.FileStream]::new($zipPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
    [WacReleaseStoredZipV1]::Write($zipFile, $zipPaths, $blobs)
    $zipFile.Position = 0
    $zipHash = [Security.Cryptography.SHA256]::Create()
    try { $zipSha256 = ([BitConverter]::ToString($zipHash.ComputeHash($zipFile))).Replace('-', '').ToLowerInvariant() }
    finally { $zipHash.Dispose() }
} finally { $zipFile.Dispose() }
$checksumText = $zipSha256 + '  ' + $zipName + "`n"
$provenanceText = ConvertTo-ReleaseJson $version $before.Commit $before.Tree $payload $zipSha256
foreach ($output in @(
    @{ Name = $checksumName; Text = $checksumText },
    @{ Name = $provenanceName; Text = $provenanceText }
)) {
    Assert-ReleaseDirectory $outputRoot
    $file = [IO.FileStream]::new((Join-Path $outputRoot $output.Name), [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $bytes = $utf8.GetBytes($output.Text)
        $file.Write($bytes, 0, $bytes.Length)
    } finally { $file.Dispose() }
}
Assert-ReleaseDirectory $repoRoot
$after = Get-ReleaseState
if ($after.Commit -cne $before.Commit -or $after.Tree -cne $before.Tree) {
    throw 'Source identities changed during packaging; the retained files are not an accepted build.'
}
[pscustomobject]@{
    application = 'WinAudioClean'; version = $version
    source_commit = $before.Commit; source_tree = $before.Tree
    zip = $zipName; checksum = $checksumName; provenance = $provenanceName; zip_sha256 = $zipSha256
}
