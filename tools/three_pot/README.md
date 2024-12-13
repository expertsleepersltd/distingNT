# distingNT/tools/three_pot
Prepares .3pot files for the disting NT module.

© 2024 Expert Sleepers Ltd

Released under the MIT License. See [LICENSE](LICENSE) for details.

## Usage
Put .spn files in the 'spn' folder. Subdirectories are allowed.

Run 'make'. If you have a multi-core machine use the -j option for multiple parallel builds e.g. 'make -j23'.

Ouptut .3pot files will be built into the '3pot' folder. These can then be copied to a MicroSD card for use in the disting NT.

## Dependencies
[spn_to_c](https://github.com/expertsleepersltd/spn_to_c)

arm-none-eabi toolchain, installed via [MCUXpresso IDE](https://www.nxp.com/design/design-center/software/development-software/mcuxpresso-software-and-tools-/mcuxpresso-integrated-development-environment-ide:MCUXpresso-IDE)

After installing the IDE, read "MCUXpresso_IDE_Installation_Guide.pdf" and find the "Command line use" section that applies to your platform.

On macOS, note that the "MCUXpressoPath.sh" script is for bash, so it will not work with the macOS default zsh. Switch to bash before sourcing the script.

To use the Makefile on Windows you'll need to use a Linux subsystem of some sort e.g. Cygwin.
