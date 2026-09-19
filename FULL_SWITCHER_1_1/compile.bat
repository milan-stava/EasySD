@echo off
setlocal
pushd "%~dp0"

del /q FULL_SWITCHER_1_1.bin FULL_SWITCHER_1_1.lst 2>nul
sjasmplus --lst=FULL_SWITCHER_1_1.lst --raw=FULL_SWITCHER_1_1.bin FULL_SWITCHER_1_1.a80
if errorlevel 1 goto :fail

if not exist FULL_SWITCHER_1_1.bin goto :fail
for %%F in (FULL_SWITCHER_1_1.bin) do if not "%%~zF"=="2924" goto :bad_size

echo FULL_SWITCHER_1_1.bin OK - 2924 bytes
popd
exit /b 0

:bad_size
echo *** WRONG FULL_SWITCHER_1_1.bin SIZE - EXPECTED 2924 BYTES ***
goto :fail

:fail
echo *** FULL SWITCHER 1.1 BUILD FAILED ***
popd
exit /b 1
