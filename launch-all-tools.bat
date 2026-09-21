@echo off
:: Launches every tool of this repository, each in its own window.
:: A tool is a folder <tool>\ holding a launcher named <tool>.bat — discovered at run time, nothing to edit here.
setlocal
set "launchedCount=0"
for /d %%T in ("%~dp0*") do (
    if exist "%%~T\%%~nxT.bat" (
        echo Launching %%~nxT
        start "%%~nxT" /d "%%~T" "%%~T\%%~nxT.bat"
        set /a launchedCount+=1
    )
)
if %launchedCount%==0 (
    echo No tool found: expected ^<tool^>\^<tool^>.bat next to this file.
    pause
)
endlocal
