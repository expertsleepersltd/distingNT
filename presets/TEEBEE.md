# TEEBEE
Author: Expert Sleepers Ltd

License: This work is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/?ref=chooser-v1) 

## Overview
A demonstration of the Step sequencer and Accent sweep algorithms, to provide a familiar burbling  synth bassline.

A lot of fun can be had simply randomising the step sequencer.

## Breakdown

### Clock
The Clock algorithm generates a 1/16th note clock on **Input 1**, and a reset trigger once every 2 bars on **Input 2**.

The preset is set to use internal clock, but you can easily change it to sync to external clock pulses (from another module) or to MIDI, via the 'Source' parameter.

### Step sequencer
The sequencer takes its clock from **Input 1** and reset from **Input 2**. It outputs a pitch CV on **Output 3**, gate on **Output 4**, velocity on **Output 5**, and mod(ulation) on **Output 6**.

### Envelope Vol
Generates an envelope that shapes the note volume. Triggered by **Output 4** (sequencer gate), and outputting to **Aux 1**.

### Envelope Filt
Generates an envelope for the filter. Triggered by **Output 4** (sequencer gate), and outputting to **Aux 2**.

The release time is mapped to the velocity on **Output 5** to shorten the release on an accented note.

### VCO with waveshaping
The VCO. Takes pitch from **Output 3** (the sequencer pitch CV output), and outputs to **Output 1**.

### VCA Vol Acc
This VCA applies a volume boost when the sequencer outputs an accent.

It combines the second envelope on **Aux 2** with the sequencer velocity on **Output 5**, adding its output onto **Aux 1** (the volume envelope).

### VCA Vol
This VCA applies the combined volume envelopes on **Aux 1** to the VCO output on **Output 1**.

### VCA Filt Acc
This VCA applies the accent to the second envelope for the filter.

It combines the second envelope on **Aux 2** with the sequencer velocity on **Output 5**, outputting to **Aux 3**.

### Accent sweep
This applies the secret sauce to the accent envelope on **Aux 3**, replacing it with the shapes version.

### Filter depth
This is a mixer which combines the filter envelopes from **Aux 2** (regular envelope) and **Aux 3** (accent envelope). It outputs to **Aux 2**, replacing the input signal.

### VCF (State Variable)
A lowpass filter which acts on the VCO output on **Output 1**. It takes its frequency CV from **Aux 2**.

### Mixer Stereo
Simply takes the filter output on **Output 1** and makes it stereo.
