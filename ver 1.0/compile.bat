@echo off
setlocal
pushd "%~dp0"

echo.
echo ========================================
echo   Building EasySD for MB03+
echo ========================================
del /q EasySD_MB.bin 2>nul
sjasmplus --lst=EasySD_MB.lst --raw=EasySD_MB.bin easyhdd.a80
if errorlevel 1 goto :error_mb
if not exist EasySD_MB.bin goto :missing_mb

echo.
echo ========================================
echo   Building EasySD for eLeMeNt
echo ========================================
del /q EasySD_EL.bin 2>nul
sjasmplus --lst=EasySD_EL.lst --define ELEMENT --raw=EasySD_EL.bin easyhdd.a80
if errorlevel 1 goto :error_el
if not exist EasySD_EL.bin goto :missing_el

echo.
echo ========================================
echo   Building TAP files
echo ========================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make_taps.ps1"
if errorlevel 1 goto :error_taps


echo.
echo ========================================
echo   BUILD OK
echo ========================================
echo   EasySD_MB.bin      - MB03+
echo   EasySD_EL.bin      - eLeMeNt
echo   EasySD_MB_BIN.tap  - simple TAP: LOAD 32768 / USR 32768
echo   EasySD_EL.tap      - full eLeMeNt startup TAP
echo   EasySD_MB.lst
echo   EasySD_EL.lst
echo ========================================

popd
exit /b 0

:error_mb
echo.
echo *** MB03+ BUILD FAILED ***
goto :fail

:error_el
echo.
echo *** eLeMeNt BUILD FAILED ***
goto :fail

:error_taps
echo.
echo *** TAP BUILD FAILED ***
goto :fail

:missing_mb
echo.
echo *** MB03+ BUILD DID NOT CREATE EasySD_MB.bin ***
goto :fail

:missing_el
echo.
echo *** eLeMeNt BUILD DID NOT CREATE EasySD_EL.bin ***
goto :fail

:fail
popd
exit /b 1
