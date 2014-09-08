:: thin_manager.cmd                     01/29/2014
:: Jens Jap
::
:: change log
:: 02/14/2014 - jj - Add optional runtime environment parameter
:: 02/14/2014 - jj - Add 5 second delay between each kill command
:: 02/14/2014 - jj - Add 2 minute delay between starting each thin server
:: 02/14/2014 - jj - Add restarting subroutine. Restart happens in
::                   such a fashion that only 1 thin server is down at a time (10 minute delay)
::

@ECHO OFF

cls

REM Parameter1 specifies action (start|stop|status|restart|help)
REM Parameter2 environment (valid options: production|development|test, default: development)
REM Parameter3 number of servers in cluster to work on (default: 5)
REM Parameter4 starting port number (default: 3000)

d:
cd\
cd Ruby
cd srdr-dev

setlocal enableextensions
setlocal enabledelayedexpansion

:: ------------------- MAIN -------------------- ::
call :parameter_validation %1 %2 %3 %4
call :initialize %1 %2 %3 %4
if not "%error_list%"=="" goto :error
echo "%timestamp% thin manager called with the following params: %1 %2 %3 %4"
echo "%timestamp% thin manager called with the following params: %1 %2 %3 %4">> "%logfile%"
echo "%timestamp% starting thin manager with parameters: %command_action% %environment% %srvr_cnt% %starting_port%"
echo "%timestamp% starting thin manager with parameters: %command_action% %environment% %srvr_cnt% %starting_port%">> "%logfile%"
echo.
if /i "%command_action%"=="Help" goto :help
if /i "%command_action%"=="Start" goto :start
if /i "%command_action%"=="Stop" goto :stop
if /i "%command_action%"=="Restart" goto :restart
if /i "%command_action%"=="Status" goto :status
set error_list=%error_list% 99
if not "%error_list%"=="" goto :error
goto :end

:: ------------------- Subroutines -------------------- ::
:start
echo "Remove existing processes first"
echo "Remove existing processes first">> "%logfile%"
call :clean_up
echo "Starting cluster with server count %srvr_cnt% beginning on port %starting_port%"
echo "Starting cluster with server count %srvr_cnt% beginning on port %starting_port%">> "%logfile%"
set /a ending_port=%starting_port%+%srvr_cnt%-1
for /l %%A in (%starting_port%,1,%ending_port%) do (
  sleep 120
  call :start_one_server %%A
)
goto :end

:clean_up
call :find_pids
call :find_cmds
if not "%pids%"=="" (
  call :kill_processes
) else (
  echo "No running processes found. Nothing to kill"
  echo "No running processes found. Nothing to kill">> "%logfile%"
  goto :eof
)
call :find_pids
if not "%pids%"=="" (
  set error_list=%error_list% 31
  goto :error
) else (
  echo "Processes successfully stopped!"
  echo "Processes successfully stopped!">> "%logfile%"
)
if not "%cmds%"=="" (
  call :del_cmds
)
goto :eof

:kill_processes
echo "Attempting to kill processes [%pids%]"
for %%A in (%pids%) do (
  taskkill /t /f /pid %%A >> "%logfile%"
  sleep 5
)
goto :eof

:find_pids
set pids=
for /f "usebackq tokens=2" %%A in (`tasklist /fo list /fi "IMAGENAME eq cmd_thin_port_*" ^| find /i "PID:"`) do (
  set pids=!pids! %%A
)
echo "Found the following pids: [%pids%]"
echo "Found the following pids: [%pids%]">> "%logfile%"
goto :eof

:find_cmds
set cmds=
for /f "usebackq tokens=3" %%A in (`tasklist /fo list /fi "IMAGENAME eq cmd_thin_port_*" ^| find /i "Image Name:"`) do (
  set cmds=!cmds! %%A
)
echo "Found the following cmds: [%cmds%]"
echo "Found the following cmds: [%cmds%]">> "%logfile%"
goto :eof

:find_ports
set ports=
for /f "usebackq delims=_. tokens=4" %%A in (`tasklist /fo list /fi "IMAGENAME eq cmd_thin_port_*" ^| find /i "Image Name:"`) do (
  set ports=!ports! %%A
)
echo "Found servers on the following ports: [%ports%]"
echo "Found servers on the following ports: [%ports%]">> "%logfile%"
goto :eof

:start_one_server
echo "Copying cmd.exe"
echo "Copying cmd.exe">> "%logfile%"
call :copy_cmd %1
echo "Starting server on port %1"
echo "Starting server on port %1">> "%logfile%"
start /high /min cmd_thin_port_%1.exe /c bundle exec thin start -p %1 -e %environment%
goto :eof

:kill_n_restart
for %%A in (%ports%) do (
  rem !!!
  echo "Executing the following: taskkill /t /f /im cmd_thin_port_%%A.exe"
  echo "Executing the following: taskkill /t /f /im cmd_thin_port_%%A.exe">> "%logfile%"
  taskkill /t /f /im cmd_thin_port_%%A.exe >> "%logfile%"
  echo "Starting it up again with: start /high /min cmd_thin_port_%%A.exe /c bundle exec thin start -p %%A -e %environment%"
  echo "Starting it up again with: start /high /min cmd_thin_port_%%A.exe /c bundle exec thin start -p %%A -e %environment%">> "%logfile%"
  start /high /min cmd_thin_port_%%A.exe /c bundle exec thin start -p %%A -e %environment%
  echo "Waiting for server on port %%A to boot up before killing the next one."
  echo "Waiting for server on port %%A to boot up before killing the next one.">> "%logfile%"
  sleep 600
)
goto :eof

:copy_cmd
if exist %root_path%\cmd_thin_port_%1.exe (
  echo "cmd_thin_port_%1.exe already exists?"
  echo "cmd_thin_port_%1.exe already exists?">> "%logfile%"
  set error_list=%error_list% 41
) else (
  copy C:\Windows\System32\cmd.exe %root_path%\cmd_thin_port_%1.exe
  echo "Creating cmd_thin_port_%1.exe file"
  echo "Creating cmd_thin_port_%1.exe file">> "%logfile%"
)
if exist %root_path%\cmd_thin_port_%1.exe (
  echo "Copy successful! Created %root_path%\cmd_thin_port_%1.exe"
  echo "Copy successful! Created %root_path%\cmd_thin_port_%1.exe">> "%logfile%"
) else (
  echo "Failure to make a copy. Exiting..."
  echo "Failure to make a copy. Exiting...">> "%logfile%"
  set error_list=%error_list% 42
  goto :error
)
goto :eof

:del_cmds
echo "Attempting to delete cmds [%cmds%]"
echo "Attempting to delete cmds [%cmds%]">> "%logfile%"
for %%A in (%cmds%) do (
  echo "Deleting %root_path%\%%A"
  echo "Deleting %root_path%\%%A">> "%logfile%"
  del %root_path%\%%A >> "%logfile%"
  if exist %root_path%\%%A (
    echo "Failure to delete %root_path%\%%A.exe"
    echo "Failure to delete %root_path%\%%A.exe">> "%logfile%"
    set error_list=%error_list% 44
  )
)
goto :eof

:stop
echo "Stopping"
call :clean_up
goto :end

:restart
echo "Restarting"
call :find_ports
call :kill_n_restart
goto :end

:status
echo "Reporting status"
call :report_status
goto :end

:report_status
tasklist /v /fo table /fi "IMAGENAME eq cmd_thin_port_*"
tasklist /v /fo table /fi "IMAGENAME eq cmd_thin_port_*">> "%logfile%"
goto :eof

:initialize
set root_path=%CD%
set timehour=%time:~0,2%
set timemin=%time:~3,2%
set timesec=%time:~6,2%
set logfile=%root_path%\log\thin_manager.log
set error_log=%root_path%\log\thin_manager.err
set process_list=%root_path%\log\process.list
set timestamp=%date% %time%
set command_action=%1
set environment=%env%
set srvr_cnt=%s_cnt%
set starting_port=%port%
goto :eof

:parameter_validation
set param1=%1
set param2=%2
set param3=%3
set param4=%4
set action_list=Start Stop Status Restart Help
set env_list=production development test
set error_list=
set command_action=
set env=
set s_cnt=
set port=
if /i "%param1%"=="stop" goto :eof
if /i "%param1%"=="status" goto :eof
if /i "%param1%"=="help" goto :eof
:: Validate action
if "%param1%"=="" (
  set error_list=%error_list% 1
) else (
  for %%A in (%action_list%) do if /i "%param1%"=="%%A" set command_action=%%A
  if "!command_action!"=="" set error_list=%error_list% 2
)
:: Validate environment
if "%param2%"=="" (
  set env=development
) else (
  for %%A in (%env_list%) do if /i "%param2%"=="%%A" set env=%%A
  if "!env!"=="" set error_list=%error_list% 3
)
:: If we are restarting, then we don't need parameters 3 and 4
if /i "%param1%"=="restart" goto :eof
:: Set server count or default to 5
if "%param3%"=="" (
  set /a s_cnt=5
) else (
  call :validate_number %param3%
  set /a s_cnt=%param3%
)
:: Set starting port or default to 3000
if "%param4%"=="" (
  set /a port=3000
) else (
  call :validate_number %param4%
  set /a port=%param4%
)
goto :eof

:validate_number
if "%1"=="" (
  set error_list=%error_list% 21
)
set /a number=%1
if %number% LSS 1 (
  set error_list=%error_list% 22
)
if not %number% GEQ 1 (
  set error_list=%error_list% 23
)
goto :eof

:: -------------------- Print Help -------------------- ::
:help
echo "Starts, stops and restarts a Thin cluster. Number of servers can be supplied if used with start command."
echo "Restart will restart all currently running thin servers one at a time. There should always be a thin server"
echo "available to server at all times during a restart."
echo "Environment is optional and defaults to development."
echo "Number of server is optional and defaults to 5."
echo "Starting port is optional and defaults to 3000."
echo.
echo "Usage: thin_manager action [env [n [p]]]"
echo.
echo "Example 1: thin_manager start 5"
echo     "Starts a cluster of 5 servers on ports 3000, 3001, 3002, 3003, 3004 in development mode."
echo.
echo "Example 2: thin_manager start production 3 5000"
echo     "Starts a cluster of 3 server on ports 5000, 5001, 5002 in production mode."
echo.
echo "Example 3: thin_manager stop"
echo     "Stops all thin servers in the cluster."
echo.
echo "Example 4: thin_manager status"
echo     "Displays currently running thin servers."
echo.
echo "Example 5: thin_manager restart production"
echo     "Recycle all thin instance 1 at a time in production environment"
echo.
echo "Example 6: thin_manager help"
echo     "Displays this help message."
echo.
echo.
echo "Parameter Options:"
echo     "action: Start,Stop,Restart,Status,Help."
echo     "env: Environment mode to start the thin servers in."
echo     "n: Positive integer, where n is the number of servers. Default=5"
echo     "p: [optional] Starting port number. Default=3000."
echo.
echo.
goto :end

:: -------------------- Error Reporting -------------------- ::
:error
echo "error list [%error_list%]"
echo "error list [%error_list%]">> "%error_log%"
echo "%timestamp% parameters passed: %1 %2 %3 %4"
echo "%timestamp% parameters passed: %1 %2 %3 %4">> "%error_log%"
for %%A in (%error_list%) do call :error_message %%A
echo "----- End Of Errors -----"
echo "----- End Of Errors -----">> "%error_log%"
echo.>> "%error_log%"
goto :end

:error_message
set error_number=%1
if "%error_number%"=="1" (
  echo "*** ERROR *** No action parameter was passed."
  echo "*** ERROR *** No action parameter was passed.">> "%error_log%"
)
if "%error_number%"=="2" (
  echo "*** ERROR *** Action called was not one of the allowed options [start,stop,status,restart,help]."
  echo "*** ERROR *** Action called was not one of the allowed options [start,stop,status,restart,help].">> "%error_log%"
)
if "%error_number%"=="3" (
  echo "*** ERROR *** Runtime environment set was not a valid environment [production,development,test]."
  echo "*** ERROR *** Runtime environment set was not a valid environment [production,development,test].">> "%error_log%"
)
if "%error_number%"=="21" (
  echo "*** ERROR *** Server count and port number must be specified."
  echo "*** ERROR *** Server count and port number must be specified.">> "%error_log%"
)
if "%error_number%"=="22" (
  echo "*** ERROR *** Server count and port number must be greater than 0."
  echo "*** ERROR *** Server count and port number must be greater than 0.">> "%error_log%"
)
if "%error_number%"=="23" (
  echo "*** ERROR *** Server count and port number must be an integer."
  echo "*** ERROR *** Server count and port number must be an integer.">> "%error_log%"
)
if "%error_number%"=="31" (
  echo "*** ERROR *** Failed to stop cluster."
  echo "*** ERROR *** Failed to stop cluster.">> "%error_log%"
)
if "%error_number%"=="41" (
  echo "*** ERROR *** Old cmd_thin_port_*.exe file found."
  echo "*** ERROR *** Old cmd_thin_port_*.exe file found.">> "%error_log%"
)
if "%error_number%"=="42" (
  echo "*** ERROR *** Failed to create a copy of cmd.exe file."
  echo "*** ERROR *** Failed to create a copy of cmd.exe file.">> "%error_log%"
)
if "%error_number%"=="43" (
  echo "*** ERROR *** Unable to find cmd.exe copy to delete."
  echo "*** ERROR *** Unable to find cmd.exe copy to delete.">> "%error_log%"
)
if "%error_number%"=="44" (
  echo "*** ERROR *** Failed to delete copy of cmd.exe file."
  echo "*** ERROR *** Failed to delete copy of cmd.exe file.">> "%error_log%"
)
if "%error_number%"=="99" (
  echo "*** ERROR *** Unexpected error."
  echo "*** ERROR *** Unexpected error.">> "%error_log%"
)
goto :eof

:: -------------------- Tear Down -------------------- ::
:end
echo "Program finished at %date% %time%"
echo "Program finished at %date% %time%">> "%logfile%"
echo.>> "%logfile%"
endlocal

