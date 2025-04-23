# distingNT/flash
Tools for updating the firmware on the disting NT module.

© 2025 Expert Sleepers Ltd

Released under the MIT License. See [LICENSE](LICENSE) for details.

Please see the disting NT user manual for detailed instructions on updating the module firmware.

Linux users can use the macOS scripts.

## flash_mac.sh/flash_win.bat
Usage

`
flash_mac.sh <unzipped manufacturing package>
`

These scripts flash firmware from manufacturing packages as prepared by the [MCUXpresso Secure Provisioning Tool](https://www.nxp.com/design/design-center/software/development-software/mcuxpresso-software-and-tools-/mcuxpresso-secure-provisioning-tool:MCUXPRESSO-SECURE-PROVISIONING).

## helper_mac.sh
User-contributed script that provides a bit more hand-holding than `flash_mac.sh`.

## flash.sh/flash.bat
These legacy scripts flash firmware in hex format, and are deprecated.
