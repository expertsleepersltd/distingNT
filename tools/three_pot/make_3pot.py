
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
