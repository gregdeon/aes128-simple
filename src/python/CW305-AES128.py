from chipwhisperer.capture.targets.CW305 import CW305
import time

# Our AES-128 key and text
key = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 
       0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f]
plaintext = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
             0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]
			 
# The filepath of the bitstream generated by Vivado
filename = r"C:\Users\greg\Documents\Vivado\aes128_simple\aes128_simple.runs\impl_1\cw305_top.bit"

# Useful USB addresses on the FPGA
addr_cipher = 0x200 # 128 bit ciphertext
addr_trig   = 0x440	# Write 0x01 to trigger AES computation
addr_key    = 0x500	# 128 bit key
addr_plain  = 0x600	# 128 bit plaintext


# Connect to our board and load our bitstream onto it
cw = CW305()
cw.con(bsfile=filename, force = True)

# Load the inputs into the board
# Note: fpga_write() writes the lowest byte first (little-endian style)
#       so we have to communicate our key/plaintext backwards
cw.fpga_write(addr_key, key[::-1])
cw.fpga_write(addr_plain, plaintext[::-1])

# Trigger it and let it run
cw.fpga_write(addr_trig, [1])
time.sleep(0.5)

# Gobble up the result
# See above for note on backwards read
ciphertext = cw.fpga_read(addr_cipher, 16)[::-1]

''' Prints:
plain:  00 11 22 33 44 55 66 77 88 99 AA BB CC DD EE FF
key:    00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
cipher: 69 C4 E0 D8 6A 7B 04 30 D8 CD B7 80 70 B4 C5 5A
'''
print "plain:  " + " ".join(["%02X"%c for c in plaintext])
print "key:    " + " ".join(["%02X"%c for c in key])
print "cipher: " + " ".join(["%02X"%c for c in ciphertext])
