
SETLOCAL enableDelayedExpansion
set /A result=2
set /A found_error=0
set /A security_enabled=0
set "success=(0x0) Success"
set "success_build=bootable image generated successfully"
set "hab_enabled=305411090"
set "hab_disabled=1450735702"
set "hab_enabled_sdphost_spsdk=Status (HAB mode) = 2 (0x2)"
set "error=error:"
set "rkth_generated=RKTH"
set "sign_write_error=kStatus_AbortDataPhase kStatusRomLdrSignature"
set "cfpa_security_enabled_legacy_blhost=kStatus_FLASH_OutOfDateCfpaPage"
set "cfpa_security_enabled_spsdk_blhost=FLASH Driver: Out Of Date CFPA Page"
set "secure_boot_enabled=10001 (0x2711)"
set "rtxxx_secured_legacy_blhost=Response word 1 = -1019428036 (0xc33cc33c)"
set "rtxxx_secured_spsdk_blhost=Response word 1 = 3275539260 (0xc33cc33c)"
set "hab_enabled_blhost=Security State = SECURE"

@rem store command output into the temporary file
:temp_loop
set TEMPFILE=%TEMP%\spt_%RANDOM%.txt
if exist %TEMPFILE% goto temp_loop 
mkdir "%TEMPFILE%.lock" > NUL
if %ERRORLEVEL% == 1 (
	goto temp_loop 
)
findstr "^" >%TEMPFILE%
type %TEMPFILE%

if not "%~1" == "sdphost" goto blhost
@rem ************** sdphost checks 
findstr "/C:%success%" "%TEMPFILE%" > NUL
if %ERRORLEVEL% == 0 (
	set /A result=0
)

findstr "%hab_disabled%" "%TEMPFILE%" > NUL
if %ERRORLEVEL% == 0 (
	set /A result=0
)

findstr "/C:%hab_enabled_sdphost_spsdk%" "%TEMPFILE%" > NUL
if %ERRORLEVEL% == 0 (
  echo "security enabled, found `%hab_enabled_sdphost_spsdk%`"
  set /A security_enabled=1
)

findstr "%hab_enabled%" "%TEMPFILE%" > NUL
if %ERRORLEVEL% == 0 (
  echo "security enabled, found `%hab_enabled%`"
  set /A security_enabled=1
)

goto finish
:blhost
if not "%~1" == "blhost" (
   echo "Unknown tool %~1"
   set /A found_error=1
   goto finish
)

@rem ************** blhost checks
findstr "/C:%success%" "%TEMPFILE%" > NUL
if %ERRORLEVEL% == 0 (
	set /A result=0
)

findstr "%sign_write_error%" "%TEMPFILE%" > NUL
if %ERRORLEVEL% == 0 (
  set /A found_error=1
)

findstr /C:"%cfpa_security_enabled_legacy_blhost%" "%TEMPFILE%"> NUL
if %ERRORLEVEL% == 0 (
  echo Detected: CFPA page already written
  set /A security_enabled=1
)
findstr /C:"%cfpa_security_enabled_spsdk_blhost%" "%TEMPFILE%"> NUL
if %ERRORLEVEL% == 0 (
  echo Detected: CFPA page already written
  set /A security_enabled=1
)
findstr /C:"%secure_boot_enabled%" "%TEMPFILE%" > NUL
if %ERRORLEVEL% == 0 (
  echo Detected enabled Security
  set /A security_enabled=1
)
findstr /i /C:"%rtxxx_secured_legacy_blhost%" "%TEMPFILE%" > NUL
if %ERRORLEVEL% == 0 (
  echo Detected enabled Security
  set /A security_enabled=1
)
findstr /i /C:"%rtxxx_secured_spsdk_blhost%" "%TEMPFILE%" > NUL
if %ERRORLEVEL% == 0 (
  echo Detected enabled Security
  set /A security_enabled=1
)
findstr /i /C:"%hab_enabled_blhost%" "%TEMPFILE%" > NUL
if %ERRORLEVEL% == 0 (
  echo Detected enabled Security
  set /A security_enabled=1
)
if defined blhost_wrapper_expected_output (
  findstr /i /C:"%blhost_wrapper_expected_output%" "%TEMPFILE%"
  if ERRORLEVEL 1 (
    rem NOP
  ) else (
    echo "Detected `%blhost_wrapper_expected_output%` in blhost output"
    set /A security_enabled=1
  )
)


:finish

rmdir "%TEMPFILE%.lock"
del "%TEMPFILE%"
if %found_error% == 1 (
   exit /B 2
)
if %security_enabled% == 1 (
   exit /B 1
)
ENDLOCAL & SET result=%result%
exit /B %result%
