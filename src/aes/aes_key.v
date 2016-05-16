`timescale 1ns / 1ps

// Potential improvements:
// - Main loop is 3 states (load temp, reload transformed temp, apply temp)
//   It could probably be 2 (load temp, apply temp (or transformed temp)
//   Key scheduler would run in 2/3 of the time


module aes_key(
    input  wire [ 127:0] key,   // The 128-bit key
    output reg  [1407:0] w,     // The 44 word key schedule
    input  wire trigger,        // Set high to start key scheduling
    output reg  done,           // Goes high when done computation. Stays high until trigger
    input  wire clk,            // 
    input  wire reset           // Reset the state to "idle"
    );

// State machine setup
localparam STATE_idle  = 3'd0,
           STATE_start = 3'd1,
           STATE_temp  = 3'd2,
           STATE_sub   = 3'd3,
           STATE_xor   = 3'd4,
           STATE_done  = 3'd5,
           STATE_empty_1 = 3'd6,
           STATE_empty_2 = 3'd7;

reg [2:0] currentState;
reg [2:0] nextState;
reg [6:0] nextWord;


// Intermediate results
reg [31:0] temp;
wire [31:0] temp_sub;
wire [31:0] temp_rot;
wire [31:0] temp_rcon;

s_box my_s_box(
    .in(temp),
    .out(temp_sub)
    );

assign temp_rot = (temp_sub << 8) | (temp_sub >> 24);

wire [31:0] rcon [10:0];
assign rcon[0]  = 32'h00000000;
assign rcon[1]  = 32'h01000000;
assign rcon[2]  = 32'h02000000;
assign rcon[3]  = 32'h04000000;
assign rcon[4]  = 32'h08000000;
assign rcon[5]  = 32'h10000000;
assign rcon[6]  = 32'h20000000;
assign rcon[7]  = 32'h40000000;
assign rcon[8]  = 32'h80000000;
assign rcon[9]  = 32'h1b000000;
assign rcon[10] = 32'h36000000;
assign temp_rcon = temp_rot ^ rcon[nextWord/4];


// Act on current state
always @ (posedge clk)
begin
    case(currentState)
        STATE_idle: begin
            // Do nothing -- we're idle, remember?
            done <= 0;
        end
        STATE_start: begin
            // Startup routine
            nextWord <= 4;
            done <= 0;
        
            // Load the first four words
            w[ 31: 0] <= key[127:96];
            w[ 63:32] <= key[ 95:64];
            w[ 95:64] <= key[ 63:32];
            w[127:96] <= key[ 31: 0];
        end
        STATE_temp: begin
            // Load the temp register with a word
            temp <= w[32*(nextWord-1) +: 32];
        end
        STATE_sub: begin
            // Perform the sub/rot/rcon transformation
            // This is all hard-wired, so just grab the result
            temp <= temp_rcon;
        end
        STATE_xor: begin
            // Use our temp value to update the key schedule
            w[32*nextWord +: 32] <= w[32*(nextWord-4) +: 32] ^ temp;
            
            // Move onto the next word
            nextWord <= nextWord + 1;
        end
        STATE_done: begin
            // Tell the world we're done
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
            // Start: always move to the main loop
            nextState = STATE_temp;
        end
        STATE_temp: begin
            // Decide if we should use a substitution
            if(nextWord % 4 == 0)
                nextState = STATE_sub;
            else
                nextState = STATE_xor;
        end
        STATE_sub: begin
            // After using the s-box, always apply the results
            nextState = STATE_xor;
        end
        STATE_xor: begin
            // Go back into the loop unless we're done
            if (nextWord >= 43) // 44 words, so the last one is numbered 43
                nextState = STATE_done;
            else
                nextState = STATE_temp;
        end
        STATE_done: begin
            // Done: go back to sleep
            nextState = STATE_idle;
        end
        default: begin
            // If we were in an undefined state, give up
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
