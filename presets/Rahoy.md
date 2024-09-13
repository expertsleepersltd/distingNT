# Rahoy
Author: Simon Kirby

License: This work is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/?ref=chooser-v1) 

Factory preset, included on the MicroSD card.

## Overview
As noted in the preset itself, "This is an example of the Kirbinator algorithm, prepared by its namesake, Simon Kirby. It is a sound much used on his album [At Rahoy, the Early Light](https://simonkirby.bandcamp.com/album/at-rahoy-the-early-light).".

The preset works on audio fed into the module's inputs 1 & 2.

## Breakdown

### Clock
The Clock algorithm generates the clocks that are required by the Kirbinator for its Mark and Trigger inputs.

It outputs a single clock, which is shared by both Mark and Trigger. The clock is output on **Aux 1**.

If you were feeding rhythmic audio into this preset and wanted the Kirbinator to be in sync, you could remove this Clock algorithm and feed external clocks into the Kirbinator instead. Or, you could change the Clock's 'Source' to be 'External' or 'MIDI' instead of 'Internal'.

### Delay (Stereo)
This algorithm applies a delay effect to the audio before it enters the Kirbinator.

The left/right inputs are **Input 1** and **Input 2** - these are then the audio inputs to the preset. The left/right outputs are **Output 1** and **Output 2**.

The 'Mix' parameter is the wet/dry control for the delay effect.

### Kirbinator
The left/right inputs and outputs are **Output 1** and **Output 2**, so the algorithm works on the output of the delay. The 'Output mode' is set to 'Add', but this should really be 'Replace' - an updated version of this preset will correct that.

The Mix page allows us to set the Dry and Effect gains independently.

On the Routing page, the 'Mark input' and 'Trigger input' are both set to **Aux 1**, which is the output from the Clock algorithm above.

### Reverb
This algorithm's left/right inputs and outputs are **Output 1** and **Output 2**, so it is adding reverb to the Kirbinator output. 
