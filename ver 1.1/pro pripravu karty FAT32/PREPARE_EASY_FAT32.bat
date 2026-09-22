@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ================================================================
rem EasySD / EasyCF FAT32 preparation helper
rem
rem Purpose:
rem   Prepare a freshly formatted FAT32 BSDOS partition BEFORE
rem   MBD/MBH images are copied to it.
rem
rem v3:
rem   - waits for Windows removable-volume metadata:
rem       System Volume Information\IndexerVolumeGuid
rem       System Volume Information\WPSettings.dat
rem   - shows a live countdown while waiting
rem   - any key aborts the wait safely
rem   - pre-allocates 2500 FAT32 root-directory entries
rem     (suitable also for long VFAT/LFN image filenames)
rem   - if metadata already exists at startup, preparation continues
rem     immediately without the extra 3-second settle delay
rem ================================================================

set "WAIT_MAX=120"
set "TEMP_COUNT=2500"

rem Always operate on the drive where this BAT file is stored.
set "TARGET=%~d0"
set "ROOT=%TARGET%\"
set "SVI=%ROOT%System Volume Information"
cd /d "%ROOT%"

rem Require the BAT itself to be stored directly in the root directory.
if /I not "%~dp0"=="%ROOT%" (
    echo.
    echo ERROR: This BAT must be stored directly in the ROOT of the BSDOS partition.
    echo Current location: %~dp0
    echo Expected:         %ROOT%
    echo.
    goto :exit_error
)

rem Read the volume label (best effort; VOL output is localized).
set "VOL_LABEL="
set "VOL_LINE="
for /f "tokens=1,* delims=:" %%A in ('vol %TARGET% 2^>nul ^| findstr /i "Volume in drive Svazek"') do (
    set "VOL_LINE=%%B"
)
if defined VOL_LINE (
    for /f "tokens=*" %%A in ("!VOL_LINE!") do set "VOL_LABEL=%%A"
)
for /f "tokens=5,*" %%A in ('vol %TARGET% 2^>nul ^| findstr /i /c:"Volume in drive"') do set "VOL_LABEL=%%B"
if not defined VOL_LABEL set "VOL_LABEL=(unknown)"

echo ==========================================
echo   EasySD / EasyCF FAT32 preparation
echo ==========================================
echo.
echo Target drive : %TARGET%
echo Volume label : !VOL_LABEL!
echo.
echo This helper prepares a FAT32 partition BEFORE MBD/MBH images
echo are copied to it. The MBD/MBH data area must remain physically
echo contiguous on the medium.
echo.
echo IMPORTANT:
echo - Use this on a freshly formatted FAT32 BSDOS partition.
echo - Run this BAT BEFORE copying any MBD/MBH images.
echo - Do not copy other files while preparation is running.
echo.

rem Never prepare an already populated image partition.
if exist "%ROOT%*.MBD" goto :images_exist
if exist "%ROOT%*.MBH" goto :images_exist

rem Avoid overwriting/deleting somebody else's files with our temp prefix.
if exist "%ROOT%ESD*.TMP" (
    echo ERROR: Files matching ESD*.TMP already exist on %TARGET%
    echo.
    echo Please remove or rename those files and run this BAT again.
    echo No changes were made.
    echo.
    goto :exit_error
)

echo Step 1/2: Waiting for Windows volume metadata...
echo.
echo Waiting for:
echo   IndexerVolumeGuid
echo   WPSettings.dat
echo.
echo Windows normally creates these files after formatting the volume
echo or after the medium is inserted. This BAT does NOT try to create them.
echo.
echo If they are missing and Windows is not currently creating them,
echo safely eject and reinsert the medium, then run this BAT again.
echo.

call :check_metadata
if "!META_READY!"=="1" goto :metadata_already_ready

rem PowerShell is used only for the non-blocking keyboard check/countdown.
rem It also checks whether both metadata files have appeared.
set "ESD_SVI=%SVI%"
set "ESD_WAIT_MAX=%WAIT_MAX%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='SilentlyContinue';" ^
 "$svi=$env:ESD_SVI; $max=[int]$env:ESD_WAIT_MAX;" ^
 "$idx=Join-Path $svi 'IndexerVolumeGuid'; $wps=Join-Path $svi 'WPSettings.dat';" ^
 "$sw=[Diagnostics.Stopwatch]::StartNew(); $last=-1;" ^
 "while($true) {" ^
 "  $idxOk=[IO.File]::Exists($idx) -and ((Get-Item -Force -LiteralPath $idx).Length -gt 0);" ^
 "  $wpsOk=[IO.File]::Exists($wps) -and ((Get-Item -Force -LiteralPath $wps).Length -gt 0);" ^
 "  if($idxOk -and $wpsOk){Write-Host ''; exit 0};" ^
 "  $elapsed=[int][Math]::Floor($sw.Elapsed.TotalSeconds);" ^
 "  $remaining=[Math]::Max(0,$max-$elapsed);" ^
 "  if($remaining -ne $last){Write-Host (\"`rWaiting... {0,3} seconds remaining   Press any key to abort\" -f $remaining) -NoNewline; $last=$remaining};" ^
 "  try {if([Console]::KeyAvailable){[void][Console]::ReadKey($true); Write-Host ''; exit 7}} catch {};" ^
 "  if($elapsed -ge $max){Write-Host ''; exit 6};" ^
 "  Start-Sleep -Milliseconds 100;" ^
 "}"

set "WAIT_RESULT=%ERRORLEVEL%"
if "%WAIT_RESULT%"=="0" goto :metadata_ready_after_wait
if "%WAIT_RESULT%"=="7" goto :metadata_aborted
goto :metadata_timeout

:metadata_already_ready
echo Windows metadata is ready.
echo   IndexerVolumeGuid : !IDX_SIZE! bytes
echo   WPSettings.dat    : !WPS_SIZE! bytes
echo.
goto :prepare_root

:metadata_ready_after_wait
call :check_metadata
if not "!META_READY!"=="1" goto :metadata_timeout

echo.
echo Windows metadata is ready.
echo   IndexerVolumeGuid : !IDX_SIZE! bytes
echo   WPSettings.dat    : !WPS_SIZE! bytes
echo.
echo Waiting 3 extra seconds for the volume state to settle...
timeout /t 3 /nobreak >nul

call :check_metadata
if not "!META_READY!"=="1" (
    echo.
    echo ERROR: Metadata changed during the settle delay.
    echo Run this BAT again.
    echo.
    goto :exit_error
)

:prepare_root
echo Step 2/2: Pre-allocating FAT32 root-directory space...
echo.
echo Creating %TEMP_COUNT% temporary 8.3 directory entries...
echo This reserves enough FAT32 root-directory space for up to 255
echo MBD/MBH files even when long VFAT/LFN filenames are used.
echo.

set "CREATE_FAILED=0"
for /L %%i in (1,1,%TEMP_COUNT%) do (
    type nul > "%ROOT%ESD%%i.TMP"
    if errorlevel 1 (
        set "CREATE_FAILED=1"
        goto :temp_create_done
    )
)

:temp_create_done
if "!CREATE_FAILED!"=="1" (
    echo.
    echo ERROR: Could not create all temporary directory entries.
    echo Cleaning up...
    del /Q "%ROOT%ESD*.TMP" >nul 2>&1
    echo.
    echo Preparation FAILED. Do not copy MBD/MBH images yet.
    echo.
    goto :exit_error
)

echo Removing temporary files...
del /Q "%ROOT%ESD*.TMP" >nul 2>&1

if exist "%ROOT%ESD*.TMP" (
    echo.
    echo ERROR: Some temporary ESD*.TMP files could not be removed.
    echo Preparation FAILED. Do not copy MBD/MBH images yet.
    echo.
    goto :exit_error
)

echo.
echo ==========================================
echo   Preparation complete
echo ==========================================
echo.
echo Target drive : %TARGET%
echo Volume label : !VOL_LABEL!
echo.
echo Windows metadata was created BEFORE the image area and the FAT32
echo root directory has been pre-allocated for %TEMP_COUNT% entries.
echo.
echo NOW copy your MBD/MBH images to %TARGET%\
echo EasySD / EasyCF will find the physically first MBD/MBH image automatically.
echo.
echo IMPORTANT: Do not format the partition again after this step.
echo.
echo Press any key to exit...
pause >nul
endlocal
exit /b 0

:images_exist
echo ERROR: MBD or MBH files already exist on %TARGET%
echo.
echo Preparation must be performed BEFORE the images are copied.
echo No changes were made.
echo.
goto :exit_error

:metadata_aborted
echo.
echo Waiting aborted by user.
echo.
echo No root-directory preparation was performed.
echo DO NOT copy MBD/MBH files yet.
echo.
echo If the metadata files are missing:
echo   safely eject the medium,
echo   insert it again,
echo   then run this BAT again.
echo.
goto :exit_error

:metadata_timeout
echo.
echo ERROR: Windows did not create its removable-volume metadata
echo within %WAIT_MAX% seconds.
echo.
echo DO NOT copy MBD/MBH files yet.
echo.
echo Recommended procedure:
echo   1. Close this window.
echo   2. Safely eject the medium.
echo   3. Insert it again.
echo   4. Open the BSDOS drive once in Explorer/Total Commander.
echo   5. Wait a few seconds.
echo   6. Run this BAT again from the root of the BSDOS partition.
echo.
goto :exit_error

:exit_error
echo Press any key to exit...
pause >nul
endlocal
exit /b 1

:check_metadata
set "META_READY=0"
set "IDX_OK=0"
set "WPS_OK=0"
set "IDX_SIZE=0"
set "WPS_SIZE=0"

if exist "%SVI%\IndexerVolumeGuid" (
    for %%F in ("%SVI%\IndexerVolumeGuid") do set "IDX_SIZE=%%~zF"
    if !IDX_SIZE! GTR 0 set "IDX_OK=1"
)

if exist "%SVI%\WPSettings.dat" (
    for %%F in ("%SVI%\WPSettings.dat") do set "WPS_SIZE=%%~zF"
    if !WPS_SIZE! GTR 0 set "WPS_OK=1"
)

if "!IDX_OK!!WPS_OK!"=="11" set "META_READY=1"
exit /b 0
