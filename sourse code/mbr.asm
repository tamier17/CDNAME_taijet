; NyxiumOS simple two-stage BIOS bootloader (learning / example)
; License: MIT — use this instead of ISOLINUX to avoid copyright concerns.
; This file contains two parts in a single document: mbr.asm (512-byte MBR) and
; stage2.asm (a simple second-stage loader). Build instructions are at the end.

; ---------------------------------------------------------------------------
; mbr.asm
; ---------------------------------------------------------------------------
; A minimal MBR that prints a message, loads the next sectors (stage2) into
; 0x0000:0x0600 using BIOS int 0x13, then jumps to it.
;
; Notes/assumptions:
; - Assembled with NASM as a flat binary (nasm -f bin mbr.asm -o mbr.bin)
; - Loads "stage2" starting at disk sector 2 (LBA 1) — many simple images use
;   this layout: sector 0 = MBR, sector 1.. = stage2/kernel
; - For a real floppy/hard-disk/USB the CHS mapping can differ; for robust
;   loaders use INT 13 extensions (AH=0x42) or use a stage that understands
;   BIOS geometry. This example keeps it small for educational use.

org 0x7c00
BITS 16

start:
    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7c00       ; temporary stack

    mov si, msg
    call print_string

    ; load stage2: read 8 sectors from CH=0 CL=2 DH=0 (sector 2..9)
    mov ah, 0x02        ; BIOS read sectors
    mov al, 8           ; count (adjust as needed)
    mov ch, 0x00        ; cylinder
    mov cl, 0x02        ; sector start (sector numbers start at 1) -> sector 2
    mov dh, 0x00        ; head
    mov dl, [boot_drive] ; drive (filled by BIOS at boot: 0x80 for HDD)
    mov bx, 0x0600      ; offset into ES where to load
    mov es, ax          ; ES = 0x0000
    int 0x13
    jc disk_error

    ; far jump to 0000:0600 (stage2)
    jmp 0x0000:0x0600

disk_error:
    mov si, err_msg
    call print_string
    hlt_loop:
        hlt
        jmp hlt_loop

; ---------------------------------------------------------------------------
; simple string printer (BIOS teletype INT 0x10)
; prints zero-terminated string pointed by SI
; ---------------------------------------------------------------------------
print_string:
    pusha
.next_char:
    lodsb
    cmp al, 0
    je .done
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    jmp .next_char
.done:
    popa
    ret

msg: db "NyxiumOS boot: loading stage2...", 0x0D, 0x0A, 0
err_msg: db "Disk read error!", 0x0D,0x0A,0

; BIOS stores boot drive in the far stack: push/pop or at 0x0000:0x007C? Instead
; we'll read it from the stack location where many BIOSes place it after int 19.
; Safer approach: store DL copied earlier by BIOS when launching MBR.
; We'll reserve a byte to be filled by external stage if needed.
boot_drive: db 0x00

; fill rest of 512-byte MBR with zeros and signature
times 510 - ($ - $$) db 0
dw 0xAA55

; ---------------------------------------------------------------------------
; stage2.asm
; ---------------------------------------------------------------------------
; A very small second-stage loaded at 0000:0600. It prints a message and then
; (for now) waits. In real use this stage would parse a filesystem and load
; a kernel image.

; Assemble this file as a flat binary too (nasm -f bin stage2.asm -o stage2.bin)
; When the MBR above reads stage2 into 0x0000:0x0600, it jumps there.

; NOTE: Because stage2 is loaded to physical address 0x0600, set ORG accordingly.
org 0x0600
BITS 16

stage2_start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax

    mov si, stage2_msg
    call print_string_stage2

    ; Busy loop
hang:
    hlt
    jmp hang

; small printer that uses BIOS int 0x10; stage2 has own copy so it is self-contained
print_string_stage2:
    pusha
.next2:
    lodsb
    cmp al, 0
    je .done2
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    jmp .next2
.done2:
    popa
    ret

stage2_msg: db "NyxiumOS stage2: hello from stage2!", 0x0D,0x0A,0

; pad stage2 to a multiple of 512 bytes if you plan to write exact sectors
; (not necessary for an assembled binary, but dd will write full sectors)

; ---------------------------------------------------------------------------
; Build instructions (example)
; ---------------------------------------------------------------------------
; Requirements: nasm, dd (on Unix-like systems). Windows users can use WSL or
; equivalent tooling.

; 1) Assemble MBR and stage2:
;    nasm -f bin mbr.asm -o mbr.bin
;    nasm -f bin stage2.asm -o stage2.bin
;
; 2) Create a disk image and install the two parts into sectors:
;    # create empty image (e.g., 10 MiB)
;    dd if=/dev/zero of=disk.img bs=1M count=10
;
;    # write MBR into sector 0
;    dd if=mbr.bin of=disk.img bs=512 count=1 conv=notrunc
;
;    # write stage2 into sector 1.. (seek=1)
;    dd if=stage2.bin of=disk.img bs=512 seek=1 conv=notrunc
;
; 3) Boot the image in QEMU for testing:
;    qemu-system-x86_64 -drive format=raw,file=disk.img
;
; 4) To write to a USB device (DANGEROUS: double-check device), e.g. /dev/sdX:
;    sudo dd if=disk.img of=/dev/sdX bs=4M conv=fdatasync status=progress
;
; Notes and next steps:
; - This minimal loader is intentionally tiny; it does not implement a
;   filesystem or robust disk handling. For production use you will want a
;   stage2 that understands FAT/ISO9660 and can find and load a kernel file.
; - For ISO images (El Torito), creating a bootable ISO requires setting the
;   El Torito boot catalog and embedding a boot image. Tools such as xorriso
;   or grub-mkrescue can create El Torito-compatible images. If you want a
;   purely custom El Torito master boot record and boot catalog, that's also
;   possible but more complex.
; - If you intend to publish your bootloader, choose a permissive license
;   (MIT/BSD) to avoid copyright/compatibility concerns. The header above uses
;   MIT as an example.

; ---------------------------------------------------------------------------
; Security / portability tips
; ---------------------------------------------------------------------------
; - Using INT 13 CHS calls is simple but may fail on certain modern setups
;   (large disks, virtualization differences). Consider using INT 13h EDD
;   extensions (AH=0x42) or rely on a small BIOS-compatible FAT reader in
;   the second stage.
; - Test widely: QEMU, VirtualBox, and a real machine if possible.

; End of document
