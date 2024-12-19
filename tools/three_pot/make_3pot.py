'''
MIT License

Copyright (c) 2024 Expert Sleepers Ltd

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

import sys
from datetime import datetime, timezone
import subprocess
import os.path

filename = sys.argv[1]
include = sys.argv[2]

docs = [ os.path.basename( filename ).replace( '.hex', '' ), "Pot 1", "Pot 2", "Pot 3", "" ]

spnfile = filename.replace( '.hex', '.spn' )
try:
	with open( spnfile, 'r' ) as F:
		lines = F.readlines()
		lines = [ l.strip() for l in lines ]
		if lines[1].startswith( '; ' ):
			title = lines[1][2:].strip()
			if title != 'null':
				docs[0] = title
		for i in range(3):
			if lines[2+i].startswith( f'; Pot {i}: ' ):
				pot = lines[2+i][9:].strip()
				if len(pot) > 0:
					docs[1+i] = pot
		description = ''
		for i in range(2):
			if lines[5+i].startswith( '; ' ):
				description += lines[5+i][2:] + ' '
		docs[4] = description.strip()
except FileNotFoundError:
	pass

docfile = filename.replace( '.hex', '.txt' )
try:
	with open( docfile, 'r' ) as F:
		lines = F.readlines()
		lines = [ l.strip() for l in lines ]
		for i in range(4):
			if len(lines) > i:
				if len(lines[i]) > 0:
					docs[i] = lines[i]
		if len(lines) > 4:
			docs[4] = ' '.join( lines[4:] )
except FileNotFoundError:
	pass

docs = [ d.replace( '"', '\\"' ) for d in docs ]

def computeCodeSize( lines ):
	size = 0
	for line in lines:
		bits = line.split( ':' )
		if len(bits) < 2:
			continue
		data = bits[1]
		count = int( data[0:2], 16 )
		address = int( data[2:6], 16 )
		size = max( size, address + count - 1 )
	return size

toolchain = subprocess.run( 'arm-none-eabi-c++ --version', capture_output=True, shell=True, text=True ).stdout.split('\n')[0].strip()

abi = '0'
with open( os.path.join( include, 'three_pot_state.h' ), 'r' ) as F:
	lines = F.readlines()
	for line in lines:
		if line.startswith( '#define THREE_POT_ABI_VERSION' ):
			abi = line[29:].strip()
			break
	
with open( filename, 'r' ) as F:
	lines = F.readlines()
	size = computeCodeSize( lines )
	lines = [ '\"' + l.strip() + '\"\n' for l in lines ]
	print( '{\n"kind": "disting NT 3pot",' )
	print( '"version": 1,' )
	print( '"name": "' + docs[0] + '",' )
	print( '"pot1": "' + docs[1] + '",' )
	print( '"pot2": "' + docs[2] + '",' )
	print( '"pot3": "' + docs[3] + '",' )
	print( '"description": "' + docs[4] + '",' )
	print( f'"code_size": {size},' )
	print( '"build_date": "' + str( datetime.now( tz=timezone.utc ) ) + '",' )
	print( f'"toolchain": "{toolchain}",' )
	print( f'"abi_version": "{abi}",' )
	print( '"code":[' )
	print( ','.join( lines ) )
	print( ']' )
	
	print( '}' )
