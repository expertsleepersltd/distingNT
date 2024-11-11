# Spectral Freeze auto
Author: Expert Sleepers Ltd

License: This work is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/?ref=chooser-v1) 

## Overview
This preset demonstrates the Spectral Freeze algorithm. To make it automatic, a Delayed Function algorithm drives the whole patch, sequencing a number of events:
- The voices of the Spectral Freeze are frozen, one at a time.
- The output is crossfaded from the unfrozen to the frozen audio.
- Finally the Etherization on the Spectral Freeze is ramped up.

## Breakdown

### Clock
The Clock algorithm outputs clocks for the two Step Sequencers on **Aux 1** and **Aux 2**.

It also outputs a run/stop signal on **Output 8**, so that the Delayed Function algorithm is triggered as soon as the patch is loaded.

### Step Sequencer (x2)
The two Step Sequencers take clocks on **Aux 1** and **Aux 2**, and generate CV/gate pairs on **Aux 3/4** and **Aux 5/6** respectively.

### Poly Multisample
Takes the two CV/gate pairs from the Step Sequencers and plays two different timbres, both outputting to **Aux 7/8**.

### Delay (Stereo)
Applies an echo effect to the output of Poly Multisample, adding its effect to **Aux 7/8**. It takes a clock from **Aux 1** to sync the delay time.

### Delayed Function
This algorithm drives the whole preset, as described above. It is triggered when the preset is loaded by the Clock algorithm via **Output 8**. It outputs to **Aux 1-6**.

### Spectral Freeze
Takes audio from **Aux 8** and freezes it, outputting each voice on its own output using **Aux 1-4**.

The four Freeze parameters are mapped to the first four outputs of the Delayed Function. Etherization is mapped to the sixth output.

### Mixer Stereo
Mixes the four frozen voices on **Aux 1-4** and places them in the stereo field. Outputs to **Aux 1/2** (using replace).

### Reverb
Applied reverb to the mixer output.

### Crossfader
Crossfades the reverb output (**Aux 1/2**) and the pre-freeze signals (**Aux 7/8**). The crossfade amount is driven by a mapping from the Delayed Function via **Aux 5**.

The final output is from **Output 1/2**.
