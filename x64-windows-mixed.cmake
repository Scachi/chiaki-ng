# Custom vcpkg triplet: x64-windows-mixed
# Static linking for most libraries, dynamic linking ONLY for OpenSSL
#
# Based on x64-windows-static with OpenSSL override

set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

# Special handling for OpenSSL - force dynamic linking
if(PORT MATCHES "^openssl$")
    set(VCPKG_LIBRARY_LINKAGE dynamic)
    message(STATUS "[CUSTOM TRIPLET] OpenSSL will use DYNAMIC linking")
endif()
