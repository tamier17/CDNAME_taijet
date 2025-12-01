; boot.asm - 512 bytes MBR
[org 0x7C00]

cli
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7C00
sti

; 커널 로드 (섹터 2~5, 0x8000에)
mov bx, 0x8000
mov dh, 4
mov dl, 0x80
mov ch, 0
mov cl, 2
mov ah, 0x02
int 0x13

jmp 0x0000:0x8000

times 510-($-$$) db 0
dw 0xAA55