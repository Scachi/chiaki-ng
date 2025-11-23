@echo off

setlocal enabledelayedexpansion

:: Find Visual Studio
for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath`) do (
    set "VS_PATH=%%i"
)

if not exist "%VS_PATH%\VC\Auxiliary\Build\vcvarsall.bat" (
    echo ERROR: Could not find Visual Studio installation
    exit /b 1
)

:: Initialize VS environment
echo Initializing Visual Studio environment...
call "%VS_PATH%\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1

:: Try to find Qt6
if "%QT_DIR%"=="" (
    if exist "C:\Qt\6.9.2\msvc2022_64" (
        set "QT_DIR=C:\Qt\6.9.2\msvc2022_64"
        echo Found Qt at: C:\Qt\6.9.2\msvc2022_64
    )
)

:: Configure and build
echo Configuring...
if "%QT_DIR%"=="" (
    cmake -B build -G "Ninja" -DCMAKE_BUILD_TYPE=Release -DCHIAKI_ENABLE_CLI=OFF -DCHIAKI_GUI_ENABLE_SDL_GAMECONTROLLER=ON -DCHIAKI_ENABLE_STEAMDECK_NATIVE=OFF
) else (
    cmake -B build -G "Ninja" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="%QT_DIR%"
)

if errorlevel 1 (
    echo ERROR: Configuration failed
    goto :cleanup
)

echo Building...
cmake --build build

if errorlevel 1 (
    echo ERROR: Build failed
    goto :cleanup
)

endlocal
