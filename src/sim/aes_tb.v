// aes_tb.v
// A testbench for the module in aes.v

`timescale 1ns / 1ps

// Module has no inputs or outputs
module aes_tb();

// Inputs and outputs for AES module
wire [127:0] key;
wire [127:0] plaintext;
wire [127:0] ciphertext;

reg trigger;
wire done;
reg clk;
reg reset;

// Set key and plaintext inputs to constants
assign key = 128'h000102030405060708090a0b0c0d0e0f;
assign plaintext = 128'h00112233445566778899aabbccddeeff;
//assign key = 128'h2b7e151628aed2a6abf7158809cf4f3c;
//assign plaintext = 128'h3243f6a8885a308d313198a2e0370734;

// Module under test
aes my_aes(
    .key(key),
    .plaintext(plaintext),
    .ciphertext(ciphertext),
    
    .trigger(trigger),
    .done(done),
    .clk(clk),
    .reset(reset)
    );
    
// Turn on the trigger, then turn it back off
initial begin
    trigger = 1;
    reset = 0;
    clk = 0;
    
    #100;
    trigger = 0;
end

// Clock speed: 4 ns period
always begin
    #2 clk = ~clk;
end



endmodule
