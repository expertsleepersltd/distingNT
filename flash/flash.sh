sdphost -u 0x1fc9,0x0135 -j error-status

sdphost -u 0x1fc9,0x0135 -j write-file 536878592 ivt_flashloader_user.bin 

sdphost -u 0x1fc9,0x0135 -j jump-address 536878592

sleep 0.5

blhost -u 0x15A2,0x0073 list-memory

blhost -u 0x15A2,0x0073 fill-memory 538976256 4 3221225479 word
blhost -u 0x15A2,0x0073 fill-memory 538976260 4 0 word
blhost -u 0x15A2,0x0073 configure-memory 9 538976256

blhost -u 0x15A2,0x0073 flash-image disting_NT.hex erase 9

blhost -u 0x15A2,0x0073 reset
