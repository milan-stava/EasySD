@echo off
setlocal
pushd "%~dp0"

set "SJASM=%~dp0sjasmplus.exe"
if not exist "%SJASM%" set "SJASM=sjasmplus"

rem ============================================================
rem EasySD 1.1 release build - Windows
rem No Python required. Uses sjasmplus + Windows PowerShell only.
rem ============================================================

echo.
echo ========================================
echo   EasySD 1.1 - clean release build
echo ========================================

rem Remove current and obsolete build artefacts so old binaries cannot be mistaken for fresh output.
del /q EasySD_1_1_INSTALL.bin EasySD_1_1_INSTALL.lst EasySD_1_1_INSTALL.tap 2>nul
del /q EasySD_1_1_EL.bin EasySD_1_1_EL.lst EasySD_1_1_EL.tap 2>nul
del /q EasySD_1_1_SLIM.bin EasySD_1_1_SLIM.lst EasySD_1_1_SLIM.tap 2>nul
del /q EasySD_MB.bin EasySD_MB.lst EasySD_MB_BIN.tap 2>nul
del /q EasySD_EL.bin EasySD_EL.lst EasySD_EL.tap 2>nul
del /q EasySD_SLIM.bin EasySD_SLIM.lst EasySD_SLIM.tap 2>nul

rem ------------------------------------------------------------
rem MB03+
rem ------------------------------------------------------------
echo.
echo [1/4] Building MB03+ installer...
"%SJASM%" --define DUAL_GUI_TEST --define DUAL_GUI_INSTALL_TEST --lst=EasySD_1_1_INSTALL.lst --raw=EasySD_1_1_INSTALL.bin easyhdd_1_1_release_SD12.a80
if errorlevel 1 goto :error_mb
if not exist EasySD_1_1_INSTALL.bin goto :missing_mb
for %%F in (EasySD_1_1_INSTALL.bin) do if not "%%~zF"=="13312" goto :bad_mb_size

rem ------------------------------------------------------------
rem eLeMeNt ZX
rem ------------------------------------------------------------
echo.
echo [2/4] Building eLeMeNt ZX...
"%SJASM%" --define DUAL_GUI_TEST --define DUAL_GUI_INSTALL_TEST --define ELEMENT --define SD_ONLY_PAGE98 --lst=EasySD_1_1_EL.lst --raw=EasySD_1_1_EL.bin easyhdd_1_1_release_SD12.a80
if errorlevel 1 goto :error_el
if not exist EasySD_1_1_EL.bin goto :missing_el

rem ------------------------------------------------------------
rem MB03+ Slim
rem SLIM uses the SD-only one-page model: BSDOS page 97, EasySD page 98.
rem SD1 and SD2 share the same resident driver page.
rem ------------------------------------------------------------
echo.
echo [3/4] Building MB03+ Slim...
"%SJASM%" --define DUAL_GUI_TEST --define DUAL_GUI_INSTALL_TEST --define SLIM --define SD_ONLY_PAGE98 --lst=EasySD_1_1_SLIM.lst --raw=EasySD_1_1_SLIM.bin easyhdd_1_1_release_SD12.a80
if errorlevel 1 goto :error_slim
if not exist EasySD_1_1_SLIM.bin goto :missing_slim
for %%F in (EasySD_1_1_SLIM.bin) do if %%~zF GTR 16384 goto :bad_slim_size

rem ------------------------------------------------------------
rem TAP files - PowerShell only, no Python
rem ------------------------------------------------------------
echo.
echo [4/4] Building TAP files...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make_taps_1_1_SD12.ps1"
if errorlevel 1 goto :error_taps

if not exist EasySD_1_1_INSTALL.tap goto :missing_taps
if not exist EasySD_1_1_EL.tap goto :missing_taps
if not exist EasySD_1_1_SLIM.tap goto :missing_taps

echo.
echo ========================================
echo   EASYSD 1.1 BUILD OK
echo ========================================
for %%F in (EasySD_1_1_INSTALL.bin) do echo   EasySD_1_1_INSTALL.bin  %%~zF bytes
for %%F in (EasySD_1_1_EL.bin)      do echo   EasySD_1_1_EL.bin       %%~zF bytes
for %%F in (EasySD_1_1_SLIM.bin)    do echo   EasySD_1_1_SLIM.bin     %%~zF bytes
echo.
echo   EasySD_1_1_INSTALL.tap
echo   EasySD_1_1_EL.tap
echo   EasySD_1_1_SLIM.tap
echo ========================================
popd
exit /b 0

:error_mb
echo *** MB03+ BUILD FAILED ***
goto :fail
:error_el
echo *** eLeMeNt BUILD FAILED ***
goto :fail
:error_slim
echo *** MB03+ SLIM BUILD FAILED ***
goto :fail
:error_taps
echo *** TAP BUILD FAILED ***
goto :fail
:missing_mb
echo *** EasySD_1_1_INSTALL.bin WAS NOT CREATED ***
goto :fail
:missing_el
echo *** EasySD_1_1_EL.bin WAS NOT CREATED ***
goto :fail
:missing_slim
echo *** EasySD_1_1_SLIM.bin WAS NOT CREATED ***
goto :fail
:missing_taps
echo *** ONE OR MORE TAP FILES WERE NOT CREATED ***
goto :fail
:bad_mb_size
echo *** WRONG MB03+ SIZE - EXPECTED 13312 BYTES ***
goto :fail
:bad_slim_size
echo *** SLIM BINARY TOO LARGE - MUST FIT IN 16384 BYTES ***
goto :fail
:fail
popd
exit /b 1
