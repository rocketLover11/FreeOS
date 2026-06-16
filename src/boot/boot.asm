[org 0x7C00]
[bits 16]

;
; FAT12 header
;
jmp short start
nop

oem:  db 'MSWIN4.1'
bps:  dw 512        ; Bytes per sector
spc:  db 1          ; Sectors per cluster
rs:   dw 1          ; Reserved sectors
fc:   db 2          ; FAT count
deco: dw 0xE0       ; Directory entries count
ts:   dw 2880       ; Total sectors
mdt:  db 0xF0       ; Media descriptor type
spf:  dw 9          ; Sectors per FAT
spt:  dw 18         ; Sectors per track
heds: dw 2          ; Heads
hs:   dd 0          ; Hidden sectors
lsc:  dd 0          ; Large sector count

; Extended boot record
dn:   db 0          ; Drive number
      db 0
sig:  db 0x29       ; Signature
vid:  db 0x54, 0x45, 0xA0, 0xB0 ; Serial number
vl:   db 'FREE OS    '
sid:  db 'FAT12      '

start:
    jmp main

;
; Halts the program
;
halt:
    cli
    hlt

;
; Prints a string to the screen
; Params:
;   - ds:si points to string
;
printstr:
    push si
    push ax
    mov ah, 0x0E
    mov bh, 0
.loop:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    pop ax
    pop si
    ret

;
; Converts an LBA address to CHS address
; Params:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector
;   - cx [bits 6-15]: cylinder
;   - dh: head
lba_to_chs:
    push ax
    push dx

    xor dx, dx
    div word [spt]
    inc dx
    mov cx, dx
    xor dx, dx
    div word [heds]
    mov dh, dl
    mov ch, al
    shl ah, 6
    or cl, ah
    
    pop ax
    mov dl, al
    pop ax
    ret

;
; Shows a disk error message
;
disk_err:
    mov si, msg_disk_err
    call printstr
    mov ah, 0
    int 0x16
    jmp 0xFFFF:0
    jmp halt

;
; Resets disk controller
; Params:
;   - dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 0x13
    jc disk_err
    popa
    ret

;
; Reads sectors from a disk
; Params:
;   - ax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address to store the data
;
disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs
    pop ax
    mov ah, 0x02
    mov di, 3
.retry:
    pusha
    stc
    int 0x13
    jnc .done
    popa
    call disk_reset
    dec di
    test di, di
    jnz .retry
.fail:
    jmp disk_err
.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret


main:
    ; Setup data segments
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; Setup stack
    mov ss, ax
    mov sp, 0x7C00

    mov ah, 0x05
    mov al, 0x02
    int 0x10

    mov si, msg_start
    call printstr

    mov [dn], dl
    mov ax, 1
    mov cl, 1
    mov bx, 0x7E00
    call disk_read

    jmp halt

msg_start: db 'Booting Free OS...', 0x0D, 0x0A, 0
msg_disk_err: db 'Failed to read from disk!', 0x0D, 0x0A, 0

times 510-($-$$) db 0
dw 0xAA55