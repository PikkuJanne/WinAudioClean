# Test-only private native console. Product bytes and interactive host remain intact.
param([Parameter(Mandatory = $true)][string]$CasePath)
$ErrorActionPreference = 'Stop'
$case = [IO.File]::ReadAllText($CasePath) | ConvertFrom-Json
$result = [ordered]@{ exitCode = $null; width = $null; menu = ''; completed = ''; inputInjected = $false; error = $null }
try {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class WacSignalConsole {
    [StructLayout(LayoutKind.Sequential)] public struct Coord { public short X, Y; public Coord(short x, short y) { X=x; Y=y; } }
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public short Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct Info { public Coord Size, Cursor; public short Attributes; public Rect Window; public Coord Maximum; }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct Key { public int Down; public short Repeat, Virtual, Scan; public char Character; public int Control; }
    [StructLayout(LayoutKind.Explicit, CharSet=CharSet.Unicode)] public struct Input { [FieldOffset(0)] public short Type; [FieldOffset(4)] public Key Key; }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr security, uint mode, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetConsoleScreenBufferInfo(SafeFileHandle handle, out Info info);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetConsoleScreenBufferSize(SafeFileHandle handle, Coord size);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetConsoleWindowInfo(SafeFileHandle handle, bool absolute, ref Rect window);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool ReadConsoleOutputCharacterW(SafeFileHandle handle, StringBuilder text, uint length, Coord start, out uint read);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool WriteConsoleInputW(SafeFileHandle handle, Input[] values, uint count, out uint written);
    static Thread worker; static volatile bool stop;
    public static string Menu = "", InputError = null;
    public static bool Injected;
    static SafeFileHandle Open(string name) { var handle=CreateFile(name,0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero); if(handle.IsInvalid) throw new System.ComponentModel.Win32Exception(); return handle; }
    public static int Resize(short width) {
        using(var output=Open("CONOUT$")) {
            Rect window=new Rect { Right=(short)(width-1), Bottom=19 };
            if(!SetConsoleWindowInfo(output,true,ref window) || !SetConsoleScreenBufferSize(output,new Coord(width,3000))) throw new System.ComponentModel.Win32Exception();
            Info info; if(!GetConsoleScreenBufferInfo(output,out info)) throw new System.ComponentModel.Win32Exception(); return info.Size.X;
        }
    }
    public static string Capture() {
        using(var output=Open("CONOUT$")) {
            Info info; if(!GetConsoleScreenBufferInfo(output,out info)) throw new System.ComponentModel.Win32Exception();
            int length=info.Size.X*(info.Cursor.Y+1); var text=new StringBuilder(length); uint read;
            if(!ReadConsoleOutputCharacterW(output,text,(uint)length,new Coord(0,0),out read)) throw new System.ComponentModel.Win32Exception();
            var rows=new StringBuilder(); string raw=text.ToString();
            for(int offset=0;offset<raw.Length;offset+=info.Size.X) rows.AppendLine(raw.Substring(offset,Math.Min(info.Size.X,raw.Length-offset)).TrimEnd());
            return rows.ToString();
        }
    }
    public static void StartInput() {
        stop=false;
        worker=new Thread(delegate() {
            try {
                var deadline=DateTime.UtcNow.AddSeconds(20);
                while(!stop && DateTime.UtcNow<deadline) {
                    string captured=Capture();
                    if(captured.Contains("Enter selection")) {
                        Menu=captured;
                        using(var input=Open("CONIN$")) {
                            var records=new Input[4];
                            for(int i=0;i<records.Length;i++) {
                                records[i].Type=1; records[i].Key.Down=i%2==0?1:0; records[i].Key.Repeat=1;
                                records[i].Key.Character=i<2?'2':'\r'; records[i].Key.Virtual=(short)(i<2?0x32:13);
                            }
                            uint written; if(!WriteConsoleInputW(input,records,4,out written) || written!=4) throw new System.ComponentModel.Win32Exception();
                            Injected=true; return;
                        }
                    }
                    Thread.Sleep(20);
                }
                if(!stop) InputError="Mode prompt was not observed within 20 seconds.";
            } catch(Exception error) { InputError=error.Message; }
        });
        worker.IsBackground=true; worker.Start();
    }
    public static void StopInput() { stop=true; if(worker!=null && !worker.Join(2000)) throw new TimeoutException("Console input observer did not stop."); }
}
'@
    $result.width = [WacSignalConsole]::Resize([int16]$case.width)
    $env:WAC_TEST_FFMPEG_OUTPUT = '1'
    $env:WAC_TEST_EXIT_CODE = '0'
    $env:WAC_TEST_STDOUT = "out_time_us=1500000`nprogress=continue`nout_time_us=3000000`nprogress=end`n"
    $env:WAC_TEST_STDERR = 'Synthetic console fixture diagnostic'
    $env:WAC_TEST_BLOCK_LOG = if ($case.status -eq 'WARNING') { '1' } else { '0' }
    $parameters = @{ inputPath = $case.input; OutputDirectory = $case.output; IgnoreSavedSettings = $true }
    if ($case.status -eq 'DEPENDENCY') {
        $parameters.Mode = 'Zoom'; $parameters.FfmpegPath = [IO.Path]::Combine($case.root, 'missing.exe')
    } else {
        if ($case.status -eq 'PAN_DEPENDENCY') {
            $parameters.Mono = $true
            $env:WAC_TEST_PROBE_STDOUT = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"pcm_s16le","channels":2,"channel_layout":"stereo","sample_rate":"48000","duration":"3.000000"}]}'
        }
        [WacSignalConsole]::StartInput()
    }
    & ([IO.Path]::Combine($case.root, 'WinAudioClean.ps1')) @parameters
    $result.exitCode = $LASTEXITCODE
    [WacSignalConsole]::StopInput()
    if ([WacSignalConsole]::InputError) { throw [WacSignalConsole]::InputError }
    $result.menu = [WacSignalConsole]::Menu
    $result.completed = [WacSignalConsole]::Capture()
    $result.inputInjected = [WacSignalConsole]::Injected
} catch { $result.error = $_.Exception.Message }
finally {
    [IO.File]::WriteAllText($case.result, (($result | ConvertTo-Json -Depth 6) + "`r`n"), [Text.UTF8Encoding]::new($false))
}
if ($result.error) { exit 1 }
exit 0
