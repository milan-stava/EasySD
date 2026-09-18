@echo off
setlocal

set "ASM=..\..\sjasmplus.exe"
if not exist "%ASM%" set "ASM=sjasmplus.exe"

if not exist "%ASM%" (
  echo ERROR: sjasmplus.exe not found.
  goto :fail
)

echo [1/3] Assembling backend at #8000...
"%ASM%" --nologo --raw=_switcher_backend.bin --lst=_switcher_backend.lst switcher_1_1_full.a80
if errorlevel 1 goto :fail

echo [2/3] Assembling UI helper at #8800...
"%ASM%" --nologo --raw=_switcher_ui.bin --lst=_switcher_ui.lst switcher_ui.a80
if errorlevel 1 goto :fail

echo [3/3] Building combined binary...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File build_switcher.ps1
if errorlevel 1 goto :fail

echo.
echo BUILD OK.
goto :eof

:fail
echo.
echo BUILD FAILED.
exit /b 1
