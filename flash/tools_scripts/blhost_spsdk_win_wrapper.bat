
pushd %~dp0
SETLOCAL ENABLEDELAYEDEXPANSION
set blhost_params=%*
set blhost_params=%blhost_params:+amp+=^^^&%
set TIMEOUT=5000
@rem if command does not accept string with quotes inside quotes
set blhost_params_noquot=%blhost_params:"=%
if not "x%blhost_params_noquot:get-property=%"=="x%blhost_params_noquot%" (
  @rem for get-property command use shorted timeout to retrieve result quickly
  set TIMEOUT=2000
) else if not "x%blhost_params_noquot:flash-erase-all=%"=="x%blhost_params_noquot%" (
  @rem for flash-erase-all use longer timeout
  set TIMEOUT=240000
) else if not "x%blhost_params_noquot:receive-sb-file=%"=="x%blhost_params_noquot%" (
  @rem for receive-sb-file might take longer if contains flash-erase or flash-erase-all
  set TIMEOUT=240000
) else if not "x%blhost_params_noquot:flash-erase-=%"=="x%blhost_params_noquot%" (
  @rem for flash-erase-region use longer timeout taking into account the size of the region
  set TIMEOUT=50000
  @ rem delete arguments before the flash-erase-* itself
  set ERASE_ARGS=%blhost_params_noquot:*flash-erase-=%
  for /f "tokens=3" %%i in ("!ERASE_ARGS!") do set ERASE_SIZE=%%i
  @rem for every MB add 10 extra seconds
  set /A TIMEOUT=!TIMEOUT!+!ERASE_SIZE!/100
)
echo blhost -t %TIMEOUT% %blhost_params%
blhost -t %TIMEOUT% %blhost_params% | check_result.bat blhost
ENDLOCAL
popd

if errorlevel 2 (
  echo blhost failed
  exit /B 2
)
if errorlevel 1 (
  echo blhost detected secure status
  exit /B 1
)
echo blhost succeeded
exit /B 0
