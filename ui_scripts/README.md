# distingNT/ui_scripts
UI scripts for the disting NT module.

© 2024 Expert Sleepers Ltd

Released under the MIT License. See [LICENSE](LICENSE) for details.

## example.lua
[example.lua](example.lua)

Example script from the user manual; controls an Augustus Loop.

## LFO.lua
[LFO.lua](LFO.lua)

A simple example script, corresponding to the [LFO.json](../presets/LFO.json) factory preset.

## Granulator.lua
[Granulator.lua](Granulator.lua)

UI script making most parameters of the Granulator algorithm accessible directly via the pots, encoders, and buttons - or combinations thereof.

##### Before running the script, make sure the granulator algorithm has already been added, and is named "Granulator"!

#### Pots and Encoders
- Pot1: Grain delay (=position) mean/spread
- Pot2: Grain size mean/spread
- Pot3: Pitch mean/spread
- Encoder1: Click to record, turn to change buffer size
- Encoder2: LFO speed/depth
In each of the above, click to change between mean/spread or speed/depth

#### Buttons
- Button1: toggle Dry gain -inf / 0dB
- Button2: toggle Granulator gain -inf / 0dB
- Button3: cycle between reverse probabilities 0/25/50/75/100 %
- Button4: cycle between 3 LFO shapes Triangle/Ramp up/Ramp Down

#### Button combos
- Hold Button1 and turn (left) Encoder1 to set dry gain (remembered between toggles via Button1)
- Hold Button2 and turn (left) Encoder1 to set granulator gain (remembered between toggles via Button2)
- Hold Button2 + press Button1: Drone 1 on/off
- Hold Button2 + turn Encoder2: Grain limit 1-40
- Hold Button2 + turn Pot2: Rate mean
- Hold Button2 + turn Pot3: Rate spread
- Hold Button3 + press Button4: cycle Grain Shape
- Hold Button4 + press Button3: cycle Spawn Mode

Press all four buttons at the same time to exit the UI script.
