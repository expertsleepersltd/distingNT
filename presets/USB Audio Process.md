# USB Audio Process
Author: Expert Sleepers Ltd

License: This work is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/?ref=chooser-v1) 

## Overview
This preset uses the USB audio algorithms to enable the module to process audio from the host and send it back. In this particular case, it runs the Granulator algorithm on two of the audio channels.

This means that you could, for example, run the module as a send effect in your DAW.

## Breakdown

### USB audio (from host)
The algorithm's outputs are **Output 1** thru **Output 8**. Audio is received from the host and emerges on these 8 busses.

### Granulator
The Granulator algorithm is set up as an audio effect. The 'Record' parameter is 'On', so it's continually recording audio into its buffer. Two of the drone voices are enabled, so grains are also continually being played.

Left/right inputs and outputs are set to **Output 1** and **Output 2**. The 'Output mode' is set to 'Replace', so the algorithm's output replaces the signal on the bus.

### USB audio (to host)
The algorithm's inputs are **Output 1** thru **Output 8** and **Aux 1** thru **Aux 4**. These 12 busses are sent to the host.
