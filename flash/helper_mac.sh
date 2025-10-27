#!/bin/bash

####################################################################################################################
#
#  NT Firmware Update Helper (for Mac OS) - v1.1 (20250422)
#  created by ty hodson
#
#  This script is intended to assist with updating the Disting NT firmware using the script method, as mentioned 
#  in the Disting NT user manual. For someone already familiar with using *nix and the command line, a helper script 
#  like this is probably unnecessary. But others may find it difficult to parse the steps and especially the 
#  pre-requisites that need to be in place, and so this helper script is offered to assist.
#
#  -----------------------------------------------------------------------------------------------------------------
#
#  Please read the following before deciding if this is for you.
#
#  This script relies on the following pre-requisites:
#
#  1.  SPSDK (Secure Provisioning Software Development Kit) -- This is a Python SDK library that includes the tools 
#      needed for your computer to connect to the Disting NT via USB. SPSDK has its own pre-requisites -- namely 
#      Python 3.9+ -- which can be satisfied by installing Xcode Command Line Tools (more on that in a moment).
#      There's a lot of information at the following link, but the only thing you really need to know is how to 
#      install SPSDK on Mac OS:
#      https://spsdk.readthedocs.io/en/latest/examples/_knowledge_base/installation_guide.html#macos
#
#      But before you do that, recall that the Disting NT user manual says that on Mac OS you may also need to 
#      install Xcode, which is a set of developer tools from the Apple Developer Network. I don't have the full 
#      Xcode package on my Mac, but I do have a subset of Xcode called Command Line Tools, which includes the 
#      components required by SPSDK to update Disting NT's firmware. To see if you have Command Line Tools installed, 
#      type:
#
#      xcode-select -p
#
#      If you get a response with a path to 'CommandLineTools', you're probably set. Otherwise, you can install it 
#      with this command:
#
#      xcode-select --install
#
#      If that makes you uneasy, more information about what to expect when you run that command can be found here:
#      https://mac.install.guide/commandlinetools/4
#
#      After you have Command Line Tools installed, if you wanted to take my word for it (which you shouldn't), you 
#      could just open a Terminal window and type the following commands to install SPSDK (note that these commands 
#      are derived from the installation steps at the SPSDK link above):
#
#        cd ~
#        python3 -m venv venv
#        source venv/bin/activate
#        python -m pip install --upgrade pip
#        pip install spsdk
#        pip install setuptools --upgrade
#        deactivate
#
#      This block of commands creates and activates a Python virtual environment in a folder called 'venv' in your 
#      user directory. It then performs some actions within the venv to avoid creating conflicts with the operating 
#      system's base Python environment. These actions include updating the Python package installer, installing 
#      SPSDK and updating the setuptools package. Finally it deactivates the venv. This virtual environment still 
#      exists and can be activated the next time you need it. You may very well never interact with it again, but 
#      this helper script will.
#
#      The concept of a Python venv is explained more here:
#      https://packaging.python.org/en/latest/guides/installing-using-pip-and-virtual-environments/
#
#  2.  Disting NT firmware (package version):
#      https://expert-sleepers.co.uk/distingNTfirmwareupdates.html
#
#      This is downloaded as a compressed archive (zip), and it needs to be unzipped somewhere on your computer. It 
#      doesn't really matter where, but your home directory might be a good place. When you unzip it, it will create 
#      a folder called 'distingNT_<version>'. This helper script will need to know where to find this folder, and 
#      you'll be prompted to confirm its location. If you have multiple firmware versions stashed there, this script
#      will generate a list for you to choose which one to install.
#
####################################################################################################################

clear
# Determine path used to execute this script; this exported path will be picked up by the update script.
# Note: This assumes that this script was executed from the same dir where tools_scripts is located.
absolute_path=$(realpath "$0")
script_dir_absolute=$(dirname "$absolute_path")
export "SPT_INSTALL_BIN=$script_dir_absolute"

# Sets other location variables used in this script
flashdir="$script_dir_absolute"
venvdir="$script_dir_absolute/.venv"
envfile="$script_dir_absolute/.env"

# Load settings from .env file if it exists
if [ -f "$envfile" ]; then
  source "$envfile"
  echo ""; echo "Loaded settings from .env file"; echo ""
fi

# Initialize Python virtual environment if it doesn't exist
if ! [ -d "$venvdir" ]; then
  echo ""; echo "Python virtual environment not found. Initializing..."; echo ""
  python3 -m venv "$venvdir"
  if [ $? -ne 0 ]; then
    echo "- FAIL: Could not create virtual environment"; echo ""
    echo "Make sure Python 3 is installed. You may need to install Xcode Command Line Tools:"; echo ""
    echo "  xcode-select --install"; echo ""
    exit 1
  fi
  # Activate the venv and install SPSDK
  source "$venvdir/bin/activate"
  echo "- OK: Virtual environment created"
  echo "- Installing pip updates and SPSDK (this may take a few minutes)..."; echo ""
  python -m pip install --upgrade pip
  pip install spsdk
  pip install setuptools --upgrade
  if [ $? -ne 0 ]; then
    echo ""; echo "- FAIL: Could not install SPSDK"; echo ""
    deactivate
    exit 1
  fi
  echo ""; echo "- OK: SPSDK installed successfully"
  deactivate
fi

echo ""; echo "Welcome to NT Firmware Update Helper!"; echo ""

echo "Before proceeding, make sure Disting NT is in bootloader mode:"
echo "  Menu > Misc > Enter bootloader mode..."; echo ""

echo "This script will use the following folder locations (you can change them):"; echo ""

echo "  Firmware folder:  $flashdir"
echo "  Python venv:      $venvdir"; echo ""

##### Start user input
while true; do
  read -p "If this looks good, enter Y to start the firmware update or N to specify your folder locations: " yn
  case $yn in
    [Yy]* ) echo ""; echo "- OK: Assuming defaults"; break;;
    [Nn]* ) echo ""; echo "- OK: Custom folder locations"; echo ""

    echo "For each prompt, press Enter to accept the default location (indicated above), or specify your own."
    echo "  Hint: You can also drag the requested folder to this window to autofill the location."; echo ""

    # If necessary, revise the flashdir location variable
    read -p "Firmware folder location (ENTER to accept default): " input
    if [ -z "$input" ]; then
      echo ""; echo "- OK: flashdir location: $flashdir"; echo ""
    else
      # Expand tilde if present
      if echo "$input" | grep -q "~"; then
        flashdir="${input/#\~/$HOME}"
      else
        flashdir="$input"
      fi
      # Convert to absolute path if relative
      if [[ "$flashdir" != /* ]]; then
        flashdir="$(cd "$flashdir" 2>/dev/null && pwd)" || {
          echo ""; echo "- FAIL: $flashdir doesn't exist or is not accessible"; echo ""
          exit 1
        }
      fi
      if ! [ -d "$flashdir" ]; then
        echo ""; echo "- FAIL: $flashdir doesn't exist"; echo ""
        exit 1
      fi
      echo ""; echo "- OK: flashdir location: $flashdir"; echo ""
    fi

    # If necessary, revise the venvdir location variable
    read -p "venv location (ENTER to accept default): " input
    if [ -z "$input" ]; then
      echo ""; echo "- OK: venvdir location: $venvdir"; echo ""
    else
      # Expand tilde if present
      if echo "$input" | grep -q "~"; then
        venvdir="${input/#\~/$HOME}"
      else
        venvdir="$input"
      fi
      # Convert to absolute path if relative
      if [[ "$venvdir" != /* ]]; then
        venvdir="$(cd "$venvdir" 2>/dev/null && pwd)" || {
          echo ""; echo "- FAIL: $venvdir doesn't exist or is not accessible"; echo ""
          exit 1
        }
      fi
      if ! [ -d "$venvdir" ]; then
        echo ""; echo "- FAIL: $venvdir doesn't exist"; echo ""
        exit 1
      fi
      echo ""; echo "- OK: venvdir location: $venvdir"; echo ""
    fi

  break;;
    * ) echo "Please enter y or n.";;
  esac
done
##### End user input

# Save settings to .env file for future use
echo "flashdir=\"$flashdir\"" > "$envfile"
echo "venvdir=\"$venvdir\"" >> "$envfile"
echo "- OK: Settings saved to .env file"

# Make sure venvdir and flashdir exist
if ! [ -d "$venvdir" ]; then
  echo "- FAIL: $venvdir doesn't exist"; echo ""
  echo "Are you sure you've previously activated a Python venv at this location?"; echo ""
  exit 1
else
  if ! [ -d "$flashdir" ]; then
    echo "- FAIL: $flashdir doesn't exist"; echo ""
    exit 1
  fi
  echo "- OK: Folder locations validated"
fi

# Locate firmware update script(s) in selected flashdir
cd "$flashdir"
script_name="write_image_mac.sh"
base_dir="$flashdir"
found_scripts=$(find "$base_dir" -type f -name "$script_name" 2>/dev/null)
# Check if any scripts were found
if [ -z "$found_scripts" ]; then
  echo "- FAIL: '$script_name' not found"
  echo ""; echo "Did you unzip the firmware package file?"; echo ""
  exit 1
fi
# If more than one script was found, present a numbered list
if [[ $(echo "$found_scripts" | wc -l) -gt 1 ]]; then
  echo ""; echo "Multiple firmware update scripts named '$script_name' found:"; echo ""
  # Create a numbered list and print to screen
  i=1
  while read -r script; do
    echo "$i. $script"
    i=$((i+1))
  done <<< "$found_scripts"
  # Prompt user to select a script
  while true; do
    echo ""; read -p "Enter the number of the updater you want to run: " selection
    if [[ "$selection" =~ ^[1-9][0-9]*$ ]]; then
      # Get the script path from the selected number
      echo "$found_scripts" | awk -F "\n" -v sel="$selection" '{if(NR==sel) {print $0}}'
      chosen_script=$(echo "$found_scripts" | awk -F "\n" -v sel="$selection" '{if(NR==sel) {print $0}}')
      # Check if a valid script was selected
      if [[ -f "$chosen_script" ]]; then
        echo ""; echo "- OK: Selected firmware update script: $chosen_script"; echo ""
        script_path="$chosen_script"; break
      else
        echo "Invalid selection. Please try again."
      fi
    else
      echo "Invalid input. Please enter a number."
    fi
  done
else
  # If only one script was found, name it
  echo "- OK: Found firmware update script: $found_scripts"; echo ""
  script_path="$found_scripts"
fi

# Enter the venv to carry out the update
source "$venvdir"/bin/activate

# Pre-flight device check
output=$(sdphost -u 0x1fc9,0x0135 -j error-status | grep "\"value\": 1450735702")
if [[ -n "$output" ]]; then
  echo "- OK: Disting NT is ready"
else
  echo ""; echo "- FAIL: Can't see Disting NT"
  deactivate
  echo ""; echo "Be sure to put Disting NT in bootloader mode, and then try again."; echo ""
  exit 1
fi

# Proceed with update
echo "- OK: Calling firmware update script"; echo ""
bash "$script_path"
echo ""; echo "- OK: Firmware update script exited"
echo "- OK: Sending restart request to Disting NT"; echo ""
blhost -u 0x15A2,0x0073 reset
deactivate
echo ""; echo "All done!"; echo ""
