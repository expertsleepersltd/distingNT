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

filename = sys.argv[1]

docs = [ filename.replace( '.hex', '' ), "Pot 1", "Pot 2", "Pot 3", "" ]
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

with open( filename, 'r' ) as F:
	lines = F.readlines()
	lines = [ '\"' + l.strip() + '\"\n' for l in lines ]
	print( '{\n"kind": "disting NT 3pot",' )
	print( '"version": 1,' )
	print( '"name": "' + docs[0] + '",' )
	print( '"pot1": "' + docs[1] + '",' )
	print( '"pot2": "' + docs[2] + '",' )
	print( '"pot3": "' + docs[3] + '",' )
	print( '"description": "' + docs[4] + '",' )
	print( '"code":[' )
	print( ','.join( lines ) )
	print( ']' )
	
	print( '}' )
