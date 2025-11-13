set(SOURCE
		include/chiaki-cli.h
		src/discover.c
		src/wakeup.c)

add_library(chiaki-cli-lib STATIC ${SOURCE})
target_include_directories(chiaki-cli-lib PUBLIC "include")
target_link_libraries(chiaki-cli-lib chiaki-lib)

if(CHIAKI_CLI_ARGP_STANDALONE)
	find_package(Argp REQUIRED)
	target_link_libraries(chiaki-cli-lib Argp::Argp)
endif()

add_executable(chiaki-cli src/main.c)
target_link_libraries(chiaki-cli chiaki-cli-lib)
install(TARGETS chiaki-cli)

# Add lightweight control-only client
add_executable(chiaki-control src/control.c)
target_link_libraries(chiaki-control chiaki-lib)
install(TARGETS chiaki-control)

# Qt-based small utility to dump rp keys from QSettings
find_package(Qt6 REQUIRED COMPONENTS Core)
add_executable(qt_dump_keys src/qt_dump_keys.cpp)
target_link_libraries(qt_dump_keys PRIVATE Qt6::Core)
# Make sure includes are available
target_include_directories(qt_dump_keys PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")
install(TARGETS qt_dump_keys)
