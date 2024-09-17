# Euclidean Drums
Author: Expert Sleepers Ltd

License: This work is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/?ref=chooser-v1) 

Uses a number of drum sample folders on the stock MicroSD card.

## Overview
This preset is based around a Euclidean patterns algorithm driving a Sampler player. An LFO modulates some of the sample choices, while a second Euclidean patterns instance modulates the patterns of the first.

## Breakdown
### Clock
The Clock algorithm generates two clocks on **Aux 1** and **Aux 3**, and a reset pulse on **Aux 2**. The clock on **Aux 1** is a 1/16th note clock for the primary Euclidean patterns (which is triggering all the drums), while the clock on **Aux 3** is a slower one (1/2 notes) to  drive the other Euclidean patterns algorithm.

The preset is set to use internal clock, but you can easily change it to sync to external clock pulses (from another module) or to MIDI, via the 'Source' parameter.

### Euclidean patterns
The first Euclidean patterns algorithm generates a slowly changing pattern to introduce variation into the other Euclidean patterns algorithm.

It takes clock from **Aux 3** and reset from **Aux 2** (both from the Clock algorithm). It has one channel which outputs on **Aux 3**, replacing the clock.

The pattern selected is one pulse every four steps. Since the clock is 1/2 notes, that corresponds to 2 beats out of 2 bars. The output type is changed to '% of clock' (rather than the default 'Trigger') so that the output remains high during the pulse. This will be our modulation source to modify the following algorithm.

### Euclidean patterns
The second Euclidean patterns algorithm generates the drum triggers.

It takes clock from **Aux 1** and reset from **Aux 2** (both from the Clock algorithm). It has eight channels which output on **Aux 1** thru **Aux 8**, replacing the signals already there.

The Pulses parameter of channel 2 of this algorihm is mapped to **Aux 3**, which is the output of the first Euclidean patterns. The value changes between 4 and 11 as a result. This particular channel is triggering the snare drum - you can quite clearly hear the variation from a steady backbeat (4 pulses) to a more complex rhythm (11 pulses).

### LFO
The LFO's job is to generate some modulation of which samples get played by the Sample player.

It has two channels, one driving **Output 3** and one driving **Output 4**.

### Sample player
The Sample player plays a selection of drum samples, triggered by the Euclidean patterns on **Aux 1** thru **Aux 8**.

Most of the samples are routed to **Output 1** and **Output 2**, except for Trigger 2 (the snare) which is routed to **Output 7** and **Output 8** so that we can process it separately.

The sample selections for Triggers 5 & 8 are mapped to the two LFO outputs, with a small Delta so the sample changes by only one or two samples away from the one selected by the parameter.

### Kirbinator
The Kirbinator takes input from and outputs to **Output 1** and **Output 2**, replacing the busses with its own mix of dry and effect signals.

It uses **Aux 6** and **Aux 8**, two of the Euclidean patterns outputs, as its Mark and Trigger inputs.

### Delay (Stereo)
This adds a delay effect to the output of the Kirbinator, on **Output 1** and **Output 2**.

It uses **Aux 1**, one of the Euclidean patterns outputs, as a clock input to set the base delay time. The Delay multiplier parameter is set to 1/8 to use a division of this time as the actual delay time.

### Reverb
The reverb takes input from and outputs to **Output 7** and **Output 8**, which is the snare drum output from the Sample player. Its Output mode is set to 'Replace', so the Mix control works as a dry/wet mix.

### Mixer Stereo
The mixer is used to combine the drum mix on **Output 1** and **Output 2** with the snare (with reverb) on **Output 7** and **Output 8**.

The final mix is output on **Output 1** and **Output 2**, using the Replace output mode.
