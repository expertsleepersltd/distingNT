# distingNT/tools
Tools for the disting NT module.

© 2024 Expert Sleepers Ltd

Released under the MIT License. See [LICENSE](LICENSE) for details.

## Preset editor
[dnt_preset_editor.html](dnt_preset_editor.html)
Allows you to edit presets in a web browser (via MIDI SysEX).

## Scala tool
[dnt_scala_tool.html](dnt_scala_tool.html)
Tool for transferring Scala .scl .kbm files to the module via MIDI SysEX.

## Screenshot tool
[dnt_screenshot_tool.html](dnt_screenshot_tool.html)
Tool for taking screenshots (via MIDI SysEx).

## Plug-in uploader

[`push_plugin_to_device.py`](push_plugin_to_device.py) uploads a compiled
plug-in to a connected disting NT, rescans the plug-in directory, and reloads
the current preset. The [`ntpush`](ntpush) command provides a shorter,
validated command-line interface to that script.

The uploader requires disting NT firmware 1.13 or later, Python 3, `mido`, and
`python-rtmidi`. One way to install its Python dependencies is:

```sh
cd tools
python3 -m venv venv
venv/bin/python -m pip install mido python-rtmidi
```

`ntpush` automatically uses `tools/venv/bin/python` (or
`tools/.venv/bin/python`) when it exists. Otherwise it uses `python3`; set
`NTPUSH_PYTHON` to select another interpreter.

```sh
./ntpush --help
./ntpush /path/to/plugin.o
./ntpush /path/to/plugin.o 0
./ntpush /path/to/plugin.o 0 devpreset
```

The SysEx ID defaults to `0`. Supplying a preset name saves the current state
under that name before uploading and restores it afterwards. Without a preset
name, unsaved changes to the current preset will be lost.
