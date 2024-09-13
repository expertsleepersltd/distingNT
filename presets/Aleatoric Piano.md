# Aleatoric Piano
Author: Expert Sleepers Ltd

License: This work is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/?ref=chooser-v1) 

Factory preset, included on the MicroSD card.

## Overview
This preset is centred around a Poly Multisample algorithm, playing piano samples. The algorithms above it generate a random evolving sequence of CV/gates; those after it are audio effects (delay and reverb).

## Breakdown
### Clock
The Clock algorithm generates two output clocks on **Aux 1** and **Aux 3**, one quarter notes and the other quarter note triplets.

The preset is set to use internal clock, but you can easily change it to sync to external clock pulses (from another module) or to MIDI, via the 'Source' parameter.

### Shift Register Random (x2)
Two Shift Register Random algorithms take the clocks and generate random evolving patterns of CVs.

The first takes input from **Aux 1** and outputs to **Aux 2**; the second takes input from **Aux 3** and outputs to **Aux 4**.

### Quantizer
The Quantizer algorithm takes the two CVs (from the Shift Register Random algorithms) and the two clocks (from the Clock algorithm), and quantizes the CVs into a scale.

Channel 1 of the Quantizer takes CV from **Aux 2** and gate from **Aux 1**. Its output CV and gate are on the same busses, replacing them - **Aux 2** is now the quantized CV and **Aux 1** is now the trigger output from the Quantizer. Note that this fires only when the CV changes, so instead of a regular clock, we now have a pattern of triggers generated according to the random CV pattern. This is key to the sound of the patch - it would sound a lot more robotic if the piano notes were simply firing on every clock.

Similarly channel 2 of the Quantizer takes CV from **Aux 4** and gate from **Aux 3** and replaces them with a quantized CV and a trigger.

### Poly Multisample
This polysynth algorithm is set up to use two CV/gate inputs, so two notes can be played at once.

'Gate input 1' is set to **Aux 1**, which is the trigger from channel 1 of the Quantizer. 'Gate 1 CV count' is set to 1, so the next 1 bus is used as a CV - which is **Aux 2**, the quantized CV.

Similarly 'Gate input 2' is set to **Aux 3**, which is the trigger from channel 2 of the Quantizer, and 'Gate 2 CV count' is set to 1.

The algorithm output is on the default busses **Output 1** and **Output 2**.

### Delay (Stereo)

A simple delay effect is added to the piano output.

Left/right input and output are set to **Output 1** and **Output 2**. The 'Output mode' is set to 'Add', so the delay algorithm's output is being *added* to the Poly Multisample output.

The 'Mix' is set to 100%, so it's only the wet (delayed) signal that is being added. The 'Level' parameter then allows us to mix in the delay to taste.

### Reverb

Again, left/right input and output are set to **Output 1** and **Output 2**. This time however the 'Output mode' is set to 'Replace', so the reverb algorithm's output is *replacing* the incoming audio (the piano with added delay).

Because we're using 'Replace', the 'Mix' parameter is our wet/dry control for the reverb effect.

