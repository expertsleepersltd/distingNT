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

Pot1: Grain delay (=position) mean/spread
Pot2: Grain size mean/spread
Pot3: Pitch mean/spread
Encoder1: Click to record, turn to change buffer size
Encoder2: LFO speed/depth
In each of the above, click to change between mean/spread or speed/depth

Button1: switch Dry gain -inf / 0dB
  - Hold Button1 and turn (left) Encoder1 to set dry gain (remembered between toggles)
Button 2: switch Granulator gain -inf / 0dB
  - Hold Button2 and turn (left) Encoder1 to set granulator gain (remembered between toggles)
Button 3: cycle between reverse probabilities 0/25/50/75/100 %
Button 4: cycle between 3 LFO shapes Triangle/Ramp up/Ramp Down

Hold Button 2 + press Button1: Drone 1 on/off
Hold Button 2 + turn Pot2: Grain limit 1-40
Hold Button 3 + press Button4: change Grain Shape

Press all four buttons at the same time to exit the UI script.