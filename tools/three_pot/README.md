# distingNT/tools/three_pot
Prepares .3pot files for the disting NT module.

© 2025 Expert Sleepers Ltd

Released under the MIT License. See [LICENSE](LICENSE) for details.

## Usage
Put .spn files in the 'spn' folder. Subdirectories are allowed.

Run `make`. If you have a multi-core machine use the -j option for multiple parallel builds e.g. `make -j23`.

Ouptut .3pot files will be built into the '3pot' folder. These can then be copied to a MicroSD card for use in the disting NT.

To use the Makefile on Windows you'll need to use a Linux subsystem of some sort e.g. wsl or Cygwin.

## Dependencies
[spn_to_c](https://github.com/expertsleepersltd/spn_to_c)

arm-none-eabi toolchain
- Can be installed via [MCUXpresso IDE](https://www.nxp.com/design/design-center/software/development-software/mcuxpresso-software-and-tools-/mcuxpresso-integrated-development-environment-ide:MCUXpresso-IDE)
- Can be installed on Linux via a package manager e.g. apt install gcc-arm-none-eabi

If you install the IDE, read "MCUXpresso_IDE_Installation_Guide.pdf" and find the "Command line use" section that applies to your platform.

On macOS, note that the "MCUXpressoPath.sh" script is for bash, so it will not work with the macOS default zsh. Switch to bash before sourcing the script.

### Installing wsl on Windows

These notes are not intended to be a comprehensive tutorial on wsl - just sufficient to enable running of this project on Windows.

- If not already installed, install wsl by running 
`wsl --install`
in a command prompt. A reboot may be required afterwards.
- Your command prompt will now have an extra item, 'Ubuntu', in its drop-down menu. Select this.
- Run the following commands:
```bash
sudo apt update
sudo apt install gcc-arm-none-eabi
sudo apt install build-essential
```
- You should now be able to run `make` after cloning the GitHub repository.
