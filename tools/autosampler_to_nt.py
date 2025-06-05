"""
autosampler_to_nt.py

Converts the output files of Logic Pro's autosampler into a format suitable
for the Disting NT.

Usage: Open a Terminal. cd to the folder containing the files. Copy the script into
the folder. Enter the command:

python3 autosampler_to_nt.py

Then copy the folder to the disting's MicroSD card.
Delete the .aif files if you wish, but the disting will ignore them anyway.
"""

# http://pysoundfile.readthedocs.org/
# 
# python3 -m pip install soundfile
# python3 -m pip install tinytag
#

from tinytag import TinyTag
import soundfile as sf

import glob

subtitutions = []

files = glob.glob( "*.aif" )
files.sort()

newfiles = [ file.replace( '.aif', '.wav' ).replace( '_', ' ' ).replace( '-', '_' ) for file in files ]

notes = [ '_'.join( s.split('_')[:-2] ) for s in newfiles ]
velocities = set(())
for i in range( len( newfiles ) ):
	if ( notes[i] == notes[0] ):
		velocities.add( newfiles[i].split('_')[2] )

velocities = [ int( v[1:] ) for v in velocities ]
velocities.sort()
v_replace = {}
for i in range( len( velocities ) ):
	v_replace[ '_V' + str(velocities[i]) + '_' ] = '_V' + str( i+1 ) + '_'

roots = [ '_'.join( s.split('_')[:-1] ) for s in newfiles ]
robins = [ s.split('_')[ -1 ].split( '.' )[0] for s in newfiles ]

root = ''
rr = 1
for i in range( len( newfiles ) ):
	if ( roots[i] != root ):
		root = roots[i]
		rr = 1
	newfiles[i] = newfiles[i].replace( robins[i], 'RR' + str(rr) )
	for k, v in v_replace.items():
		newfiles[i] = newfiles[i].replace( k, v )
	rr += 1

for file, newfile in zip( files, newfiles ):
	print( file + "\t-> " + newfile )

	tag: TinyTag = TinyTag.get( file )
	# print( "bitdepth = {0}".format(tag.bitdepth) ) # Debug
	if   ( tag.bitdepth >= 32 ): fmt_subtype = 'FLOAT'
	elif ( tag.bitdepth >= 24 ): fmt_subtype = 'PCM_24'
	elif ( tag.bitdepth <=  8 ): fmt_subtype = 'PCM_U8'
	else: fmt_subtype = 'PCM_16'

	if not sf.check_format( 'WAV', fmt_subtype ):
		# if we cannot retain original files' bit depth, force to 24 bit or 16 bit
		fmt_subtype = 'PCM_24'
	# print( "{0} subtype".format(fmt_subtype) )  # Debug

	# fmt_subtype = sf.subtype # NOTE: no direct method in soundfile module, use TinyTag
	# data is read as 'float64' by default in soundfile module
	data, sr = sf.read( file )
	sf.write( newfile, data, sr, fmt_subtype )
