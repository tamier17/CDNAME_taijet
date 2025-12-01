// kernel.c - SimpleOS v0.5 freestanding, string.h 없이 사용
#include <stdint.h>

#define VIDEO_MEM 0xB8000
#define SCREEN_WIDTH 80
#define SCREEN_HEIGHT 25
#define SCREEN_SIZE (SCREEN_WIDTH * SCREEN_HEIGHT)

volatile uint16_t* video = (uint16_t*) VIDEO_MEM;
int cursor = 0;

// -------------------------------
// 문자열 비교 (freestanding용)
int strcmp(const char* s1, const char* s2) {
    while (*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }
    return *(const unsigned char*)s1 - *(const unsigned char*)s2;
}

// -------------------------------
// 화면 스크롤
void scroll() {
    for (int i = SCREEN_WIDTH; i < SCREEN_SIZE; i++)
        video[i - SCREEN_WIDTH] = video[i];
    for (int i = SCREEN_SIZE - SCREEN_WIDTH; i < SCREEN_SIZE; i++)
        video[i] = 0x0720; // 공백 + 회색 배경
    cursor = SCREEN_SIZE - SCREEN_WIDTH;
}

// -------------------------------
// 단일 문자 출력
void print_char(char c) {
    if (c == '\n') {
        cursor = (cursor / SCREEN_WIDTH + 1) * SCREEN_WIDTH;
    } else if (c == '\r') {
        cursor = (cursor / SCREEN_WIDTH) * SCREEN_WIDTH;
    } else if (c == '\b') {
        if (cursor > 0) {
            cursor--;
            video[cursor] = 0x0720;
        }
        return;
    } else {
        video[cursor++] = (c | 0x0F00);
    }

    if (cursor >= SCREEN_SIZE)
        scroll();
}

// 문자열 출력
void print(const char* str) {
    while (*str) {
        print_char(*str++);
    }
}

// 화면 초기화
void clear_screen() {
    for (int i = 0; i < SCREEN_SIZE; i++)
        video[i] = 0x0720;
    cursor = 0;
}

// -------------------------------
// 명령어 함수
void cmd_restart() {
    print("Restarting...\n");
    // "eax" 레지스터를 클로버(Clobber) 리스트에 추가
    asm volatile(
        "int $0x19"
        : /* No output */
        : /* No input */
        : "eax" 
    );
}

void cmd_shutdown() {
    print("Attempting shutdown...\n");
    // eax, ebx, ecx 레지스터를 클로버 리스트에 추가
    asm volatile(
        "mov $0x5307, %%ax\n"
        "mov $0x0001, %%bx\n"
        "mov $0x0003, %%cx\n"
        "int $0x15\n"
        : /* No output */
        : /* No input */
        : "eax", "ebx", "ecx" 
    );
}
void cmd_clear() {
    clear_screen();
}

// 명령어 테이블
typedef void (*cmd_func)();

struct Command {
    const char* name;
    cmd_func func;
};

struct Command commands[] = {
    {"restart", cmd_restart},
    {"shutdown", cmd_shutdown},
    {"clear", cmd_clear},
};

#define CMD_COUNT (sizeof(commands)/sizeof(commands[0]))

// -------------------------------
// BIOS 키보드 입력
char read_key() {
    char c;
    asm volatile(
        "xor %%ah, %%ah\n"
        "int $0x16\n"
        "mov %%al, %0\n"
        : "=r"(c)
        :
        : "eax" // 32비트 레지스터를 클로버 리스트에 사용
    );
    return c;
}

void read_line(char* buf, int max_len) {
    int i = 0;
    while (i < max_len - 1) {
        char c = read_key();
        if (c == '\r') break;
        else if (c == '\b') {
            if (i > 0) {
                i--;
                print_char('\b');
            }
        } else if (c >= ' ' && c <= '~') {
            buf[i++] = c;
            print_char(c);
        }
    }
    buf[i] = 0;
    print("\n");
}

// -------------------------------
// Kernel main
void kernel_main() {
    clear_screen();
    print("SimpleOS v0.5 - Freestanding Terminal\n");

    char input[16];

    while(1) {
        print("> ");
        read_line(input, sizeof(input));

        int found = 0;
        for(int i=0;i<CMD_COUNT;i++){
            if (input[0]!=0 && strcmp(input, commands[i].name)==0) {
                commands[i].func();
                found = 1;
                break;
            }
        }

        if (!found) {
            print("Unknown command: ");
            print(input);
            print("\n");
        }
    }
}