; CONSTANTS
    ; addresses
.define CENTER_ADDRESS $0288
.define VSYNC_COUNTER $00
.define OLD_VSYNC_COUNTER $01
.define PLAYER_HEAD $10
.define PLAYER_BODY $11
.define PLAYER_LENGTH $02
.define ACC_TEMPORARY_ADDRESS $03
.define VIDEO_OUT $0200
.define JOYSTICK $4000
.define DIRECTION $04
.define APPLE_POSITION $05
.define RANDOM_SEED $0F
    ; values
.define FPS #15
.define START_LENGTH #01
.define PLAYER_COLOR #$F
.define BACKGROUND_COLOR #0
.define APPLE_COLOR #1
.define K_UP #$01
.define K_DOWN #$02
.define K_LEFT #$04
.define K_RIGHT #$08
.define MOVE_VERTICAL #$10
.define MOVE_HORIZONTAL #$01
.define CENTER_VALUE #$88

; basic setup for the 6502
.org $8000
LDX #$FF
TXS
start:
    JSR init
    JSR loop
init:
    LDA PLAYER_COLOR
    STA CENTER_ADDRESS
    LDA CENTER_VALUE
    STA PLAYER_HEAD
    LDA START_LENGTH
    STA PLAYER_LENGTH
    init_loop:
        JSR count_seed
        JSR get_direction
        JSR draw_snake
        LDA DIRECTION
        CMP #$00
        BEQ init_loop
        JSR set_new_apple
        RTS
loop:
    JSR count_seed
    JSR check_collisions
    JSR get_direction
    JSR check_do_update
    JSR do_body
    JSR do_movement
    JSR draw
    JMP loop
skip_cycle:
    ; pop this reference from stack (saves space in stack)
    PLA 
    PLP
    JMP loop
exit_subroutine:
    RTS
count_seed:
    INC RANDOM_SEED
    RTS
check_collisions:
    check_apple_collision:
        LDA APPLE_POSITION
        CMP PLAYER_HEAD
        BNE check_snake_collision
        INC PLAYER_LENGTH
        JSR set_new_apple
    check_snake_collision:
        LDA PLAYER_LENGTH
        CMP #$05
        BMI exit_subroutine
        LDX #$03
        snake_loop:
            LDA PLAYER_HEAD, X
            CMP PLAYER_HEAD
            BEQ collision_self
            INX
            CPX PLAYER_LENGTH
            BNE snake_loop
    RTS
collision_self:
    JMP game_over
get_direction:
    LDA JOYSTICK
    CMP #$00 ; no movement protection
    BEQ exit_subroutine
    CMP DIRECTION
    BNE change_direction
    RTS
change_direction:
    TAX
    LDA DIRECTION
    CMP K_UP
    BEQ k_up
    CMP K_DOWN
    BEQ k_down
    CMP K_LEFT
    BEQ k_left
    CMP K_RIGHT
    BEQ k_right
    STX DIRECTION
    RTS
k_up:
    CPX K_DOWN
    BEQ exit_subroutine
    STX DIRECTION
    RTS
k_down:
    CPX K_UP
    BEQ exit_subroutine
    STX DIRECTION
    RTS
k_left:
    CPX K_RIGHT
    BEQ exit_subroutine
    STX DIRECTION
    RTS
k_right:
    CPX K_LEFT
    BEQ exit_subroutine
    STX DIRECTION
    RTS
check_do_update:
    LDA VSYNC_COUNTER
    CMP OLD_VSYNC_COUNTER
    BEQ skip_cycle
    STA OLD_VSYNC_COUNTER
    CMP FPS ; this will update only one time per second
    BNE skip_cycle
    RTS
do_body:
    LDY PLAYER_HEAD
    LDA PLAYER_LENGTH
    CMP START_LENGTH
    BEQ exit_subroutine
    ; set offset to last bodypart (len - 1 as always)
    LDX PLAYER_LENGTH
    DEX
    DEX
    LDY PLAYER_BODY, X
follow_head:
    LDA PLAYER_HEAD, X ; acts as a pointer to the bodypart to follow, which is ahead
    STA PLAYER_BODY, X
    DEX
    BPL follow_head
    RTS
do_movement:
    LDA DIRECTION
    AND K_UP
    BNE move_up
    LDA DIRECTION
    AND K_DOWN
    BNE move_down
    LDA DIRECTION
    AND K_LEFT
    BNE move_left
    LDA DIRECTION
    AND K_RIGHT
    BNE move_right
    RTS
move_up:
    ; decrease by 0x001
    SEC ; sets the carry to avoid crossing to a different line
    LDA PLAYER_HEAD
    CMP #$10
    BMI collision_wall
    SBC MOVE_VERTICAL
    STA PLAYER_HEAD
    RTS
move_down:
    CLC
    LDA PLAYER_HEAD
    CMP #$F0
    BPL collision_wall
    CLC ; clears carry for the same reason as above
    LDA PLAYER_HEAD
    ADC MOVE_VERTICAL
    STA PLAYER_HEAD
    ; increase by 0x0010
    RTS
move_left:
    LDA PLAYER_HEAD
    LDX #0
    left_loop:
        CPX #4
        BEQ collision_wall
        SEC
        ROR A
        INX
        BCC left_loop
    ; decrease by 0x0001
    LDA PLAYER_HEAD
    SBC MOVE_HORIZONTAL
    STA PLAYER_HEAD
    RTS
move_right:
    LDA PLAYER_HEAD
    LDX #0
    right_loop:
        CPX #4
        BEQ collision_wall
        CLC
        ROR A
        INX
        BCS right_loop
    ; increase by 0x0001
    LDA PLAYER_HEAD
    ADC MOVE_HORIZONTAL
    STA PLAYER_HEAD
    RTS
collision_wall:
    JMP game_over
draw:
    LDA BACKGROUND_COLOR
    STA VIDEO_OUT, Y
    JSR draw_apple
    JSR draw_snake
    RTS
draw_apple:
    LDA DIRECTION
    CMP #0
    BEQ draw_snake
    LDA APPLE_COLOR
    LDY APPLE_POSITION
    STA VIDEO_OUT, Y
    RTS
draw_snake:
    LDA PLAYER_COLOR
    LDY PLAYER_HEAD
    STA VIDEO_OUT, Y
    RTS
get_random:
    LDA RANDOM_SEED
    ADC VSYNC_COUNTER
    LDX DIRECTION
    random_loop:
        ADC PLAYER_LENGTH
        DEX
        BNE random_loop
        RTS
set_new_apple:
    JSR get_random
    STA APPLE_POSITION
    RTS
nmi:
    ; cache accumulator value
    STA ACC_TEMPORARY_ADDRESS
    ; save old frame count
    LDA VSYNC_COUNTER
    STA OLD_VSYNC_COUNTER
    ; set the change in frame
    DEC VSYNC_COUNTER
    BEQ reset_vsync
    ; reset accumulator
    LDA ACC_TEMPORARY_ADDRESS
    RTI
reset_vsync:
    LDA FPS
    STA VSYNC_COUNTER
    ; reset accumulator
    LDA ACC_TEMPORARY_ADDRESS
    RTI
game_over:
    LDA #$00
    LDX #0
clear_page_zero:
    STA $00, X
    INX
    BNE clear_page_zero
clear_stack:
    STA $0100, X
    INX
    BNE clear_stack
clear_video_out:
    STA VIDEO_OUT, X
    INX
    BNE clear_video_out
JMP start
; ; sets the last values in the rom (interrupt ones) to start address
.goto $FFFA
.dw nmi ; non maskable
.dw start ; reset
.dw start ; interrupt
