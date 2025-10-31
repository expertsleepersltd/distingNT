#!/bin/bash

####################################################################################################################
#
#  NT Firmware Update Helper (for MacOS) - v1.2 (20251029)
#  created by ty hodson, improved by Neal Sanche
#
#  This script automates the Disting NT firmware update process using the script method mentioned in the Disting NT 
#  user manual. For someone already familiar with using *nix and the command line, a helper script like this is 
#  probably unnecessary. But others may find it difficult to parse the steps and especially the pre-requisites that 
#  need to be in place, and so this helper script is offered to assist.
#
#  What follows is an explanation of what this script does:
#
#  Currently the Disting NT firmware update process relies on SPSDK (Secure Provisioning Software Development Kit), 
#  which is a Python SDK library that includes tools needed for your computer to connect to the Disting NT via USB. 
#  SPSDK has its own pre-requisites -- namely Python 3.9+ (which is included in later versions of MacOS) and Xcode 
#  Command Line Tools (which is not).
#
#  As an aside, this script was written specifically for MacOS, but has been confirmed to work on (Debian) Linux.
#
#  This script initializes a Python3 virtual environment (venv) in the same directory where this script is executed. 
#  On MacOS, this action requires Xcode Command Line Tools, and if it's not already installed, the script will exit 
#  and you'll be provided a command you can run to install it. MacOS itself may also pop up a window prompting you 
#  to install it.
#
#  Once the Xcode tools are installed, run this script again. A hidden venv folder and settings file will be created 
#  in the same directory where you ran the script, and then SPSDK will be installed into the venv (this virtual 
#  environment keeps the firmware updater tools separate from the rest of your system). It may take a few minutes to 
#  complete, but it only has to be done once.
#
#  You'll then be greeted by the firmware update process, which prompts you to ensure that the Disting NT is in its 
#  bootloader mode. It also displays the folder locations where the venv and the downloaded and unzipped firmware 
#  are located. The most streamlined process is to unzip the firmware to the 'distingNT/flash' directory where you 
#  ran this script.
#
#  You're given the opportunity to accept or change the locations if needed. In the latter case, when you're 
#  prompted to provide those locations, you can drag the folder from Finder to the script window and the location 
#  will be auto-filled.
#
#  If multiple firmwares are found they'll be displayed with a number, at which point you can enter the number for 
#  the version you want to install. The rest of the update process is automatic and should take around 20 seconds. 
#  After a successful update, the script will exit with the message "All Done!" and your Disting NT will reboot.
#  To verify the update was successful, press the upper left button and navigate to Menu / Misc / About.
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
