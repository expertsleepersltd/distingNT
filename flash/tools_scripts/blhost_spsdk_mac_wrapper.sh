#! /bin/bash

TIMEOUT=5000
ARGS="$@"
if [ -z "${ARGS##*get-property*}" ]; then
  # for get-property command use shorted timeout to retrieve result quickly
  TIMEOUT=2000
elif [ -z "${ARGS##*flash-erase-all*}" ]; then
  # for flash-erase-all use longer timeout
  TIMEOUT=240000
elif [ -z "${ARGS##*receive-sb-file*}" ]; then
  # for receive-sb-file use longer timeout, because erase flash can be included
  TIMEOUT=240000
elif [ -z "${ARGS##*flash-erase*}" ]; then
  # for flash-erase-region use longer timeout
  TIMEOUT=50000
  ERASE_ARGS=(${ARGS##*flash-erase})
  ERASE_SIZE=${ERASE_ARGS[2]}
  if [ -n "$ERASE_SIZE" ]; then
    # for every MB add 10 extra seconds
    ((TIMEOUT=TIMEOUT + ERASE_SIZE / 100))
  fi
fi
echo `which blhost` -t ${TIMEOUT} "$@"
CMD=$(blhost -t ${TIMEOUT} "$@")
STATUS="$?"
RESULT=2
echo "$CMD"
echo "$CMD" | grep -q -E -- 'Success|bootable image generated successfully|1450735702' && RESULT=0
echo "$CMD" | grep -q -E -- 'FLASH Driver: Out Of Date CFPA Page' && RESULT=1 && STATUS=0
echo "$CMD" | grep -q -E -- '10001|Response word 1 = 3275539260 (0xc33cc33c)|Security State = SECURE' && RESULT=1 
if [[ -z "${blhost_wrapper_expected_output}" ]]; then
  :
else
  echo "$CMD" | grep -q -E -- "${blhost_wrapper_expected_output}" && RESULT=1 && STATUS=0
fi
# LPC failure writing signed image
echo "$CMD" | grep -q -E -- 'kStatus_AbortDataPhase|kStatusRomLdrSignature' && RESULT=2
if [ $STATUS -eq 0 ] && [ $RESULT -le 1 ]; then
  echo "blhost succeeded"
  exit $RESULT
else
  echo "blhost failed"
  exit 2
fi
