@echo off
setlocal
set "PS1_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS1_EXE%" (
    echo Windows PowerShell 5.1 was not found.
    exit /b 1
)
start "" "%PS1_EXE%" -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0CornerQuoteMapper.ps1"
endlocal
