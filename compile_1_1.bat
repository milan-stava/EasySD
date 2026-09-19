@echo off
setlocal
pushd "%~dp0"

echo.
echo ========================================
echo   Building EasySD/EasyCF 1.1 for MB03+
echo ========================================

del /q EasySD_1_1_INSTALL.bin EasySD_1_1_INSTALL.lst 2>nul
sjasmplus --define DUAL_GUI_TEST --define DUAL_GUI_INSTALL_TEST --lst=EasySD_1_1_INSTALL.lst --raw=EasySD_1_1_INSTALL.bin easyhdd.a80
if errorlevel 1 goto :error_install
if not exist EasySD_1_1_INSTALL.bin goto :missing_install

del /q SWITCH_ALL.bin SWITCH_ALL.lst 2>nul
sjasmplus --lst=SWITCH_ALL.lst --raw=SWITCH_ALL.bin switch_device_unified.a80
if errorlevel 1 goto :error_switch
if not exist SWITCH_ALL.bin goto :missing_switch

del /q FULL_SWITCHER_1_1.bin FULL_SWITCHER_1_1.lst 2>nul
sjasmplus --lst=FULL_SWITCHER_1_1.lst --raw=FULL_SWITCHER_1_1.bin FULL_SWITCHER_1_1.a80
if errorlevel 1 goto :error_full_switch
if not exist FULL_SWITCHER_1_1.bin goto :missing_full_switch

python make_1_1_tap.py
if errorlevel 1 goto :error_taps
python make_switch_menu.py
if errorlevel 1 goto :error_taps

echo.
echo ========================================
echo   BUILD 1.1 OK
echo ========================================
echo   EasySD_1_1_INSTALL.tap
echo   SWITCH_MENU.tap
echo   FULL_SWITCHER_1_1.bin
echo ========================================
popd
exit /b 0

:error_install
echo *** EasySD 1.1 INSTALL BUILD FAILED ***
goto :fail
:error_switch
echo *** SWITCHER BUILD FAILED ***
goto :fail
:error_full_switch
echo *** FULL SWITCHER 1.1 BUILD FAILED ***
goto :fail
:error_taps
echo *** TAP BUILD FAILED ***
goto :fail
:missing_install
echo *** EasySD_1_1_INSTALL.bin WAS NOT CREATED ***
goto :fail
:missing_switch
echo *** SWITCH_ALL.bin WAS NOT CREATED ***
goto :fail
:missing_full_switch
echo *** FULL_SWITCHER_1_1.bin WAS NOT CREATED ***
goto :fail
:fail
popd
exit /b 1
