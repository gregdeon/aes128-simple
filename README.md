# aes128-simple
A simple, barebones AES-128 encryption implementation in Verilog. 

## What is this?
This project is intended to be a barebones, simple-as-possible implementation of AES-128 encryption in Verilog. 

The source in this repo has four components:
* `src/aes/`: The AES-128 implementation. The module `aes.v` is the top-level module that can be instantiated in other Verilog code.
* `src/sim/`: A testbench for simulating the AES module. 
* `src/cw305/`: A USB driver for the ChipWhisperer CW305 Artix-7 FPGA target board. This code connects the AES module to the USB interface on the CW305 board so it can be controlled from a computer.
* `src/python/`: A Python script for uploading code onto the CW305 board and triggering the FPGA code. This script uses the ChipWhisperer libraries.

Check out http://chipwhisperer.com for more information about this board and the code libraries that are involved.

## Results
Vivado's Project Summary after implementation includes the following table:

```
Resource | Utilization | Available | Utilization %
---------|-------------|-----------|---------------
LUT      | 4470        | 20800     | 21.49
FF       | 2033        | 41600     | 4.89
IO       | 35          | 170       | 20.59
BUFG     | 3           | 32        | 9.38
```

Running the Python script with the default key and plaintext prints the output
```
plain:  00 11 22 33 44 55 66 77 88 99 AA BB CC DD EE FF
key:    00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
cipher: 69 C4 E0 D8 6A 7B 04 30 D8 CD B7 80 70 B4 C5 5A
```
This is the AES-128 example given in the original AES publication (http://csrc.nist.gov/publications/fips/fips197/fips-197.pdf, appendix C.1).

## Credit
Thanks for Colin O'Flynn (NewAE Technology) for ChipWhisperer and for his help with the USB module.
