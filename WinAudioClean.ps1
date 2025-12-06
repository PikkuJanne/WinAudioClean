<#
WinAudioClean.ps1
Automated Audio Cleaning & Leveling Droplet

Author: Janne Vuorela
Target OS: Windows 10/11
PowerShell: Windows PowerShell 5.1 (built-in) or PowerShell 7+
Dependencies: FFmpeg.exe (must be in the same folder), .bat wrapper for drag-and-drop

SYNOPSIS
    A "drop-and-forget" audio post-production tool.
    Takes a raw audio file, cleans it using physics-based signal processing (De-clip/De-click/Denoise),
    and levels it to broadcast standards (-12dB RMS) using a loudness chain.

WHAT THIS IS (AND ISN'T)
    - A codified version of a specific Adobe Audition "Speech Volume Leveler" workflow.
    - Designed to be a robust "black box" that just works for 95% of spoken word audio.
    - Favors consistency over granular control.
    - Not an AI-based voice isolator.
    - Not a multi-track editor, it processes single mixed files.

FEATURES
    - Text User Interface (TUI):
        Simple prompt asking if the source is a "Raw Recording" or "Zoom/Teams" meeting.
        Prevents over-processing of audio that is already noise-cancelled by VoIP software.
    - Robust Cleaning Chain (Mode 1):
        1. De-Clipper: Reconstructs peaks damaged by digital distortion.
        2. Highpass Filter (80Hz): Removes AC hum, traffic rumble, and desk thumps.
        3. De-Clicker: Smooths out mouth noises and lip smacks.
        4. FFT Denoiser: Profiling-free noise reduction for steady background hiss.
        5. Noise Gate: Silences breath and room tone between speech (Linear scale).
    - Broadcast Leveling (Mode 1 & 2):
        Uses Dynamic Audio Normalizer (dynaudnorm) to chase peaks and boost quiet sections (85% leveling).
        Finishes with a Loudness Limiter (loudnorm) targeting exactly -12 LUFS/dB.
    - Report Logging:
        Generates a verbose log file in the Music folder.
        Tracks input/output file sizes, duration, and the exact FFmpeg filter chain used for every run.
    - Non-Destructive:
        Never overwrites the original. Saves a new file with a timestamp and "_Cleaned" suffix.

MY INTENDED USAGE
    - I keep WinAudioClean shortcut on my Desktop.
    - When I finish a voice recording or download a Zoom meeting:
        1. I drag the audio file onto the shortcut (.bat) file.
        2. I type "1" for raw mic audio or "2" for a meeting.
        3. I wait for the green "SUCCESS" text.
        4. I find the polished file in my Music folder, ready for upload.

SETUP
    1) Create a folder (e.g., C:\Tools\WinAudioClean\).
    2) Place these three files inside:
        - WinAudioClean.ps1
        - WinAudioClean.bat
        - ffmpeg.exe (Download from gyan.dev or similar)
    3) (Optional) Create a shortcut to the .bat file on your Desktop.

USAGE
    A) Drag-and-Drop (Recommended)
        - Drag an audio file (WAV, MP3, M4A, MKV, etc.) onto WinAudioClean.bat.
        - Follow the on-screen prompts.

    B) Direct PowerShell
        - Open PowerShell.
        - Run: .\WinAudioClean.ps1 -inputPath "C:\Path\To\Audio.wav"

NOTES
    - The Noise Gate settings use linear math, not decibels. This conversion is handled internally.
    - The script forces the output format to .wav for maximum compatibility and quality preservation.
    - Processing speed depends on CPU power and file length.

LIMITATIONS
    - Requires FFmpeg to be present, cannot run without it.
    - The "Highpass" filter is set to 80Hz. Deep baritone voices might prefer 60Hz, but 80Hz is the safe standard.
    - Extremely noisy audio requires AI tools, which are outside the scope of this script.

TROUBLESHOOTING
    - "FFmpeg.exe not found!":
        The script cannot see ffmpeg.exe. Ensure it is in the exact same folder as the .ps1 script.
    - Red "FAILED" text:
        Check the console output immediately above the failure message. FFmpeg usually prints the specific reason (e.g., corrupt input file).

LICENSE / WARRANTY
    - Personal automation tool, provided as-is.
    - Logic based on standard audio engineering practices.
#>

param([string]$inputPath)

# --- CONFIGURATION ---
$scriptVersion = "2.3"
$ffmpegPath = "$PSScriptRoot\ffmpeg.exe"
$outFolder = [Environment]::GetFolderPath("MyMusic")
$logFile = "$outFolder\WinAudioClean_Log.txt"

# --- TUI: HEADER ---
Clear-Host
Write-Host "WinAudioClean $scriptVersion" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Gray
Write-Host "Input: " -NoNewline; Write-Host $inputPath -ForegroundColor Yellow

# --- TUI: SELECTION ---
Write-Host "`nSelect Processing Mode:" -ForegroundColor White
Write-Host "[1] RAW RECORDING (Clean + Level)" -ForegroundColor Green
Write-Host "    -> Use for mic recordings. Removes hiss, rumble, clicks, and levels volume."
Write-Host "[2] ZOOM/TEAMS (Level Only)" -ForegroundColor Magenta
Write-Host "    -> Use for meeting audio. Preserves existing noise cancellation."

$choice = Read-Host "`nEnter selection (1 or 2)"

# --- FILTER CHAINS ---
# Robust Cleaning: De-clip -> Highpass(80Hz) -> De-click -> FFT Denoise -> Gate(Linear Scale)
$cleanFilters = "adeclip,highpass=f=80,adeclick,afftdn=nf=-25,agate=range=0.056:threshold=0.0056"

# Leveling: Dynamic Normalizer -> Loudness Limiter (-12dB RMS)
$levelFilters = "dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5"

# --- LOGIC ---
if ($choice -eq '1') {
    $modeName = "RAW (Clean+Level)"
    $filterChain = "$cleanFilters,$levelFilters"
} else {
    $modeName = "ZOOM (Level Only)"
    $filterChain = "$levelFilters"
}

# --- PRE-FLIGHT CHECKS ---
if (-not (Test-Path $inputPath)) { Write-Error "No file dropped!"; exit }
if (-not (Test-Path $ffmpegPath)) { 
    if (Get-Command "ffmpeg" -ErrorAction SilentlyContinue) { $ffmpegPath = "ffmpeg" } 
    else { Write-Error "FFmpeg.exe not found! Put it next to this script."; exit }
}

$inputFileItem = Get-Item $inputPath
$inputSizeMB = "{0:N2} MB" -f ($inputFileItem.Length / 1MB)

$fileName = [System.IO.Path]::GetFileNameWithoutExtension($inputPath)
$timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$outputFile = "$outFolder\$fileName`_Cleaned_$timestamp.wav"

# --- EXECUTION ---
Write-Host "`nRunning WinAudioClean..." -ForegroundColor Cyan
Write-Host "Chain: $modeName" -ForegroundColor Gray

$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

# FFmpeg Command
$argumentList = "-i `"$inputPath`" -vn -af `"$filterChain`" `"$outputFile`" -y -hide_banner -loglevel error -stats"
$process = Start-Process -FilePath $ffmpegPath -ArgumentList $argumentList -Wait -NoNewWindow -PassThru

$stopWatch.Stop()

# --- LOGGING ---
$status = if ($process.ExitCode -eq 0) { "SUCCESS" } else { "FAILED" }
$duration = $stopWatch.Elapsed.ToString("mm\:ss\.ff")
$logDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Get Output Size if file exists
if (Test-Path $outputFile) {
    $outputFileItem = Get-Item $outputFile
    $outputSizeMB = "{0:N2} MB" -f ($outputFileItem.Length / 1MB)
} else {
    $outputSizeMB = "N/A"
}

# Construct Verbose Log Entry
$logEntry = @"
================================================================================
LOG DATE       : $logDate
--------------------------------------------------------------------------------
STATUS         : $status (Exit Code: $($process.ExitCode))
MODE           : $modeName
DURATION       : $duration

INPUT FILE     : $inputPath
INPUT SIZE     : $inputSizeMB
OUTPUT FILE    : $outputFile
OUTPUT SIZE    : $outputSizeMB

ACTIVE FILTERS : $filterChain
================================================================================
"@

# Write to Log
Add-Content -Path $logFile -Value $logEntry

# --- FEEDBACK ---
if ($status -eq "SUCCESS") {
    Write-Host "`nDONE: SUCCESS" -ForegroundColor Green
    Write-Host "Time Elapsed : $duration"
    Write-Host "Output Size  : $outputSizeMB"
    Write-Host "File saved to: $outputFile"
} else {
    Write-Host "`nDONE: FAILED" -ForegroundColor Red
    Write-Host "Check the console for FFmpeg errors."
}
