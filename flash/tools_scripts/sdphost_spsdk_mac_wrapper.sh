#! /bin/bash

echo `which sdphost` "$@"
CMD=$(sdphost "$@")
STATUS="$?"
if [ $STATUS -ne 0 ]; then
  echo "sdphost failed"
  exit 2
fi
RESULT=2
echo "$CMD"
echo "$CMD" | grep -q -E -- 'Success|bootable image generated successfully|1450735702' && RESULT=0
echo "$CMD" | grep -q -E '305411090|Status \(HAB mode\) = 2 \(0x2\)' && RESULT=1
if [ $RESULT -le 1 ]; then
  if [ $RESULT -eq 0 ]; then
    echo "sdphost succeeded, HAB disabled"
  else
    echo "sdphost succeeded, HAB enabled and closed"
  fi
  exit $RESULT
else
  echo "sdphost failed"
  exit 2
fi
