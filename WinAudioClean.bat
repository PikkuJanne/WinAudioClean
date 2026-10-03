@echo off
setlocal EnableExtensions DisableDelayedExpansion
REM Capture one argument at a time as data. Never forward a path-bearing %%*.
set "WAC_LAUNCH_SCRIPT=%~dp0WinAudioClean.ps1"
set "WAC_LAUNCH_HELPER=%~dp0WinAudioClean.Launcher.ps1"
set "WAC_LAUNCH_BAT=%~f0"
set "WAC_LAUNCH_ARGUMENT_1=%~1"
set "WAC_LAUNCH_ARGUMENT_2=%~2"
set "WAC_LAUNCH_ARGUMENT_3=%~3"
set "WAC_LAUNCH_COUNT=0"
set "CMDCMDLINE="
set "WAC_LAUNCH_COMMAND_LINE=__WAC_CAPTURE_FAILED__"
REM Late expansion captures the original line; it never repairs CMD expansion.
setlocal EnableDelayedExpansion
set "WAC_LAUNCH_COMMAND_LINE=!cmdcmdline!"
setlocal DisableDelayedExpansion
:capture
if "%~1"=="" goto captured
set /a WAC_LAUNCH_COUNT+=1 >nul
if %WAC_LAUNCH_COUNT% GTR 1024 goto captured
set "WAC_LAUNCH_ITEM_%WAC_LAUNCH_COUNT%=%~1"
shift
goto capture
:captured
REM The optional helper owns multi-file transport, selected host and pause.
REM Without it, preserve the existing single-file/environment route.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; if (Test-Path -LiteralPath $env:WAC_LAUNCH_HELPER -PathType Leaf) { & $env:WAC_LAUNCH_HELPER; exit $LASTEXITCODE }; $wacExit=2; $wacPause=$env:WAC_LAUNCH_ARGUMENT_1 -ne '/unattended'; try { if ([string]::IsNullOrWhiteSpace($env:WAC_LAUNCH_COMMAND_LINE) -or $env:WAC_LAUNCH_COMMAND_LINE -eq '__WAC_CAPTURE_FAILED__' -or $env:WAC_LAUNCH_COMMAND_LINE.Length -ge 7600) { throw 'CMD capture failed or exceeded the safe 7600-character budget. Use WinAudioClean.ps1 -InputListPath.' }; if ($env:WAC_LAUNCH_POWERSHELL) { throw 'Keep WinAudioClean.Launcher.ps1 beside the BAT to select an inner PowerShell host.' }; if ($env:WAC_LAUNCH_IGNORE_SAVED_SETTINGS -and $env:WAC_LAUNCH_IGNORE_SAVED_SETTINGS -ne '1') { throw 'WAC_LAUNCH_IGNORE_SAVED_SETTINGS must be unset or 1.' }; $wacParameters=@{}; if ($env:WAC_LAUNCH_SETTINGS_PATH) { $wacParameters.SettingsPath=$env:WAC_LAUNCH_SETTINGS_PATH }; if ($env:WAC_LAUNCH_IGNORE_SAVED_SETTINGS -eq '1') { $wacParameters.IgnoreSavedSettings=$true }; if ($env:WAC_LAUNCH_ARGUMENT_1 -eq '/unattended') { if ($env:WAC_LAUNCH_ARGUMENT_2 -notin @('Raw','Zoom') -or $env:WAC_LAUNCH_ARGUMENT_3 -or $env:WAC_LAUNCH_INPUT_LIST_PATH -or [string]::IsNullOrWhiteSpace($env:WAC_LAUNCH_INPUT) -or [string]::IsNullOrWhiteSpace($env:WAC_LAUNCH_OUTPUT_DIRECTORY)) { throw 'Legacy automation requires WAC_LAUNCH_INPUT and WAC_LAUNCH_OUTPUT_DIRECTORY, then /unattended Raw or Zoom. Keep WinAudioClean.Launcher.ps1 beside the BAT for manifests.' }; $wacParameters.inputPath=$env:WAC_LAUNCH_INPUT; $wacParameters.OutputDirectory=$env:WAC_LAUNCH_OUTPUT_DIRECTORY; $wacParameters.Mode=$env:WAC_LAUNCH_ARGUMENT_2; $wacParameters.NonInteractive=$true } else { if ($env:WAC_LAUNCH_ARGUMENT_2 -or $env:WAC_LAUNCH_ARGUMENT_1 -eq '/manifest') { throw 'Keep WinAudioClean.Launcher.ps1 beside the BAT for several files or /manifest. Use WinAudioClean.ps1 -InputListPath for a manifest.' }; if (($env:WAC_LAUNCH_ARGUMENT_1 + $env:WAC_LAUNCH_COMMAND_LINE).IndexOfAny([char[]]@(37,33)) -ge 0) { throw 'CMD can change percent or exclamation characters before launch. Use the literal environment route or direct PowerShell.' }; $wacParameters.inputPath=$env:WAC_LAUNCH_ARGUMENT_1 }; & $env:WAC_LAUNCH_SCRIPT @wacParameters; $wacExit=$LASTEXITCODE } catch { Write-Error -Message $_.Exception.Message -ErrorAction Continue }; if ($wacPause) { & ($env:SystemRoot+'\System32\cmd.exe') /d /c pause }; exit $wacExit"
set "WAC_LAUNCH_EXIT=%ERRORLEVEL%"
exit /b %WAC_LAUNCH_EXIT%
