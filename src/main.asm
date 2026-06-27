bits 16
org 0x7c00

%use ifunc

%define FPS 30
%define BLOCK_COUNT_X 8
%define BLOCK_COUNT_Y 8
%define PADDLE_HEIGHT 8
%define BLOCK_HEIGHT 8
%define BLOCK_WIDTH_PX 16 ; PLANAR_16PX
%define BLOCK_SPACE_PX 8 ; PLANAR_8PX
%define BALL_HEIGHT 8
%define PADDLE_X 100
%define PADDLE_X_MAX 200
%define PADDLE_Y 200
%define PLANAR_PX_PER_BYTE 8
%define DISPLAY_WIDTH_PX 640
%define DISPLAY_WIDTH_BYTES DISPLAY_WIDTH_PX / PLANAR_PX_PER_BYTE
%define MARGIN_TOP_PX 24
%define MARGIN_LEFT_PX 24
%define MARGIN_LEFT_BYTES MARGIN_LEFT_PX / PLANAR_PX_PER_BYTE
%define PADDLE_MOVE_PX 16
%define PLANAR_8PX 0xFF
%define PLANAR_16PX PLANAR_8PX + PLANAR_8PX
%define DEBUG xchg bx, bx
%define BALL_X_INIT 120
%define BALL_Y_INIT 150

start:
    xor ax, ax
    push ax
    pop es

init:
    .block_flags:
        inc ax ; mov ax, 1
        mov cx, BLOCK_COUNT_X * BLOCK_COUNT_Y
        lea di, block_flags
        rep stosb

    .vga:
        push 0xa000
        pop es
        mov al, 0x12 ; 640x480 16色プラナーモード
        int 0x10

        mov ax, 0x02_05 ; Graphics Mode, Write Mode 2
        call set_mode

main_loop:
    xor bp, bp
    mov bx, MARGIN_TOP_PX

draw_row:
    xor si, si
    mov di, MARGIN_LEFT_PX

draw_block:
    push bx
    mov ax, 0xffff
    mov cx, BLOCK_HEIGHT
    push bp
    shl bp, ilog2e(BLOCK_COUNT_X)
    cmp byte [block_flags + si + bp], 0 ; TODO: bit-field (64byte -> 8byte)
    jne .loop_init

    xor ax, ax

    .loop_init:
        pop bp
    .loop:
        push bx
        push di

        call xy2addr

        mov dx, [es:di]
        mov word [es:di], ax
        pop di
        pop bx

        inc bx
        loop .loop

    .next_block:
        pop bx
        add di, BLOCK_WIDTH_PX + BLOCK_SPACE_PX
        inc si ; x
        cmp si, BLOCK_COUNT_X
        jl draw_block

        add bx, BLOCK_HEIGHT + BLOCK_SPACE_PX
        inc bp ; y
        cmp bp, BLOCK_COUNT_Y
        jl draw_row

    movzx cx, byte [paddle_x]

erase_ball:
    mov di, word [ball_x]
    mov bx, word [ball_y]
    call xy2addr

    mov cx, BALL_HEIGHT
    .loop:
        mov al, byte [es:di]
        mov byte [es:di], 0
        add di, DISPLAY_WIDTH_BYTES
        loop .loop

erase_paddle:
    movzx di, byte [old_paddle_x]
    xor ax, ax
    call draw_paddle

    movzx di, byte [paddle_x]
    mov ax, 0xFFFF
    call draw_paddle
    movzx cx, byte [paddle_x]


update_ball:
    mov al, byte [ball_vx]
    movsx ax, al
    add word [ball_x], ax

    mov al, byte [ball_vy]
    movsx ax, al
    add word [ball_y], ax

check_hit:

    .top:
        mov ax, word [ball_y]
        test ax, ax
        jge .right
        neg byte [ball_vy]
    .right:
        mov ax, word [ball_x]
        cmp ax, PADDLE_X_MAX
        jle .left
        neg byte [ball_vx]
    .left:
        test ax, ax
        jnz .hit
        neg byte [ball_vx]
    .hit:
        mov ax, word [ball_y]
        cmp ax, PADDLE_Y - PADDLE_HEIGHT
        jl .no_hit

        mov ax, word [ball_x]
        movzx bx, byte [paddle_x]

        cmp ax, bx
        jl .no_hit
        add bx, 32
        cmp ax, bx
        jge .no_hit

        neg byte [ball_vy]

    .no_hit:
        xor bx, bx

    .block_loop:
        cmp byte [block_flags + bx], 0
        je .next_block

        mov ax, bx
        xor dx, dx
        mov cx, BLOCK_COUNT_X
        div cx

        ; X = MARGIN_LEFT_PX + dx * 24
        mov si, dx
        imul si, 24
        add si, MARGIN_LEFT_PX

        ; Y = MARGIN_TOP_PX + ax * 16
        mov di, ax
        imul di, 16
        add di, MARGIN_TOP_PX

        mov ax, word [ball_x]
        mov dx, word [ball_y]

        cmp ax, si
        jl .next_block
        mov cx, si
        add cx, 16
        cmp ax, cx
        jge .next_block

        cmp dx, di
        jl .next_block
        mov cx, di
        add cx, 8
        cmp dx, cx
        jge .next_block

    .block_hit:
        mov byte [block_flags + bx], 0
        neg byte [ball_vy]
        jmp .finalize

    .next_block:
        inc bx
        cmp bx, BLOCK_COUNT_X * BLOCK_COUNT_Y
        jl .block_loop

    .finalize:

draw_ball:
    mov di, word [ball_x]
    mov bx, word [ball_y]
    cmp bx, PADDLE_Y + 50
    js .continue
    mov word [ball_y], BALL_Y_INIT
    .continue:
        call xy2addr

    mov cx, BALL_HEIGHT
    .loop:
        mov byte [es:di], 0xFF
        add di, DISPLAY_WIDTH_BYTES
        loop .loop


wait_key:
    mov ah, 1 ; no-blocking mode
    int 0x16
    jz .sleep ; zf=0 if key pending, zf=1 if no key

    movzx cx, byte [paddle_x]
    mov dx, PADDLE_MOVE_PX
    cmp ah, 0x4b
    je .left
    cmp ah, 0x4d
    je .right
    jmp .clear_key

    .left:
        mov ax, cx
        sub ax, PADDLE_MOVE_PX
        js .no_move
        neg dx
        jmp .calc

    .right:
        mov ax, cx
        cmp ax, PADDLE_X_MAX - PADDLE_MOVE_PX
        jns .no_move

    .calc:
        mov byte [old_paddle_x], cl
        add byte [paddle_x], dl
    .no_move:
        xor dx, dx
    .clear_key:
        xor ah, ah
        int 0x16

    .sleep:
        xor cx, cx
        mov dx, 1_000_000/FPS ; マイクロ秒
        mov ah, 0x86
        int 0x15

    jmp main_loop

draw_paddle:
    push bx
    push di

    mov bx, PADDLE_Y
    call xy2addr

    mov cx, PADDLE_HEIGHT
    .width:
        mov dx, [es:di]
        mov dx, [es:di+2]
        mov word [es:di], ax
        mov word [es:di+2], ax

        add di, DISPLAY_WIDTH_BYTES
        loop .width

    pop di
    pop bx
    ret

xy2addr:
    ; DISPLAY_WIDTH_BYTES * Y + X / PLANAR_PX_PER_BYTE
    imul bx, DISPLAY_WIDTH_BYTES
    shr di, ilog2e(PLANAR_PX_PER_BYTE)
    add di, bx
    ret

set_mode:
    mov dx, 0x3ce
    out dx, ax
    ret

ball_x dw BALL_X_INIT
ball_y dw BALL_Y_INIT
ball_vx db -2
ball_vy db 2
old_paddle_x db PADDLE_X
paddle_x db PADDLE_X
block_flags:

times 510-($-$$) db 0
db 0x55, 0xaa
