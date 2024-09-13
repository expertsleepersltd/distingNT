# Mixer
Author: Expert Sleepers Ltd

License: This work is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/?ref=chooser-v1) 

Factory preset, included on the MicroSD card.

## Overview
This preset demonstrates a simple mixer, with per-channel EQ, and a reverb send. It takes input from the module's 12 inputs and outputs to outputs 1 & 2.

## Breakdown

### EQ Parametric
The EQ algorithm is specified with eight channels.

Channels 1-4 are mono - their 'Width' is set to 1 - and take input from **Input 1**, **Input 2**, **Input 3**, & **Input 4** respectively. The 'Output' of each is set to 'None', which means they work as an insert, replacing the input audio with the EQ'd version.

Channels 5-8 are stereo - their 'Width' is set to 2 - and take input from **Input 5/6**, **Input 7/8**, **Input 9/10**, & **Input 11/12** respectively. The 'Output' of each is again set to 'None'.

### Mixer Stereo
The mixer algorithm is also specified with eight channels, and set up to match the EQ algorithm - four mono channels and four stereo channels, with the same inputs as the EQ. Remember that because the EQ is set up as an insert, the mixer is working on the EQ'd signals.

The mixer is also specified with one send, the 'Destination' of which is **Aux 1**. This is used to send audio to the reverb. The send is set to be 'Post-fade'.

The mixer outputs are **Output 1** and **Output 2**.

### Reverb
The reverb takes input from **Aux 1** (the send from the mixer) and outputs to **Output 1** and **Output 2**. The 'Output mode' is set to 'Add', so the reverb output is combined with the mixer output.

The reverb 'Mix' is set to 100%, so that the mixer send doesn't also add in any dry signal.
