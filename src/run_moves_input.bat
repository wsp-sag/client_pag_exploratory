:: transcad path
SET TC_PATH=C:\\Program Files\\TransCAD 6.0\\

:: python path
SET PYTHON_PATH=C:\\Python27\\ArcGIS10.6\\python.exe

:: project path
SET PROJECT_PATH=D:\\PAG\\client_pag_exploratory

:: path for gisdk code
SET GISDK_CODE_PATH=%PROJECT_PATH%\\src

:: path where to put compiled UI
SET COMPILED_UI_PATH=%PROJECT_PATH%\\src\\UI

:: gisdk list file name
SET RSCFILE=inputs_MOVES_HS.rsc

:: gisdk macro name for entry
SET ENTRY_MACRO_NAME="MOVES_input"

:: path where to save output summaries
SET OUTPUT_PATH=%PROJECT_PATH%\\data\\interim

:: path where the abm model folder is located
SET MODEL_FOLDER=D:\\PAG\\client_pag_abm_development\\models\\abm

::model iteration number for network summaries
SET MODEL_ITERATION="3"



:: compile the rsc
"%TC_PATH%\rscc.exe" -c -u "%COMPILED_UI_PATH%\moves_input.dbd" "%GISDK_CODE_PATH%\%RSCFILE%"

:: run macro
cd /d %PROJECT_PATH%/src

%PYTHON_PATH% run_input_moves_hs.py "%MODEL_FOLDER%" "%OUTPUT_PATH%" %MODEL_ITERATION% "%COMPILED_UI_PATH%\\moves_input" %ENTRY_MACRO_NAME%

pause