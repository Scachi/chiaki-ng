@echo off

set "SCRIPT_DIR=%~dp0"

start "" "C:\msys64\usr\bin\bash.exe" -lc "cd \"$(cygpath -u '%SCRIPT_DIR%')\" && ./make_deploy.sh; exec bash -i"
exit /b %ERRORLEVEL%
