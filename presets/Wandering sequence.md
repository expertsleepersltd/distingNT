# Wandering sequence
Author: Expert Sleepers Ltd

License: This work is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/?ref=chooser-v1) 

## Overview
A simple demonstration of how mapping a step sequencer pitch produces an evolving pattern. The sequencer's first pitch is mapped to the LFO output. The sequencer's modulation lane also changes the reverb send.

## Breakdown

### Clock
The Clock algorithm generates a single output clock on **Input 1**.

The preset is set to use internal clock, but you can easily change it to sync to external clock pulses (from another module) or to MIDI, via the 'Source' parameter.

### LFO
The LFO algorithm generates a slow ramp waveform on **Aux 1**.

### Step sequencer
The sequencer takes clock from the Clock on **Input 1**. It outputs a pitch CV on **Output 4** and a gate on **Output 3**.

The mod(ulation) output appears on **Aux 2**. Note that the modulation value for all steps is zero apart from step 1. This is used to modulate the amount of reverb send.

The pitch of step 1 is mapped to **Aux 1**, the LFO output.

### Slew rate limiter
This is smoothing the sequencer's modulation output on **Aux 2**, replacing it with a slewed version.

### Quantizer
The Quantizer constrains the sequencer pitches to a scale. CV input and output are on **Output 4** (replacing the sequencer's pitch CV with a quantized version). The Quantizer uses the gate on **Output 3** but does not alter it or generate its own gate.

### Poly Multisample
This algorithm plays the piano samples. CV/gate are from **Output 4** and **Output 3**. Audio output is to **Output 1/2**.

### Mixer Stereo
This here to provide a reverb send. The piano sound enters on **Output 1/2**, and the mixer output is also on **Output 1/2**, replacing the input.

The reverb send goes to **Aux 3**. The amount of send is mapped to **Aux 2**, the slewed version of the sequencer modulation output.

### Reverb
Takes input from **Aux 3** and adds its output to **Output 1/2**.

### Saturation
Applies a final saturation effect to **Output 1/2**.
