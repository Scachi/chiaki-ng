@echo off
:: ============================================================================
:: Build chiaki-lib with DYNAMIC OpenSSL, STATIC everything else
::
:: STRATEGY:
::   1. Install openssl:x64-windows (dynamic DLLs)
::   2. Install everything else:x64-windows-static (static libs)
::   3. Force CMake to use dynamic OpenSSL from x64-windows
::
:: This gives us the best of both worlds:
::   - OpenSSL: Dynamic (uses Helios's libssl-3-x64.dll at runtime)
::   - Other deps: Static (embedded, no extra DLLs needed)
::
:: IMPORTANT: Clean build if you previously used a different configuration:
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

:: Use custom triplet: x64-windows-mixed (static by default, dynamic for OpenSSL)
set "VCPKG_INSTALLED=%~dp0vcpkg_installed\x64-windows-mixed"
set PATH=%VCPKG_INSTALLED%\tools\pkgconf;%PATH%;%VCPKG_INSTALLED%\tools\protobuf
set PKG_CONFIG_PATH=%VCPKG_INSTALLED%\lib\pkgconfig

echo =====================================================
echo Building chiaki-lib with CUSTOM TRIPLET:
echo   Triplet: x64-windows-mixed
echo   - OpenSSL: DYNAMIC (will load from Helios at runtime)
echo   - All other libs: STATIC (embedded in chiaki.lib)
echo =====================================================
echo Using vcpkg MANIFEST MODE - dependencies from vcpkg.json
echo vcpkg will install dependencies during CMake configure...
echo =====================================================
cmake -S . -B build -G "Ninja" -DCMAKE_BUILD_TYPE=Release -DOPENSSL_USE_STATIC_LIBS=OFF -DCHIAKI_ENABLE_PI_DECODER=OFF -DCHIAKI_ENABLE_FFMPEG_DECODER=OFF -DCHIAKI_ENABLE_CLI=OFF -DCHIAKI_ENABLE_GUI=OFF -DCHIAKI_ENABLE_TESTS=OFF -DCHIAKI_ENABLE_SPEEX=OFF -DCHIAKI_ENABLE_STEAM_SHORTCUT=OFF -DCHIAKI_ENABLE_STEAMDECK_NATIVE=OFF -DCHIAKI_LIB_ENABLE_OPUS=OFF -DCMAKE_TOOLCHAIN_FILE=D:/workspace/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x64-windows-mixed -DVCPKG_OVERLAY_TRIPLETS=%~dp0 -DVCPKG_INSTALLED_DIR=%~dp0vcpkg_installed -DPKG_CONFIG_EXECUTABLE=%VCPKG_INSTALLED%/tools/pkgconf/pkgconf.exe

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

:: Verify OpenSSL DLLs (should be in x64-windows-mixed directory)
if exist "%VCPKG_INSTALLED%\bin\libssl-3-x64.dll" (
    echo [OK] OpenSSL DLLs (dynamic) found:
    echo      %VCPKG_INSTALLED%\bin\libssl-3-x64.dll
    echo      %VCPKG_INSTALLED%\bin\libcrypto-3-x64.dll
) else (
    echo [WARNING] OpenSSL DLLs not found in vcpkg_installed!
)

:: Check static libs
if exist "%VCPKG_INSTALLED%\lib\json-c.lib" (
    echo [OK] json-c is STATIC (embedded in chiaki.lib)
)
if exist "%VCPKG_INSTALLED%\lib\libprotobuf.lib" (
    echo [OK] protobuf is STATIC (embedded in chiaki.lib)
)
if exist "%VCPKG_INSTALLED%\lib\miniupnpc.lib" (
    echo [OK] miniupnpc is STATIC (embedded in chiaki.lib)
)

echo.
echo =====================================================
echo Library Configuration (x64-windows-mixed triplet):
echo =====================================================
echo OpenSSL:   DYNAMIC (links to import libs, loads DLLs at runtime)
echo json-c:    STATIC  (embedded in chiaki.lib)
echo protobuf:  STATIC  (embedded in chiaki.lib)
echo miniupnpc: STATIC  (embedded in chiaki.lib)
echo.
echo At runtime, PSRemotePlay.dll will load OpenSSL from Helios:
echo   D:\ProgrammePortable\Helios2\Helios\lib\libssl-3-x64.dll
echo   D:\ProgrammePortable\Helios2\Helios\lib\libcrypto-3-x64.dll
echo.
echo vcpkg OpenSSL version: 3.x (for building)
echo Helios OpenSSL version: Should be compatible 3.x
echo =====================================================
