# Windows file ownership helpers. Importing this file only defines functions;
# the native declarations are compiled lazily when a transaction is allocated.
function Initialize-WacNativeFileIO {
    if ('WinAudioClean.NativeFileIO' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace WinAudioClean
{
    public static class NativeFileIO
    {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern SafeFileHandle CreateFileW(string name, uint access, uint share,
            IntPtr security, uint disposition, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetFileInformationByHandleEx(SafeFileHandle file, int kind,
            IntPtr information, uint size);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetFileInformationByHandle(SafeFileHandle file, int kind,
            IntPtr information, uint size);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern uint GetFinalPathNameByHandleW(SafeFileHandle file,
            StringBuilder path, uint size, uint flags);

        private static IOException Failure(string operation)
        {
            int code = Marshal.GetLastWin32Error();
            return new IOException(operation + ": " + new Win32Exception(code).Message + " (Win32 " + code + ").");
        }

        public static SafeFileHandle OpenDirectory(string path)
        {
            // Pin the resolved directory against rename/deletion while allowing
            // other jobs to create their own files in that same directory.
            SafeFileHandle handle = CreateFileW(path, 0x80000000, 3, IntPtr.Zero, 3, 0x02000000, IntPtr.Zero);
            if (handle.IsInvalid) { IOException error = Failure("Cannot hold output directory"); handle.Dispose(); throw error; }
            return handle;
        }

        public static string ResolvedPath(SafeFileHandle handle)
        {
            StringBuilder path = new StringBuilder(512);
            uint length = GetFinalPathNameByHandleW(handle, path, (uint)path.Capacity, 0);
            if (length == 0) throw Failure("Cannot resolve output directory");
            if (length >= path.Capacity)
            {
                path = new StringBuilder(checked((int)length + 1));
                length = GetFinalPathNameByHandleW(handle, path, (uint)path.Capacity, 0);
                if (length == 0 || length >= path.Capacity) throw Failure("Cannot resolve output directory");
            }
            string value = path.ToString();
            if (value.StartsWith(@"\\?\UNC\", StringComparison.OrdinalIgnoreCase))
                return @"\\" + value.Substring(8);
            if (value.StartsWith(@"\\?\", StringComparison.Ordinal)) return value.Substring(4);
            return value;
        }

        public static string Identity(SafeFileHandle handle)
        {
            // FILE_ID_INFO: 64-bit volume serial plus 128-bit file identifier.
            // Fail closed when the filesystem cannot provide stable identity.
            IntPtr information = Marshal.AllocHGlobal(24);
            try
            {
                if (!GetFileInformationByHandleEx(handle, 18, information, 24))
                    throw Failure("Cannot establish file identity");
                byte[] bytes = new byte[24];
                Marshal.Copy(information, bytes, 0, bytes.Length);
                return BitConverter.ToString(bytes).Replace("-", String.Empty);
            }
            finally { Marshal.FreeHGlobal(information); }
        }

        public static FileStream OpenForValidation(string path)
        {
            // READ + DELETE; share READ only. The exact bytes remain immutable
            // while this handle is validated, renamed or marked for deletion.
            SafeFileHandle handle = CreateFileW(path, 0x80010000, 1, IntPtr.Zero, 3, 0x80, IntPtr.Zero);
            if (handle.IsInvalid) { IOException error = Failure("Cannot hold owned partial"); handle.Dispose(); throw error; }
            try { return new FileStream(handle, FileAccess.Read); }
            catch { handle.Dispose(); throw; }
        }

        public static SafeFileHandle OpenReport(string path)
        {
            // Open the leaf itself, including a reparse point, before checking
            // it. Never follow a report symlink into an audio file.
            // Write-only access is compatible with PS5.1 Add-Content's writer
            // sharing mode. A data-access handle makes denied DELETE effective.
            SafeFileHandle handle = CreateFileW(path, 0x40000000, 3, IntPtr.Zero, 4, 0x00200080, IntPtr.Zero);
            if (handle.IsInvalid) { IOException error = Failure("Cannot hold report file"); handle.Dispose(); throw error; }
            IntPtr information = Marshal.AllocHGlobal(24);
            try
            {
                if (!GetFileInformationByHandleEx(handle, 9, information, 8))
                    throw Failure("Cannot inspect report attributes");
                if ((Marshal.ReadInt32(information) & 0x410) != 0)
                    throw new IOException("Report path is a reparse point or directory; it will not be written.");
                if (!GetFileInformationByHandleEx(handle, 1, information, 24))
                    throw Failure("Cannot inspect report link count");
                if (Marshal.ReadInt32(information, 16) != 1)
                    throw new IOException("Report has multiple filesystem links; it will not be written.");
                return handle;
            }
            catch { handle.Dispose(); throw; }
            finally { Marshal.FreeHGlobal(information); }
        }

        public static void RenameNoReplace(FileStream stream, SafeFileHandle directory, string leaf)
        {
            if (String.IsNullOrEmpty(leaf) || leaf != Path.GetFileName(leaf) || leaf.IndexOf(':') >= 0)
                throw new IOException("Publication requires a single ordinary filename.");
            byte[] name = Encoding.Unicode.GetBytes(Path.Combine(ResolvedPath(directory), leaf));
            int rootOffset = IntPtr.Size == 8 ? 8 : 4;
            int lengthOffset = rootOffset + IntPtr.Size;
            int nameOffset = lengthOffset + 4;
            int size = checked(nameOffset + name.Length + 2);
            IntPtr information = Marshal.AllocHGlobal(size);
            try
            {
                for (int index = 0; index < size; index++) Marshal.WriteByte(information, index, 0);
                // ReplaceIfExists remains false. Use the resolved pinned target;
                // SetFileInformationByHandle requires an absolute Win32 name.
                Marshal.WriteIntPtr(information, rootOffset, IntPtr.Zero);
                Marshal.WriteInt32(information, lengthOffset, name.Length);
                Marshal.Copy(name, 0, IntPtr.Add(information, nameOffset), name.Length);
                if (!SetFileInformationByHandle(stream.SafeFileHandle, 3, information, (uint)size))
                    throw Failure("Cannot publish output without replacing an existing file");
            }
            finally { Marshal.FreeHGlobal(information); }
        }

        public static void DeleteOwned(FileStream stream)
        {
            IntPtr information = Marshal.AllocHGlobal(1);
            try
            {
                Marshal.WriteByte(information, 1);
                if (!SetFileInformationByHandle(stream.SafeFileHandle, 4, information, 1))
                    throw Failure("Cannot remove owned partial");
            }
            finally { Marshal.FreeHGlobal(information); }
        }
    }
}
'@ -ErrorAction Stop
}

function New-WacOutputTransaction {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$OutputFolder,
        [string]$Timestamp = (Get-Date -Format 'yyyyMMdd-HHmmssfff'),
        [ValidatePattern('^[a-fA-F0-9]{32}$')][string]$JobId = ([guid]::NewGuid().ToString('N'))
    )

    if ($Timestamp -notmatch '^[0-9]{8}-([0-9]{4}|[0-9]{6}|[0-9]{9})$') { throw 'Invalid output timestamp.' }
    Initialize-WacNativeFileIO
    $transaction = [pscustomobject]@{
        JobId = $JobId.ToLowerInvariant(); InputLock = $null; InputIdentity = $null
        TempHandle = $null; TempPath = $null; FinalPath = $null; TempIdentity = $null
        ValidationHandle = $null; OutputDirectoryHandle = $null; OutputDirectoryIdentity = $null
        InputPath = [IO.Path]::GetFullPath($InputPath); OutputFolder = $null
        Published = $false; Closed = $false
    }
    try {
        $transaction.InputLock = [IO.File]::Open($transaction.InputPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        $transaction.InputIdentity = [WinAudioClean.NativeFileIO]::Identity($transaction.InputLock.SafeFileHandle)
        $transaction.InputPath = [WinAudioClean.NativeFileIO]::ResolvedPath($transaction.InputLock.SafeFileHandle)
        $transaction.OutputDirectoryHandle = [WinAudioClean.NativeFileIO]::OpenDirectory([IO.Path]::GetFullPath($OutputFolder))
        $transaction.OutputDirectoryIdentity = [WinAudioClean.NativeFileIO]::Identity($transaction.OutputDirectoryHandle)
        $transaction.OutputFolder = [WinAudioClean.NativeFileIO]::ResolvedPath($transaction.OutputDirectoryHandle)
        $transaction.TempPath = [IO.Path]::Combine($transaction.OutputFolder, ('.wac-' + $transaction.JobId + '.partial'))
        $stem = [IO.Path]::GetFileNameWithoutExtension($transaction.InputPath)
        $transaction.FinalPath = [IO.Path]::Combine($transaction.OutputFolder, ($stem + '_Cleaned_' + $Timestamp + '_' + $transaction.JobId + '.wav'))
        if ([string]::Equals($transaction.InputPath, $transaction.TempPath, [StringComparison]::OrdinalIgnoreCase) -or
            [string]::Equals($transaction.InputPath, $transaction.FinalPath, [StringComparison]::OrdinalIgnoreCase) -or
            [string]::Equals($transaction.TempPath, $transaction.FinalPath, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Input, partial and final output paths must be different.'
        }
        # CreateNew is the ownership boundary. Neither an existing regular file
        # nor a hardlink/symlink with this name may be overwritten.
        $transaction.TempHandle = [IO.File]::Open($transaction.TempPath, [IO.FileMode]::CreateNew,
            [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite)
        $transaction.TempIdentity = [WinAudioClean.NativeFileIO]::Identity($transaction.TempHandle.SafeFileHandle)
        if ($transaction.TempIdentity -eq $transaction.InputIdentity -or
            $transaction.TempIdentity.Substring(0, 16) -ne $transaction.OutputDirectoryIdentity.Substring(0, 16)) {
            throw 'Partial output identity or volume is inconsistent with its destination.'
        }
        $transaction
    } catch {
        $originalError = $_
        $cleanup = @(Close-WacOutputTransaction -Transaction $transaction)
        if ($cleanup.Count -gt 0) { Write-Warning ($cleanup -join ' ') }
        throw $originalError
    }
}

function Freeze-WacOutputTransaction {
    param([Parameter(Mandatory = $true)]$Transaction)

    if ($Transaction.Closed -or $Transaction.Published) { throw 'This output transaction cannot be frozen.' }
    if ($null -ne $Transaction.ValidationHandle) { return $Transaction.ValidationHandle }
    if ($null -ne $Transaction.TempHandle) {
        $Transaction.TempHandle.Dispose()
        $Transaction.TempHandle = $null
    }
    $handle = $null
    try {
        $handle = [WinAudioClean.NativeFileIO]::OpenForValidation($Transaction.TempPath)
        $identity = [WinAudioClean.NativeFileIO]::Identity($handle.SafeFileHandle)
        if ($identity -ne $Transaction.TempIdentity -or $identity -eq $Transaction.InputIdentity) {
            throw 'Partial output ownership changed. The replacement file will be preserved.'
        }
        $Transaction.ValidationHandle = $handle
        $handle = $null
        $Transaction.ValidationHandle
    } finally {
        if ($null -ne $handle) { $handle.Dispose() }
    }
}

function Publish-WacOutputTransaction {
    param([Parameter(Mandatory = $true)]$Transaction)

    if ($Transaction.Closed -or $Transaction.Published -or $null -eq $Transaction.ValidationHandle) {
        throw 'Output must be held for validation before publication.'
    }
    if ([WinAudioClean.NativeFileIO]::Identity($Transaction.ValidationHandle.SafeFileHandle) -ne $Transaction.TempIdentity -or
        [WinAudioClean.NativeFileIO]::Identity($Transaction.OutputDirectoryHandle) -ne $Transaction.OutputDirectoryIdentity) {
        throw 'Output ownership changed before publication.'
    }
    if (-not [string]::Equals([IO.Path]::GetDirectoryName($Transaction.TempPath), $Transaction.OutputFolder, [StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals([IO.Path]::GetDirectoryName($Transaction.FinalPath), $Transaction.OutputFolder, [StringComparison]::OrdinalIgnoreCase) -or
        [string]::Equals($Transaction.TempPath, $Transaction.FinalPath, [StringComparison]::OrdinalIgnoreCase) -or
        [string]::Equals($Transaction.InputPath, $Transaction.FinalPath, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Publication paths do not belong to this output transaction.'
    }
    [WinAudioClean.NativeFileIO]::RenameNoReplace($Transaction.ValidationHandle, $Transaction.OutputDirectoryHandle,
        [IO.Path]::GetFileName($Transaction.FinalPath))
    $Transaction.Published = $true
}

function Close-WacOutputTransaction {
    param([Parameter(Mandatory = $true)]$Transaction)

    if ($Transaction.Closed) { return }
    $diagnostics = New-Object 'System.Collections.Generic.List[string]'
    try {
        if ($null -ne $Transaction.TempHandle) {
            if (-not $Transaction.TempIdentity) {
                $diagnostics.Add("Partial retained at '$($Transaction.TempPath)': ownership identity could not be established.")
            }
            try { $Transaction.TempHandle.Dispose() }
            catch { $diagnostics.Add("Partial handle could not be closed: $($_.Exception.Message)") }
            $Transaction.TempHandle = $null
        }
        if (-not $Transaction.Published -and $Transaction.TempIdentity) {
            try {
                if ($null -eq $Transaction.ValidationHandle) {
                    $Transaction.ValidationHandle = [WinAudioClean.NativeFileIO]::OpenForValidation($Transaction.TempPath)
                }
                $identity = [WinAudioClean.NativeFileIO]::Identity($Transaction.ValidationHandle.SafeFileHandle)
                if ($identity -ne $Transaction.TempIdentity -or $identity -eq $Transaction.InputIdentity) {
                    throw 'Ownership no longer matches; the replacement file has been retained.'
                }
                [WinAudioClean.NativeFileIO]::DeleteOwned($Transaction.ValidationHandle)
            } catch {
                $diagnostics.Add("Partial cleanup incomplete at '$($Transaction.TempPath)': $($_.Exception.Message)")
            }
        }
    } finally {
        # Reporting runs before this call. Source protection is released LAST,
        # including when the shared log path is a hardlink to the input file.
        foreach ($name in @('ValidationHandle', 'OutputDirectoryHandle', 'InputLock')) {
            if ($null -ne $Transaction.$name) {
                try { $Transaction.$name.Dispose() }
                catch { $diagnostics.Add("$name could not be closed: $($_.Exception.Message)") }
                $Transaction.$name = $null
            }
        }
        $Transaction.Closed = $true
    }
    $diagnostics.ToArray()
}

function Open-WacReportGuard {
    param([Parameter(Mandatory = $true)][string]$Path)

    Initialize-WacNativeFileIO
    $handle = $null
    try {
        $handle = [WinAudioClean.NativeFileIO]::OpenReport([IO.Path]::GetFullPath($Path))
        $guard = [pscustomobject]@{
            Handle = $handle
            Path = [WinAudioClean.NativeFileIO]::ResolvedPath($handle)
        }
        $handle = $null
        $guard
    } finally {
        if ($null -ne $handle) { $handle.Dispose() }
    }
}

function Close-WacReportGuard {
    param([Parameter(Mandatory = $true)]$Guard)

    if ($null -ne $Guard.Handle) {
        $Guard.Handle.Dispose()
        $Guard.Handle = $null
    }
}
