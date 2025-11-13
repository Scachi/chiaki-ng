// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <ctype.h>

#include "../include/chiaki-cli.h"
#include <chiaki/session.h>
#include <chiaki/log.h>
#include <chiaki/controller.h>
#include <chiaki/base64.h>

#ifdef _WIN32
#include <conio.h>
#include <windows.h>
#else
#include <termios.h>
#include <unistd.h>
#endif

static ChiakiSession session;
static ChiakiLog logg;
static bool running = true;

static void print_usage(const char *prog)
{
	printf("Usage: %s <host> <rpregistkey> <rpkey> [--ps5]\n", prog);
    printf("Usage: %s <host> <regist_key_> <morning_hex_16bytes> [--ps5]\n", prog);
    printf("Examples:\n");
    printf("  %s 192.168.1.100 00112233445566778899aabbccddeeff 00112233445566778899aabbccddeeff --ps5\n", prog);
}

static void event_cb(ChiakiEvent *event, void *user)
{
    (void)user;
    switch(event->type)
    {
        case CHIAKI_EVENT_CONNECTED:
            printf("[event] CONNECTED\n");
            break;
        case CHIAKI_EVENT_QUIT:
            printf("[event] QUIT reason=%u str=%s\n", event->quit.reason, event->quit.reason_str ? event->quit.reason_str : "");
            running = false;
            break;
        case CHIAKI_EVENT_LOGIN_PIN_REQUEST:
            printf("[event] LOGIN PIN REQUEST (incorrect=%d)\n", event->login_pin_request.pin_incorrect);
            break;
        case CHIAKI_EVENT_RUMBLE:
            printf("[event] RUMBLE left=%u right=%u\n", event->rumble.left, event->rumble.right);
            break;
        default:
            printf("[event] type=%d\n", event->type);
            break;
    }
}

#ifdef _WIN32
static int kbhit_nonblock()
{
    return _kbhit();
}
static int getch_nonblock()
{
    return _getch();
}
#else
static struct termios orig_term;
static void enable_raw_mode()
{
    struct termios t;
    tcgetattr(STDIN_FILENO, &orig_term);
    t = orig_term;
    t.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(STDIN_FILENO, TCSANOW, &t);
}
static void disable_raw_mode()
{
    tcsetattr(STDIN_FILENO, TCSANOW, &orig_term);
}

#include <sys/select.h>
static int kbhit_nonblock()
{
    struct timeval tv = {0, 0};
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(0, &fds);
    return select(1, &fds, NULL, NULL, &tv) == 1;
}
static int getch_nonblock()
{
    unsigned char c;
    if (read(0, &c, 1) <= 0) return -1;
    return c;
}
#endif

static bool hex_to_bytes(const char *hex, uint8_t *out, size_t out_len)
{
    size_t len = strlen(hex);
    if (len != out_len * 2) return false;
    for (size_t i = 0; i < out_len; i++)
    {
        char hi = hex[i*2];
        char lo = hex[i*2+1];
        if(!isxdigit(hi) || !isxdigit(lo)) return false;
        uint8_t vhi = (uint8_t)(isdigit(hi) ? hi - '0' : toupper(hi) - 'A' + 10);
        uint8_t vlo = (uint8_t)(isdigit(lo) ? lo - '0' : toupper(lo) - 'A' + 10);
        out[i] = (uint8_t)((vhi << 4) | vlo);
    }
    return true;
}

int main(int argc, char **argv)
{
    if (argc < 4)
    {
        print_usage(argv[0]);
        return 1;
    }

    const char *host = argv[1];
    const char *regist_hex = argv[2];
    const char *morning_hex = argv[3];
    bool is_ps5 = false;
    if (argc >= 5 && strcmp(argv[4], "--ps5") == 0) is_ps5 = true;

    chiaki_log_init(&logg, CHIAKI_LOG_ALL & ~CHIAKI_LOG_VERBOSE, chiaki_log_cb_print, NULL);

    ChiakiErrorCode lib_err = chiaki_lib_init();
    if (lib_err != CHIAKI_ERR_SUCCESS) {
        fprintf(stderr, "chiaki_lib_init failed: %s\n", chiaki_error_string(lib_err));
        return 2;
    }

    ChiakiConnectInfo ci = {};
    ci.ps5 = is_ps5;
    ci.host = host;
    chiaki_connect_video_profile_preset(&ci.video_profile, CHIAKI_VIDEO_RESOLUTION_PRESET_720p, CHIAKI_VIDEO_FPS_PRESET_60);
    ci.video_profile_auto_downgrade = true;
    ci.enable_keyboard = false;
    ci.enable_dualsense = false;
    ci.audio_video_disabled = CHIAKI_AUDIO_VIDEO_DISABLED;
    ci.auto_regist = false;
    ci.holepunch_session = NULL;
    ci.rudp_sock = NULL;
    ci.packet_loss_max = 0.0;

    if(!hex_to_bytes(regist_hex, (uint8_t*)ci.regist_key, sizeof(ci.regist_key)))
    {
        fprintf(stderr, "regist_key must be %zu hex chars\n", sizeof(ci.regist_key)*2);
        //return 2;
    }
    if(!hex_to_bytes(morning_hex, ci.morning, sizeof(ci.morning)))
    {
        fprintf(stderr, "morning must be %zu hex chars\n", sizeof(ci.morning)*2);
        //return 2;
    }

    ChiakiErrorCode err = chiaki_session_init(&session, &ci, &logg);
    if (err != CHIAKI_ERR_SUCCESS) {
        /* Print readable error to stderr. chiaki_error_string should return a const char* */
        fprintf(stderr, "chiaki_session_init failed: %s\n", chiaki_error_string(err));
    }

    if (err != CHIAKI_ERR_SUCCESS)
    {
        return 3;
    }
    chiaki_session_set_event_cb(&session, event_cb, NULL);

    if (chiaki_session_start(&session) != CHIAKI_ERR_SUCCESS)
    {
        fprintf(stderr, "chiaki_session_start failed\n");
        chiaki_session_fini(&session);
        return 4;
    }

#ifndef _WIN32
    enable_raw_mode();
    atexit(disable_raw_mode);
#endif

    ChiakiControllerState state;
    chiaki_controller_state_set_idle(&state);

    printf("Control client started. Use keys to control (WASD left stick, IJKL right stick, space toggle CROSS, q to quit)\n");
    printf("Press and hold keys for axis; release to zero. State will be sent on changes.\n");

    ChiakiControllerState prev;
    chiaki_controller_state_set_idle(&prev);

    const int axis_val = 0x7000; // analog magnitude

    while (running)
    {
        bool changed = false;
        // non-blocking keyboard polling
        if (kbhit_nonblock())
        {
            int c = getch_nonblock();
            if (c <= 0) { /* nothing */ }
            else if (c == 'q' || c == 'Q')
            {
                running = false; break;
            }
            else if (c == ' ')
            {
                // toggle cross (CHIAKI_CONTROLLER_BUTTON_CROSS)
                if (state.buttons & CHIAKI_CONTROLLER_BUTTON_CROSS)
                    state.buttons &= ~CHIAKI_CONTROLLER_BUTTON_CROSS;
                else
                    state.buttons |= CHIAKI_CONTROLLER_BUTTON_CROSS;
                changed = true;
            }
            else
            {
                // WASD for left stick, IJKL for right stick
                switch(c)
                {
                    case 'w': case 'W': state.left_y = -axis_val; changed = true; break;
                    case 's': case 'S': state.left_y = axis_val; changed = true; break;
                    case 'a': case 'A': state.left_x = -axis_val; changed = true; break;
                    case 'd': case 'D': state.left_x = axis_val; changed = true; break;
                    case 'i': case 'I': state.right_y = -axis_val; changed = true; break;
                    case 'k': case 'K': state.right_y = axis_val; changed = true; break;
                    case 'j': case 'J': state.right_x = -axis_val; changed = true; break;
                    case 'l': case 'L': state.right_x = axis_val; changed = true; break;
                    case 'x': case 'X': // reset axes
                        state.left_x = state.left_y = state.right_x = state.right_y = 0; changed = true; break;
                    default:
                        break;
                }
            }
        }
        // on no key pressed, we should zero axes (simple heuristic)
#ifdef _WIN32
        // On Windows getch is destructive; but to keep sample simple we don't auto-zero
#else
        // check if no keys available and previous left/right non-zero then zero them after small idle
        if (!kbhit_nonblock())
        {
            if (state.left_x != 0 || state.left_y != 0 || state.right_x != 0 || state.right_y != 0)
            {
                // slowly reset to zero
                state.left_x = state.left_y = state.right_x = state.right_y = 0;
                changed = true;
            }
        }
#endif

        if (!chiaki_controller_state_equals(&state, &prev))
        {
            ChiakiErrorCode r = chiaki_session_set_controller_state(&session, &state);
            if (r != CHIAKI_ERR_SUCCESS)
            {
                fprintf(stderr, "chiaki_session_set_controller_state failed: %d\n", r);
            }
            prev = state;
        }

        // Sleep briefly to avoid busy loop
#ifdef _WIN32
        Sleep(33);
#else
        usleep(33000);
#endif
    }

    printf("Shutting down...\n");
    chiaki_session_stop(&session);
    chiaki_session_join(&session);
    chiaki_session_fini(&session);

    return 0;
}
