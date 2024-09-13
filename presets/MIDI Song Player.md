# MIDI Song Player
Author: Expert Sleepers Ltd

License: This work is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/?ref=chooser-v1) 

Factory preset, included on the MicroSD card.

## Overview
This preset demonstrates using the MIDI Player algorithm to play a .mid file from the MicroSD card. It uses a Poly Multisample algorithm and several Poly FM algorithms to play the sounds.

## Breakdown

### MIDI Player
The MIDI Player plays the MIDI file from the MicroSD card and sends the MIDI to the other algorithms.

On the Transport page, the 'Play' parameter is set to 'On' so it will start playing as soon as the preset is loaded.

If you prefer to sync the playback to another module, or to MIDI clock, this can be done on the Clock page.

On the Outputs page, 'Output to internal' is set to 'Yes', so the MIDI will be sent to the other algorithms.

Unless you've enabled a clock input, the MIDI Player algorithm uses no busses as input or output - it only outputs MIDI.

### Drums (Poly Multisample)
A Poly Multisample algorithm (named 'Drums') plays the drum sounds on MIDI channel 10. ('MIDI channel' is set to 10 on the Setup 1 page.)

It uses the sample set 'STANDARD kit reverb 40' which is from a General MIDI drum kit, so the samples are mapped to the correct notes for the General MIDI song file.

The algorithm output is on the default busses **Output 1** and **Output 2**.

### Bass, Riff, Melody, Guitar, Sax Solo (Poly FM)
Five instances of the Poly FM algorithm play other parts from the MIDI file, on MIDI channels 3, 5, 1, 8, & 6 respectively.

All of these produce output on the default busses **Output 1** and **Output 2**, adding their sound to the busses, so ultimately the audio leaving outputs 1 & 2 is the combination of the drums and all the synths.

For more flexibility, you could use a Mixer algorithm, and set each synth to output to its own bus (say, one of the Aux busses).
