# Auto-Calibrator
Author: Expert Sleepers Ltd

License: This work is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/?ref=chooser-v1) 

## Overview
This preset designed to demonstrate the Auto-calibrator algorithm. An LFO waveform is passed into the Quantizer to generate a simple scale as a CV. This is then adjusted by the Auto-calibrator, and exposed on output 3 for you to connect to a VCO. The VCO output should be connected to input 1. A mixer is provided to route this signal to outputs 1 & 2 (so you can hear it), and a tuner is also connected to input 1 so you can check the tuning of the notes.

Once you've connected a VCO as above, you should be able to hear the scale. Check the tuning with the tuner - it will most likely be off, unless you somehow carefully tuned the VCO previously. Now, switch to the Auto-calibrator algorithm and set the 'Start' parameter to 'On'. Let it do its thing. Assuming it worked, the scale should now be in tune, which you can check with the tuner.

## Breakdown

### LFO
The LFO generates a single channel, which is set to use **Output 3**. The shape is set to a slow triangle wave, with an amplitude of 1V.

### Quantizer
The Quantizer processes the CV output by the LFO. It is set to use **Output 3** for its CV input. The CV output is also set to **Output 3** (and so replaces the LFO CV), and the Gate output is set to **Output 4**, should you find it helpful to patch that into an envelope generator or similar.

The scale is set to C Dorian. The 'Quantize mode' is set to 'Warped' so that the linear LFO shape generates a nice evenly spaced scale - you might like to contrast this with setting the mode to 'Nearest'.

### Auto-calibrator
The Auto-calibrator massages the CV from the Quantizer so that it's in tune. Its input and output are both set to **Output 3**, so it receives the Quantizer output and replaces it.

The 'Audio input' is set to **Input 1**, so this is where the VCO needs to be connected so that the algorithm can listen to it during calibration.

The calibration saved in the preset is of course only appropriate for the particular setup that was used when creating it. Replace this with your own calibration as described above.

### Mixer Mono
This is simply being used as a shunt to connect **Input 1** to **Output 1** and **Output 2**, so the VCO signal connected to the Auto-calibrator can also be output.

### Tuner (simple)
Channel 1 of the Tuner is set to listen to **Input 1**, so you can check the pitch of the VCO.
