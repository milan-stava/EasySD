@echo off
setlocal
pushd "%~dp0"

set "SJASM=%~dp0..\sjasmplus.exe"
if not exist "%SJASM%" set "SJASM=%~dp0sjasmplus.exe"
if not exist "%SJASM%" set "SJASM=sjasmplus"

echo.
echo ========================================
echo   Switcher 1.0 - CF / SD1 / SD2
echo ========================================

del /q SWITCH_ALL.bin SWITCH_ALL.lst SWITCH_MENU.tap 2>nul

"%SJASM%" --lst=SWITCH_ALL.lst --raw=SWITCH_ALL.bin switch_device_unified.a80
if errorlevel 1 goto :error_asm
if not exist SWITCH_ALL.bin goto :missing_bin
for %%F in (SWITCH_ALL.bin) do if not "%%~zF"=="557" goto :bad_bin_size

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make_switch_menu.ps1"
if errorlevel 1 goto :error_tap
if not exist SWITCH_MENU.tap goto :missing_tap
for %%F in (SWITCH_MENU.tap) do if not "%%~zF"=="1797" goto :bad_tap_size

echo.
echo ========================================
echo   SWITCHER 1.0 BUILD OK
echo ========================================
echo   SWITCH_ALL.bin   557 bytes
echo   SWITCH_ALL.lst
echo   SWITCH_MENU.tap  1797 bytes
echo ========================================
popd
exit /b 0

:error_asm
echo *** SWITCHER ASSEMBLY FAILED ***
goto :fail
:error_tap
echo *** SWITCHER TAP BUILD FAILED ***
goto :fail
:missing_bin
echo *** SWITCH_ALL.bin WAS NOT CREATED ***
goto :fail
:missing_tap
echo *** SWITCH_MENU.tap WAS NOT CREATED ***
goto :fail
:bad_bin_size
echo *** WRONG SWITCH_ALL.bin SIZE - EXPECTED 557 BYTES ***
goto :fail
:bad_tap_size
echo *** WRONG SWITCH_MENU.tap SIZE - EXPECTED 1797 BYTES ***
goto :fail
:fail
popd
exit /b 1
