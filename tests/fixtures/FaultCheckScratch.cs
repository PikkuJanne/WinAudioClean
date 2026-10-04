// Development-only scratch ownership. Cleanup never follows reparse points and
// deletes through held identities, not paths supplied by a caller.
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace WinAudioClean.Tests
{
    public sealed class FaultCheckScratch : IDisposable
    {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern SafeFileHandle CreateFileW(string name, uint access, uint share,
            IntPtr security, uint disposition, uint flags, IntPtr template);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CreateDirectoryW(string name, IntPtr security);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetFileInformationByHandleEx(SafeFileHandle file, int kind,
            IntPtr information, uint size);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetFileInformationByHandle(SafeFileHandle file, int kind,
            IntPtr information, uint size);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern uint GetFinalPathNameByHandleW(SafeFileHandle file,
            StringBuilder path, uint size, uint flags);

        private readonly List<SafeFileHandle> ancestors = new List<SafeFileHandle>();
        private SafeFileHandle rootHandle;
        private string identity;
        private bool cleaned;
        public string Root { get; private set; }
        public string LocalRoot { get; private set; }

        private FaultCheckScratch() { }

        private static IOException Failure(string message)
        {
            return new IOException(message + ": " + new Win32Exception(Marshal.GetLastWin32Error()).Message);
        }

        private static string ResolvedPath(SafeFileHandle handle)
        {
            StringBuilder buffer = new StringBuilder(32768);
            uint length = GetFinalPathNameByHandleW(handle, buffer, (uint)buffer.Capacity, 0);
            if (length == 0 || length >= buffer.Capacity) throw Failure("Cannot resolve scratch identity");
            string result = buffer.ToString();
            if (result.StartsWith(@"\\?\UNC\", StringComparison.OrdinalIgnoreCase)) return @"\\" + result.Substring(8);
            if (result.StartsWith(@"\\?\", StringComparison.Ordinal)) return result.Substring(4);
            return result;
        }

        private static string Identity(SafeFileHandle handle)
        {
            IntPtr information = Marshal.AllocHGlobal(24);
            try
            {
                if (!GetFileInformationByHandleEx(handle, 18, information, 24)) throw Failure("Cannot inspect scratch identity");
                byte[] bytes = new byte[24];
                Marshal.Copy(information, bytes, 0, bytes.Length);
                return BitConverter.ToString(bytes);
            }
            finally { Marshal.FreeHGlobal(information); }
        }

        private static SafeFileHandle OpenOrdinary(string path, bool directory, bool deleteAccess)
        {
            // OPEN_REPARSE_POINT opens the leaf itself. Denying shared DELETE
            // pins it and every ordinary ancestor throughout enumeration/removal.
            SafeFileHandle handle = CreateFileW(path, deleteAccess ? 0x80010000u : 0x80000000u,
                3, IntPtr.Zero, 3, 0x00200000u | (directory ? 0x02000000u : 0u), IntPtr.Zero);
            if (handle.IsInvalid) { handle.Dispose(); throw Failure("Cannot hold scratch item"); }
            IntPtr information = Marshal.AllocHGlobal(8);
            try
            {
                if (!GetFileInformationByHandleEx(handle, 9, information, 8)) throw Failure("Cannot inspect scratch attributes");
                int attributes = Marshal.ReadInt32(information);
                if ((attributes & 0x400) != 0) throw new IOException("Scratch cleanup refuses a reparse point.");
                if (((attributes & 0x10) != 0) != directory) throw new IOException("Scratch item kind changed.");
                string actual = ResolvedPath(handle).TrimEnd(Path.DirectorySeparatorChar);
                if (!String.Equals(actual, Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar), StringComparison.OrdinalIgnoreCase))
                    throw new IOException("Scratch path resolved outside its held ordinary ancestry.");
                return handle;
            }
            catch { handle.Dispose(); throw; }
            finally { Marshal.FreeHGlobal(information); }
        }

        public static FaultCheckScratch Create(string repositoryRoot)
        {
            string repository = Path.GetFullPath(repositoryRoot).TrimEnd(Path.DirectorySeparatorChar);
            if (!Directory.Exists(repository)) throw new IOException("Scratch repository must already exist.");
            FaultCheckScratch owner = new FaultCheckScratch();
            try
            {
                List<string> paths = new List<string>();
                for (string path = repository; !String.IsNullOrEmpty(path); path = Path.GetDirectoryName(path)) paths.Add(path);
                paths.Reverse();
                foreach (string path in paths) owner.ancestors.Add(OpenOrdinary(path, true, false));
                owner.LocalRoot = Path.Combine(repository, ".wac-local");
                if (!Directory.Exists(owner.LocalRoot) && !CreateDirectoryW(owner.LocalRoot, IntPtr.Zero))
                    throw Failure("Cannot create scratch parent");
                owner.ancestors.Add(OpenOrdinary(owner.LocalRoot, true, false));
                owner.Root = Path.Combine(owner.LocalRoot, "faultchecks-" + Guid.NewGuid().ToString("N"));
                if (!CreateDirectoryW(owner.Root, IntPtr.Zero)) throw Failure("Cannot allocate new scratch tree");
                owner.rootHandle = OpenOrdinary(owner.Root, true, true);
                owner.identity = Identity(owner.rootHandle);
                return owner;
            }
            catch { owner.ReleaseHandles(); throw; }
        }

        private sealed class Item
        {
            internal string Path;
            internal SafeFileHandle Handle;
            internal string Identity;
            internal bool Directory;
        }

        private void Collect(string directory, List<Item> items)
        {
            foreach (string path in Directory.GetFileSystemEntries(directory))
            {
                string full = Path.GetFullPath(path);
                if (!full.StartsWith(Root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                    throw new IOException("Scratch enumeration escaped its owned tree.");
                bool isDirectory = (File.GetAttributes(full) & FileAttributes.Directory) != 0;
                SafeFileHandle handle = OpenOrdinary(full, isDirectory, true);
                Item item = new Item { Path = full, Handle = handle, Identity = Identity(handle), Directory = isDirectory };
                items.Add(item);
                if (isDirectory) Collect(full, items);
            }
        }

        private static void DeleteHeld(SafeFileHandle handle, string expectedIdentity)
        {
            if (Identity(handle) != expectedIdentity) throw new IOException("Scratch identity changed before removal.");
            IntPtr information = Marshal.AllocHGlobal(1);
            try
            {
                Marshal.WriteByte(information, 1);
                if (!SetFileInformationByHandle(handle, 4, information, 1)) throw Failure("Cannot remove held scratch item");
            }
            finally { Marshal.FreeHGlobal(information); }
        }

        public void RemoveTree()
        {
            if (cleaned) return;
            if (rootHandle == null || rootHandle.IsClosed) throw new IOException("Scratch owner has been released.");
            if (Identity(rootHandle) != identity || !String.Equals(ResolvedPath(rootHandle), Root, StringComparison.OrdinalIgnoreCase))
                throw new IOException("Scratch root identity changed.");
            List<Item> items = new List<Item>();
            try
            {
                // Validate and hold the whole tree before the first deletion.
                // A foreign junction therefore leaves every sibling intact.
                Collect(Root, items);
                for (int index = items.Count - 1; index >= 0; index--)
                {
                    DeleteHeld(items[index].Handle, items[index].Identity);
                    items[index].Handle.Dispose();
                }
                DeleteHeld(rootHandle, identity);
                rootHandle.Dispose();
                cleaned = true;
            }
            finally { foreach (Item item in items) item.Handle.Dispose(); }
        }

        private void ReleaseHandles()
        {
            if (rootHandle != null) rootHandle.Dispose();
            for (int index = ancestors.Count - 1; index >= 0; index--) ancestors[index].Dispose();
            ancestors.Clear();
        }

        // Disposal releases pins only. An explicit RemoveTree failure retains
        // the tree for inspection and must never trigger a fallback path delete.
        public void Dispose() { ReleaseHandles(); }
    }
}
