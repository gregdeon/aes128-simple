// aes_crypt.v
// The module used to perform AES-128 encryption on the plaintext.
// Relies on the aes_key module to generate a key schedule (w) first

`timescale 1ns / 1ps

module aes_crypt(
    input wire [1407:0] w,
    input wire [127:0] in,
    output reg [127:0] out,
    
    input wire trigger,
    output reg done,
    input wire clk,
    input wire reset
    );

// Local variables
genvar i;
genvar j;

    
// State machine
// - Idle: wait for the trigger
// - Start: Load the input plaintext into the state matrix
// - Sub: perform the SubBytes() routine
// - Shift: perform the ShiftRows() routine
// - Mix: perform the MixColumns() routine
// - Add: perform the AddRoundKey() routine
// - Done: signal that we're finished
localparam STATE_idle  = 3'd0,
           STATE_start = 3'd1,
           STATE_sub   = 3'd2,
           STATE_shift = 3'd3,
           STATE_mix   = 3'd4,
           STATE_add   = 3'd5,
           STATE_done  = 3'd6,
           STATE_empty = 3'd7;
           
reg [2:0] currentState;
reg [2:0] nextState;
reg [3:0] roundNum;


// Internals
reg [31:0] state [3:0];      // state[0] is column with x=0, state[1] is x=1...

// SubBytes()
// Use 4 s-boxes (Substitute one word each, so 1 s-box for each column)
wire [31:0] state_subbytes [3:0];
s_box s_box_0(
    .in(state[0]),
    .out(state_subbytes[0])
);
s_box s_box_1(
    .in(state[1]),
    .out(state_subbytes[1])
);
s_box s_box_2(
    .in(state[2]),
    .out(state_subbytes[2])
);
s_box s_box_3(
    .in(state[3]),
    .out(state_subbytes[3])
);


// ShiftRows()
// Hard-wire the ShiftRows() output
wire [31:0] state_shiftrows [3:0];
for (i = 0; i < 4; i=i+1) begin
    assign state_shiftrows[i][31:24] = state[(i+0)%4][31:24];
    assign state_shiftrows[i][23:16] = state[(i+3)%4][23:16];
    assign state_shiftrows[i][15: 8] = state[(i+2)%4][15: 8];
    assign state_shiftrows[i][ 7: 0] = state[(i+1)%4][7:0];
end

// MixColumns()
// Hard-wire the MixColumns() output
wire [31:0] state_mixcolumns [3:0];
function [7:0] xtime;
    input [7:0] x;
    xtime = x[7] ? ((x << 1) ^ 8'h1b) : (x << 1);
endfunction
for(i = 0; i < 4; i=i+1) begin: for1
    for(j = 0; j < 4; j=j+1)
    begin
        assign state_mixcolumns[i][8*j +: 8]
            = xtime(state[i][8*j +: 8])
              ^ xtime(state[i][8*(j+3)%32 +: 8])
              ^ state[i][8*(j+3)%32 +: 8]
              ^ state[i][8*(j+2)%32 +: 8]
              ^ state[i][8*(j+1)%32 +: 8];
    end
end

// AddRoundKey()
wire [31:0] state_addroundkey [3:0];
for(i = 0; i < 4; i=i+1)
begin
    assign state_addroundkey[i] = state[i] ^ w[128*roundNum + 32*(3-i) +: 32];
end


// Actions in each state
always @(posedge clk)
begin
    case(currentState)
        STATE_idle: begin
            // Idle: make sure we're doing nothing
            done <= 0;
        end
        STATE_start: begin
            // Set up things
            done <= 0;
            roundNum <= 0;
            
            state[0] <= in[ 31: 0];
            state[1] <= in[ 63:32];
            state[2] <= in[ 95:64];
            state[3] <= in[127:96];
        end
        STATE_sub: begin
            // SubBytes()
            state[0] <= state_subbytes[0];
            state[1] <= state_subbytes[1];
            state[2] <= state_subbytes[2];
            state[3] <= state_subbytes[3];
        end
        STATE_shift: begin
            // ShiftRows()
            state[0] <= state_shiftrows[0];
            state[1] <= state_shiftrows[1];
            state[2] <= state_shiftrows[2];
            state[3] <= state_shiftrows[3];
        end
        STATE_mix: begin
            // MixColumns()
            state[0] <= state_mixcolumns[0];
            state[1] <= state_mixcolumns[1];
            state[2] <= state_mixcolumns[2];
            state[3] <= state_mixcolumns[3];
        end
        STATE_add: begin
            // AddRoundKey()
            state[0] <= state_addroundkey[0];
            state[1] <= state_addroundkey[1];
            state[2] <= state_addroundkey[2];
            state[3] <= state_addroundkey[3];
            
            // Also, done this round -- move on
            roundNum <= roundNum + 1;
        end
        STATE_done: begin
            // Output = state            
            out[ 31: 0] <= state[0];
            out[ 63:32] <= state[1];
            out[ 95:64] <= state[2];
            out[127:96] <= state[3];
            
            done <= 1;
        end
    endcase
end

// State transition logic
always @(*)
begin
    nextState = currentState;
    case(currentState)
        STATE_idle: begin
            // Idle: wait for a trigger
            if(trigger)
                nextState = STATE_start;
        end
        STATE_start: begin
            // Starting: add the round key first
            nextState = STATE_add;
        end
        STATE_sub: begin
            // After SubBytes, always ShiftRows()
            nextState = STATE_shift;
        end
        STATE_shift: begin
            // If we're on the final round, skip to AddRoundKey
            if(roundNum >= 10)
                nextState = STATE_add;
            else
                nextState = STATE_mix;
        end
        STATE_mix: begin
            // After MixColumns, always AddRoundKey
            nextState = STATE_add;
        end
        STATE_add: begin
            // If we're on the final round, we're done!
            if(roundNum >= 10)
                nextState = STATE_done;
            else
                nextState = STATE_sub;
        end
        STATE_done: begin
            // We're done, so go back to sleep
            nextState = STATE_done;
        end
        default: begin
            // We're in a bad place; reset
            nextState = STATE_idle;
        end
    endcase
end

// Change state at each clock edge
always @ (posedge clk)
begin
    if(reset)
        currentState <= STATE_idle;
    else
        currentState <= nextState;
end

endmodule
