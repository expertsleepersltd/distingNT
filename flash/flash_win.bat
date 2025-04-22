
IF "%~1"=="" (
  @echo Usage: %0 <firmware package directory>
  exit /B 1
)

if not exist "%1" (
  @echo FAILURE: Firmware package directory not found
  exit /B 2
)

SET "SPT_INSTALL_BIN=."

call $1/write_image_win.bat

blhost -u 0x15A2,0x0073 reset
