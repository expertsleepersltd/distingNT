# Filter Bank chords
Author: Expert Sleepers Ltd

License: This work is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/?ref=chooser-v1) 

## Overview
Primarily a demo of the Filter Bank algorithm, here used as a polysynth. It also shows off the SATB mode of the polysynth harmony generation.

The preset includes a noise generator for the Filter Bank to operate on, but you can turn that off and instead feed in your own audio (say, a drum loop) on **Input 1**.

## Breakdown

### Clock
The Clock algorithm generates a whole note clock on **Aux 1**.

### Step sequencer
The first Step sequencer generates the 'soprano' part of the harmony. Five notes are played repeatedly in a random order.

The sequencer takes its clock from **Aux 1**. It outputs a pitch CV on **Aux 4**, and a gate on **Aux 3**.

### Step sequencer
The second Step sequencer controls the root degree of the harmony. Its pattern contains the root, fourth, and fifth of the scale.

The sequencer takes its clock from **Aux 1**. It outputs a pitch CV on **Aux 2**.

### Noise generator
Simply provides a noise signal for the filter bank to chew on. Adds its output to **Input 1**.

### Filter bank
The Filter bank takes its input from **Input 1** and generates outputs on **Output 1** and **Output 2** (four filters for each output).

It is driven by a CV/gate pair on **Aux 4** and **Aux 3**.

Chord mode is enabled and set to SATB, so four notes are generated for each input note. The 'Root degree' is set to 'From CV' and **Aux 2** selected as the 'Root CV'.

### Mixer Stereo
Allows you to mix in some of the input signal on **Input 1** with the Filter bank outputs on **Output 1/2**, though in the preset as saved **Input 1** is faded right down.

### Reverb (Clouds)
Applies reverb to the outputs on **Output 1/2**. Note that the output mode is set to Replace so that the mix control works as expected.

### Saturation
Applies saturation to **Output 1/2** to avoid clipping when the Filter bank resonates strongly.
