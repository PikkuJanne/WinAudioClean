#requires -Version 5.1
<#
.SYNOPSIS
Explicitly installs the pinned test modules into this checkout's ignored local folder.
.DESCRIPTION
Downloads only when invoked by the developer. Verifies each official Gallery
package against the committed SHA512 digest before extraction. Does not change
repositories, profiles, execution policy, PSModulePath, or global/user modules.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $repoRoot '.wac-local/Modules'
$stagingRoot = Join-Path $repoRoot '.wac-local/dev-setup'
$dependencies = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'DevDependencies.psd1')
[void](New-Item -ItemType Directory -Path $moduleRoot -Force)
[void](New-Item -ItemType Directory -Path $stagingRoot -Force)

foreach ($dependency in $dependencies.Modules) {
    $moduleParent = Join-Path $moduleRoot $dependency.Name
    $destination = Join-Path $moduleParent $dependency.Version
    $manifestPath = Join-Path $destination ($dependency.Name + '.psd1')
    if (Test-Path -LiteralPath $destination) {
        $installed = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        if ($installed.Version -ne [version]$dependency.Version) {
            throw "Unexpected module version in $destination. Inspect that folder before retrying."
        }
        Write-Information -InformationAction Continue -MessageData "$($dependency.Name) $($dependency.Version) already present."
        continue
    }

    $stage = Join-Path $stagingRoot ([guid]::NewGuid().ToString('N'))
    $archive = Join-Path $stage 'package.zip'
    $unpacked = Join-Path $stage 'module'
    [void](New-Item -ItemType Directory -Path $stage)
    $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
    try {
        # Windows PowerShell 5.1 may otherwise negotiate an obsolete TLS version.
        [Net.ServicePointManager]::SecurityProtocol = $previousProtocol -bor [Net.SecurityProtocolType]::Tls12
        Write-Information -InformationAction Continue -MessageData "Downloading $($dependency.Name) $($dependency.Version) from PowerShell Gallery..."
        Invoke-WebRequest -UseBasicParsing -Uri $dependency.Uri -OutFile $archive
        $hash = [Security.Cryptography.SHA512]::Create()
        $stream = [IO.File]::OpenRead($archive)
        try {
            $actualHash = [Convert]::ToBase64String($hash.ComputeHash($stream))
        }
        finally {
            $stream.Dispose()
            $hash.Dispose()
        }
        if ($actualHash -cne $dependency.Sha512) {
            throw "SHA512 mismatch for $($dependency.Name) $($dependency.Version); package was not installed."
        }
        Expand-Archive -LiteralPath $archive -DestinationPath $unpacked
        $packageManifest = Join-Path $unpacked ($dependency.Name + '.psd1')
        $package = Test-ModuleManifest -Path $packageManifest -ErrorAction Stop
        if ($package.Name -ne $dependency.Name -or $package.Version -ne [version]$dependency.Version) {
            throw "Package manifest does not match the pinned module name/version."
        }
        [void](New-Item -ItemType Directory -Path $moduleParent -Force)
        # Both paths are fixed under this checkout; a version already present is never replaced.
        $resolvedSource = [IO.Path]::GetFullPath($unpacked)
        $resolvedDestination = [IO.Path]::GetFullPath($destination)
        if (-not $resolvedSource.StartsWith([IO.Path]::GetFullPath($stagingRoot) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
            -not $resolvedDestination.StartsWith([IO.Path]::GetFullPath($moduleRoot) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Module installation path escaped the checkout-local directories.'
        }
        Move-Item -LiteralPath $resolvedSource -Destination $resolvedDestination
        Write-Information -InformationAction Continue -MessageData "Installed $($dependency.Name) $($dependency.Version); SHA512 verified."
    }
    finally {
        [Net.ServicePointManager]::SecurityProtocol = $previousProtocol
        $resolvedStage = [IO.Path]::GetFullPath($stage)
        $allowedStageRoot = [IO.Path]::GetFullPath($stagingRoot) + [IO.Path]::DirectorySeparatorChar
        if (-not $resolvedStage.StartsWith($allowedStageRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to remove a staging path outside the checkout-local setup folder.'
        }
        if (Test-Path -LiteralPath $resolvedStage) {
            Remove-Item -LiteralPath $resolvedStage -Recurse -Force
        }
    }
}
Write-Information -InformationAction Continue -MessageData 'Development dependencies ready. Run scripts/Invoke-Tests.ps1 -Level Quick.'
