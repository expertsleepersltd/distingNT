# Granulated Piano
Author: Expert Sleepers Ltd

License: This work is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/?ref=chooser-v1) 

Factory preset, included on the MicroSD card.

## Overview
This preset mainly intended as a demo of the Granulator algorithm. Sound is produced by a Poly Multisample algorithm, which you can play via CV/gate, MIDI, or I2C.

## Breakdown

### Poly Multisample
This polysynth algorithm is set up to use two CV/gate inputs, so two notes can be played at once.

'Gate input 1' is set to **Input 1**. 'Gate 1 CV count' is set to 1, so the next 1 bus is used as a CV - which is **Input 2**. Similarly 'Gate input 2' is set to **Input 3**, and 'Gate 2 CV count' is set to 1, so the second CV input is **Input 4**.

If you prefer, you can also play the algorithm via MIDI (channel 1) or I2C.

The algorithm output is on the default busses **Output 1** and **Output 2**.

### Chorus (Vintage)
The left/right inputs and outputs are set to **Output 1** and **Output 2**, so the algortihm is processing the Poly Multisample output. The 'Output mode' is set to 'Replace', so the chorus algorithm's output is *replacing* the incoming audio.

### Delay (Stereo)

A simple delay effect is added to the chorus output.

Left/right inputs and outputs are again set to **Output 1** and **Output 2**. The 'Output mode' is set to 'Add', so the delay algorithm's output is being *added* to the chorus output.

The 'Mix' is set to 100%, so it's only the wet (delayed) signal that is being added. The 'Level' parameter then allows us to mix in the delay to taste.

### Granulator
The Granulator algorithm is set up as an audio effect. The 'Record' parameter is 'On', so it's continually recording audio into its buffer. The three drone voices are enabled, so grains are also continually being played.

Rather than add the granulator effect directly to the output audio, as is done for the chorus and delay effects, here we route the granulator out to another pair of busses so we can apply a reverb only to the granulated sound, not to the granulator's input.

To achieve this, the granulator's left/right inputs are set to **Output 1** and **Output 2**, while its left/right outputs are set to **Output 3** and **Output 4**. In the Mix section, 'Dry gain' is set to '-inf dB' so that none of the dry (ungranulated) audio comes through to the outputs.

### Reverb
As mentioned above, the reverb applies only to the granulator output. The reverb algorithm's left/right inputs are **Output 3** and **Output 4** (the granulator output). The reverb outputs are **Output 1** and **Output 2**, and the output mode is 'Add', so the reverb output is added in to those busses, on top of the chorused/delayed output from the Poly Multisample.

The reverb 'Mix' parameter gives us a wet/dry mix for the amount of reverb on the granulator output.
