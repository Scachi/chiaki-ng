@echo off

set "CONDA_ACTIVATE=C:\Users\scachi\Miniconda3\Scripts\activate.bat"
if exist "%CONDA_ACTIVATE%" (
    call "%CONDA_ACTIVATE%" cv
    echo Activated conda env 'cv'
) else (
    echo WARNING: conda activate script not found at %CONDA_ACTIVATE%
)


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

:: Use local vcpkg_installed directory with static libraries
set "VCPKG_INSTALLED=%~dp0vcpkg_installed\x64-windows-static"
set PATH=%VCPKG_INSTALLED%\tools\pkgconf;%PATH%;%VCPKG_INSTALLED%\tools\protobuf
set PKG_CONFIG_PATH=%VCPKG_INSTALLED%\lib\pkgconfig

rem c:\Users\scachi\Miniconda3\condabin\conda.bat activate
rem conda activate cv

rem Install static vcpkg packages: vcpkg install --triplet x64-windows-static
cmake -S . -B build -G "Ninja" -DCMAKE_BUILD_TYPE=Release -DCHIAKI_ENABLE_PI_DECODER=OFF -DCHIAKI_ENABLE_FFMPEG_DECODER=OFF -DCHIAKI_ENABLE_CLI=OFF -DCHIAKI_ENABLE_GUI=OFF -DCHIAKI_ENABLE_TESTS=OFF -DCHIAKI_ENABLE_SPEEX=OFF -DCHIAKI_ENABLE_STEAM_SHORTCUT=OFF -DCHIAKI_ENABLE_STEAMDECK_NATIVE=OFF -DCHIAKI_LIB_ENABLE_OPUS=OFF -DCMAKE_TOOLCHAIN_FILE=D:/workspace/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x64-windows-static -DVCPKG_INSTALLED_DIR=%~dp0vcpkg_installed -DPKG_CONFIG_EXECUTABLE=%VCPKG_INSTALLED%/tools/pkgconf/pkgconf.exe -DOPENSSL_ROOT_DIR=%VCPKG_INSTALLED%
cmake --build build --target chiaki-lib
