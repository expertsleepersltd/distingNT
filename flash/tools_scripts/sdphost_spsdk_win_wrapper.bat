
pushd %~dp0
SETLOCAL ENABLEDELAYEDEXPANSION
set sdphost_params=%*
set sdphost_params=%sdphost_params:+amp+=^^^&%
echo sdphost %sdphost_params%
sdphost %sdphost_params% | check_result.bat sdphost
ENDLOCAL
popd
if errorlevel 2 (
  echo sdphost failed
  exit /B 2
)
if errorlevel 1 (
  echo sdphost succeeded, HAB enabled and closed
  exit /B 1
)
echo sdphost succeeded, HAB disabled
exit /B 0
