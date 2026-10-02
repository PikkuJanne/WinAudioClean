@echo off
setlocal DisableDelayedExpansion
REM Keep paths out of PowerShell command text. The default remains one dropped file.
set "WAC_LAUNCH_SCRIPT=%~dp0WinAudioClean.ps1"
set "WAC_LAUNCH_ARGUMENT_1=%~1"
set "WAC_LAUNCH_ARGUMENT_2=%~2"
set "WAC_LAUNCH_ARGUMENT_3=%~3"
REM Delayed expansion safely captures CMD's original command line as data.
setlocal EnableDelayedExpansion
set "WAC_LAUNCH_COMMAND_LINE=!cmdcmdline!"
setlocal DisableDelayedExpansion
REM Unattended paths must be supplied in WAC_LAUNCH_INPUT / WAC_LAUNCH_OUTPUT_DIRECTORY.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; if ($env:WAC_LAUNCH_ARGUMENT_1 -eq '/unattended') { if ($env:WAC_LAUNCH_ARGUMENT_2 -notin @('Raw','Zoom') -or $env:WAC_LAUNCH_ARGUMENT_3 -or [string]::IsNullOrWhiteSpace($env:WAC_LAUNCH_INPUT) -or [string]::IsNullOrWhiteSpace($env:WAC_LAUNCH_OUTPUT_DIRECTORY)) { Write-Error 'Usage: set WAC_LAUNCH_INPUT and WAC_LAUNCH_OUTPUT_DIRECTORY from PowerShell, then run WinAudioClean.bat /unattended Raw or Zoom.' -ErrorAction Continue; exit 2 }; & $env:WAC_LAUNCH_SCRIPT -inputPath $env:WAC_LAUNCH_INPUT -OutputDirectory $env:WAC_LAUNCH_OUTPUT_DIRECTORY -Mode $env:WAC_LAUNCH_ARGUMENT_2 -NonInteractive } else { if ($env:WAC_LAUNCH_ARGUMENT_2) { Write-Error 'Drop exactly one file. For automation use the documented /unattended route or WinAudioClean.ps1.' -ErrorAction Continue; exit 2 }; if (($env:WAC_LAUNCH_ARGUMENT_1 + $env:WAC_LAUNCH_COMMAND_LINE).IndexOfAny([char[]]@(37,33)) -ge 0) { Write-Error 'CMD can change percent or exclamation characters in paths. Use WinAudioClean.ps1 -inputPath from PowerShell, or the environment-based /unattended route.' -ErrorAction Continue; exit 2 }; & $env:WAC_LAUNCH_SCRIPT -inputPath $env:WAC_LAUNCH_ARGUMENT_1 }; exit $LASTEXITCODE"
set "WAC_LAUNCH_EXIT=%ERRORLEVEL%"
if /i not "%WAC_LAUNCH_ARGUMENT_1%"=="/unattended" pause
exit /b %WAC_LAUNCH_EXIT%
