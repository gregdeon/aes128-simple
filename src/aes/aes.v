// aes.v
// The main interface for the AES-128 implementation


`timescale 1ns / 1ps

module aes(
    input wire [127:0] key,
    input wire [127:0] plaintext,
    output wire [127:0] ciphertext,
    input wire trigger,
    output reg done,
    input wire clk,
    input wire reset
    );
    
// State machine setup
// Procedure is:
// - Idle: wait until we're asked to do work
// - Key_Start: tell the key expansion module to do its job
// - Key: wait for the key expansion module to finish
// - Crypt_Start: tell the encryption module to work
// - Crypt: wait for the encryption to finish
// - Done: signal that we're finished
// 8 states = 3 bits
localparam STATE_idle        = 3'd0,
           STATE_key_start   = 3'd1,
           STATE_key         = 3'd2,
           STATE_crypt_start = 3'd3,
           STATE_crypt       = 3'd4,
           STATE_done        = 3'd5,
           STATE_empty_1     = 3'd6,
           STATE_empty_2     = 3'd7;
           
reg [2:0] currentState;
reg [2:0] nextState;

// Internals
wire [1407:0] w;    // Key schedule (44 words)
reg trigger_key;	// Control for the key module
wire done_key;		//
reg trigger_crypt;	// Control for the crypto module
wire done_crypt;	//

// Key expansion module
aes_key my_aes_key(
    .key(key),
    .w(w),
    .trigger(trigger_key),
    .done(done_key),
    .clk(clk),
    .reset(reset)
    );
	
// Encryption module
aes_crypt my_aes_crypt(
    .w(w),
    .in(plaintext),
    .out(ciphertext),
    .trigger(trigger_crypt),
    .done(done_crypt),
    .clk(clk),
    .reset(reset)
    );

	
// Actions for each state
always @(posedge clk)
begin
    case(currentState)
        STATE_idle: begin
            // Zzzzzz
            // Make sure everything is off (remember, we reset to here)
            trigger_key <= 0;
            trigger_crypt <= 0;
            done <= 1;
        end
        STATE_key_start: begin
            // Tell the key scheduler to start its job
            trigger_key <= 1;
            done <= 0;
        end
        STATE_key: begin
            // Don't tell the key scheduler to restart
            trigger_key <= 0;
        end
        STATE_crypt_start: begin
            // Tell the crypto module to work
            trigger_crypt <= 1;
        end
        STATE_crypt: begin
            // Stop asking it to start
            trigger_crypt <= 0;
        end
        STATE_done: begin
            // Tell the world we're finished
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
                nextState = STATE_key_start;
        end
        STATE_key_start: begin
            // Starting up the key scheduler - let it work
            nextState = STATE_key;
        end
        STATE_key: begin
            // Working on the key schedule: wait until it's done
            if(done_key)
                nextState = STATE_crypt_start;
        end
        STATE_crypt_start: begin
            // Starting up the encrypter - let it go
            nextState = STATE_crypt;
        end
        STATE_crypt: begin
            // Working on encrypting: wait until it's done
            if(done_crypt)
                nextState = STATE_done;
        end
        STATE_done: begin
            // Go back to sleep
            nextState = STATE_idle;
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
