#!/usr/bin/env python3

#
# Send a raw RGB image in RGB 5/6/5 bits encoding to a server
#
# See: matrix.lua
#
# Usage:
#
# parameter 1:      the image data file
# parameter 2:      the width in pixels of the image data
# parameter 3 4:    the x y position on the display
# parameter 5:      the server host
# parameter 6:      the port number (12345)
#

import socket
import array
import sys

display="192.168.0.206"
port=12345

file=""
width=220
x=0
y=0

l= len(sys.argv)
if l >= 2:
    file= sys.argv[1]
else:
    print("missing rgb file argument\n");
    sys.exit(0)

if l >= 3:
    width= int(sys.argv[2])
if l >= 4:
    x= int(sys.argv[3])
    y= int(sys.argv[4])
if l >= 6:
    display= sys.argv[5]
if l >= 7:
    port= int(sys.argv[6])


s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

s.connect((display, port))

with open(file, 'rb') as imgfile:
    data= imgfile.read()

ib= bytearray(int(len(data) * 2 / 3))
cmd= "rgb565 " + str(len(ib)) + " " + str(width) + " " + str(x) + " " + str(y) + "\n"

b= bytearray(len(cmd))
for idx,c in enumerate(cmd) :
    b[idx]= ord(c)

s.send(b)

i= 0
for idx,c in enumerate(data) :
    if idx % 3 == 0:
        red= c
    elif idx % 3 == 1:
        green= c
    else:
        blue= c
        ib[i]= ((red >> 3) << 3) | (green >> 5)
        i= i+1
        ib[i]= (((green >> 2) & 0x7) << 5) | (blue >> 3)
        i= i+1

s.send(ib)
