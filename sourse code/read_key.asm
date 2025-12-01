; read_key.asm - 16-bit BIOS keyboard input
; 반환: AL = ASCII 코드
[BITS 16]
global read_key

read_key:
    xor ah, ah      ; AH = 0 → BIOS int 16h read key
    int 0x16        ; BIOS keyboard interrupt
    ret