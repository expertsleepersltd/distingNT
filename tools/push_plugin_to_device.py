'''
MIT License

Copyright (c) 2025 Roger Arnett
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
Disting NT Firmware v1.13 or later (SYSEX command to rescan plug-ins added in v1.13)

pip install mido
pip install python-rtmidi

Example usage:
python push_plugin_to_device 0 "/local/plugin/path/plugin.o"
'''


import mido
import sys
from pathlib import PurePath

sysExId = int(sys.argv[1])
local_plugin_path = sys.argv[2]

nt_plugin_path = "/programs/plug-ins/" + PurePath(local_plugin_path).name

# this finds the first port that has "disting NT" in the name
# Windows port names can come back with a numeric suffix, i.e. "disting NT 5"
outPortName = [name for name in mido.get_output_names() if "disting NT" in name][0]
inPortName = [name for name in mido.get_input_names() if "disting NT" in name][0]

outPort = mido.open_output( outPortName )
inPort = mido.open_input( inPortName )


def addCheckSum( arr ):
	sum = 0
	for i in range( 7, len(arr) ):
		sum += arr[i]
	sum = ( -sum ) & 0x7f
	arr.append( sum )


def getCurrentPresetPath( ):
    arr = [ 0xF0, 0x00, 0x21, 0x27, 0x6D, sysExId, 0x56, 0xF7 ]
    outMsg = mido.Message.from_bytes( arr )
    outPort.send( outMsg )

    inMsg = inPort.receive()
    stringBytes = bytes(inMsg.data[6:])
    presetName = stringBytes.decode('ascii').split('\x00', 1)[0]
    return presetName


def newPreset( ):
    arr = [ 0xF0, 0x00, 0x21, 0x27, 0x6D, sysExId, 0x35, 0xF7 ]
    outMsg = mido.Message.from_bytes( arr )
    outPort.send(outMsg)


# this method lifted mostly verbatim from file_send.py
def uploadFile( local_file, nt_path ):
    kOpUpload = 4
    ack = mido.Message.from_bytes( [ 0xF0, 0x00, 0x21, 0x27, 0x6D, sysExId, 0x7A, 0, kOpUpload, 0xF7 ] )

    with open( local_file, 'rb' ) as F:
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

        addCheckSum( arr )
        arr.append( 0xF7 )
        outMsg = mido.Message.from_bytes( arr )
        outPort.send( outMsg )

        uploadPos += count
        
        inMsg = inPort.receive()
        if inMsg != ack:
            return False

    return True


def rescanPlugins( ):
    arr = [ 0xF0, 0x00, 0x21, 0x27, 0x6D, sysExId, 0x7A, 0x08 ]
    addCheckSum(arr)
    arr.append( 0xF7 )
    outMsg = mido.Message.from_bytes( arr )
    outPort.send(outMsg)


def loadPreset( nt_path ):
    arr = [ 0xF0, 0x00, 0x21, 0x27, 0x6D, sysExId, 0x34, 0x00 ]
    for i in range( len(nt_path) ):
        arr.append( ord( nt_path[ i ] ) )
    arr.append( 0x00 )
    arr.append( 0xF7 )
    outMsg = mido.Message.from_bytes( arr )
    outPort.send(outMsg)


# remember which preset is loaded
currentPreset = getCurrentPresetPath().strip()

# create a blank preset to allow plugins to reload
newPreset()

# upload the new plugin
fileCopied = uploadFile ( local_plugin_path, nt_plugin_path )
if fileCopied:
    # scan plugins to make the new one available
    rescanPlugins()

    # reload previous preset, if there was one
    if currentPreset != "":
        loadPreset( currentPreset )

    print( "Success!" )
else:
    print( "Error uploading plug-in file!" )
