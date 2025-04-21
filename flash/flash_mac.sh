#! /bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <firmware package directory>"
    exit 1
fi

if ! [ -d "$1" ]; then
  echo "FAILURE: Firmware package directory not found: $1"
  exit 2
fi

export "SPT_INSTALL_BIN=."

$1/write_image_mac.sh

blhost -u 0x15A2,0x0073 reset
