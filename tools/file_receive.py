'''
MIT License

Copyright (c) 2025 Expert Sleepers Ltd

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
'''

'''
Requirements:
pip install mido
pip install python-rtmidi

Example usage:
python file_receive.py 0 "/presets/Aleatoric Piano.json"
or
python file_receive.py 0 "/presets/Aleatoric Piano.json" "local filename.json"
'''

import mido
import sys

kOpDownload = 2

def addCheckSumAndSend( outPort, arr ):
	sum = 0
	for i in range( 7, len(arr) ):
		sum += arr[i]
	sum = ( -sum ) & 0x7f
	arr.append( sum )
	arr.append( 0xF7 )
	m = mido.Message.from_bytes( arr )
	outPort.send( m )

argc = len(sys.argv)
sysExId = int(sys.argv[1])
nt_path = sys.argv[2]

outPort = mido.open_output( 'disting NT' )
inPort = mido.open_input( 'disting NT' )

arr = [ 0xF0, 0x00, 0x21, 0x27, 0x6D, sysExId, 0x7A, kOpDownload ]
for i in range( len(nt_path) ):
	arr.append( ord( nt_path[ i ] ) )

addCheckSumAndSend( outPort, arr )

msg = inPort.receive()
data = msg.bytes()
if data[ 0 : 9 ] != [ 0xF0, 0x00, 0x21, 0x27, 0x6D, sysExId, 0x7A, 0, kOpDownload ]:
	raise Exception( 'unexpected response' )

b = []
data = data[ 9 : -1 ]
size = len(data) >> 1
for i in range( size ):
	b.append( ( data[2*i] << 4 ) | data[2*i+1] )
b = bytes(b)

if argc < 4:
	sys.stdout.buffer.write( b )
else:
	local_path = sys.argv[3]
	with open( local_path, 'wb' ) as F:
		F.write( b )
