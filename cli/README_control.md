chiaki-control — control-only CLI client

What this is

A very small control-only client that connects to a PlayStation console using the chiaki core library and sends controller input only. It disables audio/video so it doesn't initialize decoders, renderers or audio output — ideal for a lightweight remote-control binary.

Files

- `src/control.c` — the control client implementation
- `CMakeLists.txt` — updated to provide a `chiaki-control` target

Prerequisites

- A working build of the project (the core `chiaki-lib` library must be available to CMake). This project uses CMake.
- A compiler and generator supported by CMake (Ninja, MSVC, MinGW, etc.).

Quick build (recommended from project root)

These example commands are for the default Windows `cmd.exe` shell. If you use another environment (MSYS2, WSL, Linux or macOS) adapt the generator and path syntax accordingly.

Single-config (Ninja, MinGW-w64 - recommended if you have Ninja):

```bat
rem Create a build directory and configure
cmake -S . -B build -G "Ninja" -DCMAKE_BUILD_TYPE=Release

rem Build only the control client
cmake --build build --target chiaki-control
```

Multi-config (Visual Studio generator):

```bat
rem Configure (choose desired generator if needed)
cmake -S . -B build

rem Build chiaki-control in Release configuration
cmake --build build --target chiaki-control --config Release
```

Where the binary will be

- After a successful build, the `chiaki-control` binary will be under the build output (for Ninja: `build\chiaki-control.exe`; for Visual Studio: `build\Release\chiaki-control.exe`).

Run usage

Usage:

```bat
chiaki-control <host> <regist_key_hex> <morning_hex> [--ps5]
```

Example:

```bat
build\chiaki-control.exe 192.168.1.100 00112233445566778899aabbccddeeff 00112233445566778899aabbccddeeff --ps5
```

Notes about parameters

- `host` — console IP or hostname.
- `regist_key_hex` — the registration key for the console (hex string). This must match the exact byte length expected by the library (the client checks length and will print an error if wrong). If you don't have this, register the client using the GUI or the project's registration flow first.
- `morning_hex` — the "morning" secret (hex) used for authentication; length is 16 bytes (32 hex characters).
- `--ps5` — optional flag to mark the connection as PS5. Omit for PS4.

Keyboard controls (local stdin)

- WASD: left stick (W=up, S=down, A=left, D=right)
- IJKL: right stick (I=up, K=down, J=left, L=right)
- Space: toggle CROSS (X) button
- X: reset axes to zero
- Q: quit the client

Behavior and notes

- The client sets `audio_video_disabled` so it does not initialize decoders or rendering; it only sends controller state and receives basic events (connected, quit, rumble, etc.).
- The program prints event notifications to stdout. Rumble events are printed but not forwarded to any local haptics device.
- This is a minimal demo client. For production use you probably want to wire a proper controller backend (SDL2) instead of keyboard stdin, and add robust argument parsing and registration helpers.

Troubleshooting

- "regist_key must be N hex chars" or "morning must be N hex chars": your hex strings are the wrong length. Re-check how you obtained the registration keys.
- If you don't get a connection: verify host IP, console is on, and registration secrets are valid. For remote hosts (over internet), holepunch/PSN token steps are required — this client doesn't perform PSN holepunch negotiation automatically.

Next steps / suggestions

- Add an argument parser (argp/getopt) and support reading registration secrets from a file.
- Add SDL2 joystick input forwarding so you can use a real controller instead of the keyboard.
- Implement PSN/holepunch flow if you need remote internet connections in CLI mode.

License

Follows the repository license (see top-level COPYING / LICENSE files).
