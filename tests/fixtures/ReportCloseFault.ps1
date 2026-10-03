function New-WacReportCloseFaultStream {
    param([Parameter(Mandatory = $true)]$RealStream, [Parameter(Mandatory = $true)][string]$Label)

    # Keep a real FileStream so identity-checked write/delete APIs still run.
    # The owned handle closes before the injected diagnostic. This certifies
    # advisory handling, not a stream that refuses to release its OS handle.
    if (-not ('WinAudioClean.ReportCloseFaultStream' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.IO;
namespace WinAudioClean {
    public sealed class ReportCloseFaultStream : FileStream {
        public readonly FileStream Real;
        public readonly string Label;
        public int DisposeCalls;
        public bool ThrowOnDispose = true;
        public ReportCloseFaultStream(FileStream real, string label)
            : base(real.SafeFileHandle, FileAccess.ReadWrite, 4096, false) {
            Real = real;
            Label = label;
        }
        protected override void Dispose(bool disposing) {
            if (disposing) DisposeCalls++;
            base.Dispose(disposing);
            if (disposing) {
                Real.Dispose();
                if (ThrowOnDispose) throw new IOException("Injected post-dispose " + Label + " report release diagnostic.");
            }
        }
    }
}
'@
    }
    New-Object WinAudioClean.ReportCloseFaultStream($RealStream, $Label)
}
