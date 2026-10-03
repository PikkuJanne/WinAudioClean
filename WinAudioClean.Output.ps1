# Optional output organization. Importing defines helpers without creating paths.
function Initialize-WacOutputLayoutIO {
    if ('WinAudioClean.OutputLayoutIO' -as [type]) { return }
    Initialize-WacNativeFileIO
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using Microsoft.Win32.SafeHandles;
namespace WinAudioClean {
    public static class OutputLayoutIO {
        [StructLayout(LayoutKind.Sequential)]
        private struct UnicodeString { public ushort Length; public ushort MaximumLength; public IntPtr Buffer; }
        [StructLayout(LayoutKind.Sequential)]
        private struct ObjectAttributes {
            public uint Length; public IntPtr RootDirectory; public IntPtr ObjectName;
            public uint Attributes; public IntPtr SecurityDescriptor; public IntPtr SecurityQualityOfService;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct IoStatusBlock { public IntPtr Status; public UIntPtr Information; }
        [DllImport("ntdll.dll")]
        private static extern int NtCreateFile(out SafeFileHandle file, uint access,
            ref ObjectAttributes attributes, out IoStatusBlock status, IntPtr allocation,
            uint fileAttributes, uint share, uint disposition, uint options, IntPtr ea, uint eaLength);
        [DllImport("ntdll.dll")]
        private static extern uint RtlNtStatusToDosError(int status);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern SafeFileHandle CreateFileW(string path, uint access, uint share,
            IntPtr security, uint disposition, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetFileInformationByHandleEx(SafeFileHandle file, int kind,
            IntPtr information, uint size);

        public static void ValidateDirectory(SafeFileHandle handle) {
            if (handle == null || handle.IsClosed || handle.IsInvalid)
                throw new IOException("Output layout directory handle is unavailable.");
            IntPtr information = Marshal.AllocHGlobal(8);
            try {
                if (!GetFileInformationByHandleEx(handle, 9, information, 8))
                    throw new IOException("Cannot inspect output layout directory: " +
                        new Win32Exception(Marshal.GetLastWin32Error()).Message);
                uint attributes = unchecked((uint)Marshal.ReadInt32(information));
                if ((attributes & 0x10) == 0 || (attributes & 0x400) != 0)
                    throw new IOException("Output layout requires an ordinary directory without reparse redirection.");
            } finally { Marshal.FreeHGlobal(information); }
        }

        public static SafeFileHandle OpenDirectory(string path) {
            SafeFileHandle handle = CreateFileW(path, 0x80000000, 1, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero);
            if (handle.IsInvalid) {
                int code = Marshal.GetLastWin32Error(); handle.Dispose();
                throw new IOException("Cannot hold output layout ancestor: " + new Win32Exception(code).Message);
            }
            try { ValidateDirectory(handle); return handle; }
            catch { handle.Dispose(); throw; }
        }

        public static SafeFileHandle CreateDirectory(SafeFileHandle parent, string leaf) {
            if (leaf != "media" && leaf != "reports" &&
                !Regex.IsMatch(leaf ?? String.Empty, @"\AWinAudioClean_Job_[a-f0-9]{32}\z"))
                throw new IOException("Output layout creation requires a generated single directory name.");
            ValidateDirectory(parent);
            bool added = false;
            IntPtr buffer = IntPtr.Zero, name = IntPtr.Zero;
            SafeFileHandle handle = null;
            try {
                parent.DangerousAddRef(ref added);
                buffer = Marshal.StringToHGlobalUni(leaf);
                var unicode = new UnicodeString {
                    Length = checked((ushort)(leaf.Length * 2)),
                    MaximumLength = checked((ushort)((leaf.Length + 1) * 2)), Buffer = buffer
                };
                name = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(UnicodeString)));
                Marshal.StructureToPtr(unicode, name, false);
                var attributes = new ObjectAttributes {
                    Length = (uint)Marshal.SizeOf(typeof(ObjectAttributes)),
                    RootDirectory = parent.DangerousGetHandle(), ObjectName = name, Attributes = 0x40
                };
                IoStatusBlock status;
                // FILE_CREATE gives a held new directory in one operation.
                // The existing held publication operation needs WRITE sharing
                // on its media parent. Other pins share READ only; none DELETE.
                uint share = leaf == "media" ? 3u : 1u;
                int result = NtCreateFile(out handle, 0x00100081, ref attributes, out status,
                    IntPtr.Zero, 0x80, share, 2, 0x00200021, IntPtr.Zero, 0);
                if (result < 0)
                    throw new IOException("Cannot exclusively create output layout directory: " +
                        new Win32Exception(unchecked((int)RtlNtStatusToDosError(result))).Message);
                if (status.Information.ToUInt64() != 2)
                    throw new IOException("Output layout creation did not establish a new directory.");
                ValidateDirectory(handle);
                SafeFileHandle owned = handle; handle = null; return owned;
            } finally {
                if (handle != null) handle.Dispose();
                if (name != IntPtr.Zero) Marshal.FreeHGlobal(name);
                if (buffer != IntPtr.Zero) Marshal.FreeHGlobal(buffer);
                if (added) parent.DangerousRelease();
            }
        }
    }
}
'@ -ErrorAction Stop
}

function New-WacOutputLayout {
    param([Parameter(Mandatory = $true)][string]$BaseDirectory,
        [ValidatePattern('^[a-fA-F0-9]{32}$')][string]$JobId = ([guid]::NewGuid().ToString('N')))
    Initialize-WacOutputLayoutIO
    $layout = [pscustomobject]@{
        BaseDirectory = $null; RootDirectory = $null; MediaDirectory = $null; ReportDirectory = $null
        JobId = $JobId.ToLowerInvariant(); Handles = [ordered]@{}; Identities = [ordered]@{}
        HandlePaths = [ordered]@{}; Closed = $false
    }
    try {
        $requested = Resolve-WacFileSystemPath -Path $BaseDirectory
        # Preserve supported existing base junctions by canonicalizing through IO.
        # This helper never creates a missing base or falls back to the cwd.
        $layout.Handles.RequestedBase = [WinAudioClean.NativeFileIO]::OpenDirectory($requested)
        $canonical = Resolve-WacFileSystemPath -Path ([WinAudioClean.NativeFileIO]::ResolvedPath($layout.Handles.RequestedBase))
        $layout.BaseDirectory = $canonical
        $root = [IO.Path]::GetPathRoot($canonical)
        $chain = New-Object 'System.Collections.Generic.List[string]'
        $chain.Add($root)
        $current = $root
        foreach ($part in $canonical.Substring($root.Length).TrimEnd([char[]]'\/').Split([char[]]'\/', [StringSplitOptions]::RemoveEmptyEntries)) {
            $current = [IO.Path]::Combine($current, $part); $chain.Add($current)
        }
        foreach ($path in $chain) {
            $key = 'Ancestor' + $layout.Handles.Count
            $layout.Handles[$key] = [WinAudioClean.OutputLayoutIO]::OpenDirectory($path)
            if ([WinAudioClean.NativeFileIO]::ResolvedPath($layout.Handles[$key]).TrimEnd([char[]]'\/') -ine $path.TrimEnd([char[]]'\/')) {
                throw 'Output layout ancestor changed or was redirected.'
            }
        }
        if ([WinAudioClean.NativeFileIO]::Identity($layout.Handles.RequestedBase) -ne
            [WinAudioClean.NativeFileIO]::Identity($layout.Handles[$key])) { throw 'Output layout base identity changed during acquisition.' }
        $layout.Handles.Root = [WinAudioClean.OutputLayoutIO]::CreateDirectory($layout.Handles[$key], ('WinAudioClean_Job_' + $layout.JobId))
        $layout.Handles.Media = [WinAudioClean.OutputLayoutIO]::CreateDirectory($layout.Handles.Root, 'media')
        $layout.Handles.Reports = [WinAudioClean.OutputLayoutIO]::CreateDirectory($layout.Handles.Root, 'reports')
        $layout.RootDirectory = [WinAudioClean.NativeFileIO]::ResolvedPath($layout.Handles.Root)
        $layout.MediaDirectory = [WinAudioClean.NativeFileIO]::ResolvedPath($layout.Handles.Media)
        $layout.ReportDirectory = [WinAudioClean.NativeFileIO]::ResolvedPath($layout.Handles.Reports)
        foreach ($name in $layout.Handles.Keys) {
            $layout.Identities[$name] = [WinAudioClean.NativeFileIO]::Identity($layout.Handles[$name])
            $layout.HandlePaths[$name] = [WinAudioClean.NativeFileIO]::ResolvedPath($layout.Handles[$name])
        }
        Assert-WacOutputLayout -Layout $layout
        $layout
    } catch {
        $failure = $_
        foreach ($message in @(Close-WacOutputLayout -Layout $layout)) { Write-Warning $message }
        throw $failure
    }
}

function Assert-WacOutputLayout {
    param([Parameter(Mandatory = $true)]$Layout)
    if ($Layout.Closed -or $Layout.JobId -cnotmatch '^[a-f0-9]{32}$' -or
        $null -eq $Layout.Handles -or $Layout.Handles.Count -lt 5) { throw 'Output layout is closed or invalid.' }
    foreach ($name in $Layout.Handles.Keys) {
        $handle = $Layout.Handles[$name]
        [WinAudioClean.OutputLayoutIO]::ValidateDirectory($handle)
        if ([WinAudioClean.NativeFileIO]::Identity($handle) -ne $Layout.Identities[$name] -or
            [WinAudioClean.NativeFileIO]::ResolvedPath($handle) -ine $Layout.HandlePaths[$name]) {
            throw 'Output layout directory ownership changed.'
        }
    }
    $expectedRoot = [IO.Path]::Combine($Layout.BaseDirectory, ('WinAudioClean_Job_' + $Layout.JobId))
    if ($Layout.RootDirectory -ine $expectedRoot -or $Layout.MediaDirectory -ine [IO.Path]::Combine($expectedRoot, 'media') -or
        $Layout.ReportDirectory -ine [IO.Path]::Combine($expectedRoot, 'reports') -or
        $Layout.HandlePaths.RequestedBase -ine $Layout.BaseDirectory -or $Layout.HandlePaths.Root -ine $Layout.RootDirectory -or
        $Layout.HandlePaths.Media -ine $Layout.MediaDirectory -or $Layout.HandlePaths.Reports -ine $Layout.ReportDirectory) {
        throw 'Output layout paths do not belong to the held directory hierarchy.'
    }
}

function Close-WacOutputLayout {
    param([Parameter(Mandatory = $true)]$Layout)
    if ($Layout.Closed) { return }
    $diagnostics = New-Object 'System.Collections.Generic.List[string]'
    $names = @($Layout.Handles.Keys)
    [array]::Reverse($names)
    foreach ($name in $names) {
        try { if ($null -ne $Layout.Handles[$name]) { $Layout.Handles[$name].Dispose() } }
        catch { $diagnostics.Add('Output layout handle could not be closed: ' + $_.Exception.Message) }
        $Layout.Handles[$name] = $null
    }
    $Layout.Closed = $true
    $diagnostics.ToArray()
}
