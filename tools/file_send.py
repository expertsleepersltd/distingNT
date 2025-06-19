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
python file_send.py 0 "/presets/filename.json" "filename.json"
'''

import mido
import sys

kOpUpload = 4

def addCheckSumAndSend( outPort, arr ):
	sum = 0
	for i in range( 7, len(arr) ):
		sum += arr[i]
	sum = ( -sum ) & 0x7f
	arr.append( sum )
	arr.append( 0xF7 )
	m = mido.Message.from_bytes( arr )
	outPort.send( m )

sysExId = int(sys.argv[1])
nt_path = sys.argv[2]
local_path = sys.argv[3]

outPort = mido.open_output( 'disting NT' )
inPort = mido.open_input( 'disting NT' )

ack = mido.Message.from_bytes( [ 0xF0, 0x00, 0x21, 0x27, 0x6D, sysExId, 0x7A, 0, kOpUpload, 0xF7 ] )

with open( local_path, 'rb' ) as F:
	data = F.read()
	
size = len(data)
uploadPos = 0

while True:
	count = min( 512, size - uploadPos )
	if count == 0:
		break

	createAlways = int( uploadPos == 0 )

	arr = [ 0xF0, 0x00, 0x21, 0x27, 0x6D, sysExId, 0x7A, kOpUpload ]
	for i in range( len(nt_path) ):
		arr.append( ord( nt_path[ i ] ) )
	arr.append( 0 )
	arr.append( createAlways )
	arr.append( 0 )# ( uploadPos >> 63 ) & 0x7f )
	arr.append( 0 )# ( uploadPos >> 56 ) & 0x7f )
	arr.append( 0 )# ( uploadPos >> 49 ) & 0x7f )
	arr.append( 0 )# ( uploadPos >> 42 ) & 0x7f )
	arr.append( 0 )# ( uploadPos >> 35 ) & 0x7f )
	arr.append( ( uploadPos >> 28 ) & 0x0f )# ( uploadPos >> 28 ) & 0x7f )
	arr.append( ( uploadPos >> 21 ) & 0x7f )
	arr.append( ( uploadPos >> 14 ) & 0x7f )
	arr.append( ( uploadPos >> 7 ) & 0x7f )
	arr.append( ( uploadPos >> 0 ) & 0x7f )
	arr.append( 0 )# ( count >> 63 ) & 0x7f )
	arr.append( 0 )# ( count >> 56 ) & 0x7f )
	arr.append( 0 )# ( count >> 49 ) & 0x7f )
	arr.append( 0 )# ( count >> 42 ) & 0x7f )
	arr.append( 0 )# ( count >> 35 ) & 0x7f )
	arr.append( ( count >> 28 ) & 0x0f )# ( count >> 28 ) & 0x7f )
	arr.append( ( count >> 21 ) & 0x7f )
	arr.append( ( count >> 14 ) & 0x7f )
	arr.append( ( count >> 7 ) & 0x7f )
	arr.append( ( count >> 0 ) & 0x7f )
	for j in range(count):
		b = data[ uploadPos + j ]
		arr.append( ( b >> 4 ) & 0xf )
		arr.append( ( b ) & 0xf )
	addCheckSumAndSend( outPort, arr )
	uploadPos += count
	
	msg = inPort.receive()
	if msg != ack:
		print( "ERROR - unexpected response:" )
		print( msg )
		print( "wanted:" )
		print( ack )
		break;
