# Custom vcpkg Triplet: x64-windows-mixed

## What is a vcpkg Triplet?

A triplet defines how vcpkg builds packages:
- **Architecture**: x86, x64, arm, etc.
- **CRT Linkage**: static or dynamic C runtime
- **Library Linkage**: static (.lib embedded) or dynamic (.dll files)

Standard triplets:
- `x64-windows`: Dynamic linking (all DLLs)
- `x64-windows-static`: Static linking (everything embedded)

## Our Custom Triplet: x64-windows-mixed

**File**: `x64-windows-mixed.cmake`

**Purpose**: Static linking by default, but dynamic linking ONLY for OpenSSL

```cmake
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)  # Default: static

# Exception for OpenSSL
if(PORT MATCHES "^openssl$")
    set(VCPKG_LIBRARY_LINKAGE dynamic)  # OpenSSL uses DLLs
endif()
```

## How It Works

When vcpkg builds packages using this triplet:

1. **Most packages** (json-c, protobuf, miniupnpc):
   - `VCPKG_LIBRARY_LINKAGE = static`
   - Builds `.lib` files that get embedded in chiaki.lib
   - No DLLs needed at runtime

2. **OpenSSL** (matched by `if(PORT MATCHES "^openssl$")`):
   - `VCPKG_LIBRARY_LINKAGE = dynamic`
   - Builds import libraries (`.lib`) that link to DLLs
   - Creates `libssl-3-x64.dll` and `libcrypto-3-x64.dll`
   - At runtime, loads DLLs from Helios

## Build Command

```batch
cmake ... -DVCPKG_TARGET_TRIPLET=x64-windows-mixed -DVCPKG_OVERLAY_TRIPLETS=%~dp0
```

- `VCPKG_TARGET_TRIPLET`: Use our custom triplet
- `VCPKG_OVERLAY_TRIPLETS`: Tell vcpkg where to find `x64-windows-mixed.cmake`

## Result

### Install Directory
```
vcpkg_installed/
  └── x64-windows-mixed/
      ├── bin/
      │   ├── libssl-3-x64.dll      <-- OpenSSL (dynamic)
      │   └── libcrypto-3-x64.dll   <-- OpenSSL (dynamic)
      └── lib/
          ├── libssl.lib             <-- Import lib (links to DLL)
          ├── libcrypto.lib          <-- Import lib (links to DLL)
          ├── json-c.lib             <-- Static (embedded)
          ├── libprotobuf.lib        <-- Static (embedded)
          └── miniupnpc.lib          <-- Static (embedded)
```

### chiaki.lib
- Contains: json-c, protobuf, miniupnpc (static)
- Links to: OpenSSL import libraries (`.lib` files)
- Runtime: Loads OpenSSL DLLs from Helios

### PSRemotePlay.dll
- Links to: chiaki.lib
- Runtime dependencies: **ONLY** OpenSSL DLLs from Helios
- No json-c, protobuf, or miniupnpc DLLs needed!

## Why Not Just Use x64-windows?

If we used `x64-windows` (all dynamic):
```
vcpkg_installed/x64-windows/bin/
├── libssl-3-x64.dll       ✅ Helios provides
├── libcrypto-3-x64.dll    ✅ Helios provides
├── json-c.dll             ❌ Helios does NOT provide
├── libprotobuf.dll        ❌ Helios does NOT provide
└── miniupnpc.dll          ❌ Helios does NOT provide
```

We'd need to copy extra DLLs to Helios or bundle them with the plugin.

## Why Not Just Use x64-windows-static?

If we used `x64-windows-static` (all static):
- OpenSSL gets embedded in chiaki.lib (~5MB)
- PSRemotePlay.dll becomes very large
- Can't use Helios's OpenSSL DLLs
- Duplicate OpenSSL code in memory if multiple plugins use it

## Advantages of x64-windows-mixed

✅ **Small chiaki.lib**: No embedded OpenSSL (~2-3MB instead of ~5MB)
✅ **Small PSRemotePlay.dll**: OpenSSL not duplicated
✅ **Uses Helios OpenSSL**: Consistent version across all plugins
✅ **No extra DLL copying**: json-c, protobuf, miniupnpc are static
✅ **Simple distribution**: Only needs Helios's existing OpenSSL DLLs

## Verification

After building, check:
```cmd
check_chiaki_build.bat
```

Expected output:
```
[OK] vcpkg x64-windows-mixed directory found
[OK] OpenSSL DLL found: libssl-3-x64.dll
[OK] OpenSSL DLL found: libcrypto-3-x64.dll
[OK] miniupnpc is STATIC (lib file)
[OK] json-c is STATIC (lib file)
[OK] protobuf is STATIC (lib file)
```

You can also check with dumpbin:
```cmd
dumpbin /dependents PSRemotePlay.dll
```

Should show dependencies on:
- `libssl-3-x64.dll` ✅
- `libcrypto-3-x64.dll` ✅
- Qt6Core.dll, Qt6Widgets.dll (expected)
- Windows system DLLs (expected)

Should NOT show:
- json-c.dll ❌
- libprotobuf.dll ❌
- miniupnpc.dll ❌
