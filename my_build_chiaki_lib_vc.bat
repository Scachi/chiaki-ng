@echo off
:: ============================================================================
:: Build chiaki-lib with DYNAMIC OpenSSL linking
::
:: This project uses vcpkg MANIFEST MODE (vcpkg.json).
:: Dependencies will be installed automatically when CMake runs.
::
:: The VCPKG_TARGET_TRIPLET is set to 'x64-windows' which provides DLL versions.
:: The resulting chiaki.lib will depend on OpenSSL DLLs at runtime.
::
:: IMPORTANT: If you previously built with x64-windows-static, clean first:
::   rmdir /s /q build
::   rmdir /s /q vcpkg_installed
:: ============================================================================

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

:: Use local vcpkg_installed directory with STATIC libraries (except OpenSSL)
:: Using x64-windows-static but OpenSSL will be dynamic via OPENSSL_USE_STATIC_LIBS=OFF
set "VCPKG_INSTALLED=%~dp0vcpkg_installed\x64-windows-static"
set PATH=%VCPKG_INSTALLED%\tools\pkgconf;%PATH%;%VCPKG_INSTALLED%\tools\protobuf
set PKG_CONFIG_PATH=%VCPKG_INSTALLED%\lib\pkgconfig

echo =====================================================
echo Building chiaki-lib with MIXED linking:
echo   - OpenSSL: DYNAMIC (from Helios at runtime)
echo   - Other libs: STATIC (embedded in chiaki.lib)
echo Using vcpkg MANIFEST MODE - dependencies from vcpkg.json
echo VCPKG_TARGET_TRIPLET: x64-windows-static
echo =====================================================
echo vcpkg will automatically install dependencies during CMake configure...
echo =====================================================
cmake -S . -B build -G "Ninja" -DCMAKE_BUILD_TYPE=Release -DOPENSSL_USE_STATIC_LIBS=OFF -DCHIAKI_ENABLE_PI_DECODER=OFF -DCHIAKI_ENABLE_FFMPEG_DECODER=OFF -DCHIAKI_ENABLE_CLI=OFF -DCHIAKI_ENABLE_GUI=OFF -DCHIAKI_ENABLE_TESTS=OFF -DCHIAKI_ENABLE_SPEEX=OFF -DCHIAKI_ENABLE_STEAM_SHORTCUT=OFF -DCHIAKI_ENABLE_STEAMDECK_NATIVE=OFF -DCHIAKI_LIB_ENABLE_OPUS=OFF -DCMAKE_TOOLCHAIN_FILE=D:/workspace/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x64-windows-static -DVCPKG_INSTALLED_DIR=%~dp0vcpkg_installed -DPKG_CONFIG_EXECUTABLE=%VCPKG_INSTALLED%/tools/pkgconf/pkgconf.exe -DOPENSSL_ROOT_DIR=%VCPKG_INSTALLED%

if errorlevel 1 (
    echo.
    echo =====================================================
    echo ERROR: CMake configuration failed!
    echo =====================================================
    pause
    exit /b 1
)

cmake --build build --target chiaki-lib

if errorlevel 1 (
    echo.
    echo =====================================================
    echo ERROR: Build failed!
    echo =====================================================
    pause
    exit /b 1
)

echo.
echo =====================================================
echo Build completed successfully!
echo =====================================================
echo chiaki.lib location: %~dp0build\lib\chiaki.lib
echo.

:: Verify OpenSSL DLLs were installed
if exist "%VCPKG_INSTALLED%\bin\libssl-3-x64.dll" (
    echo OpenSSL DLLs installed by vcpkg:
    echo   %VCPKG_INSTALLED%\bin\libssl-3-x64.dll
    echo   %VCPKG_INSTALLED%\bin\libcrypto-3-x64.dll
) else (
    echo WARNING: OpenSSL DLLs not found in vcpkg_installed!
)

echo.
echo IMPORTANT: This library now depends on OpenSSL DLLs at runtime.
echo At runtime, it will use the OpenSSL DLLs from Helios:
echo   - D:\ProgrammePortable\Helios2\Helios\lib\libssl-3-x64.dll
echo   - D:\ProgrammePortable\Helios2\Helios\lib\libcrypto-3-x64.dll
echo.
echo Make sure these DLLs are compatible with the vcpkg version used for building.
echo If you encounter runtime errors, the OpenSSL versions might be incompatible.
echo =====================================================
