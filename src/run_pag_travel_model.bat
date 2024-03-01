:: transcad path
SET TC_PATH=C:\Program Files\TransCAD 6.0

:: path for gisdk code
SET GISDK_CODE_PATH=D:\PAG\client_pag_abm_development\models\abm\gisdk

:: path where to put compiled UI
SET COMPILED_UI_PATH=D:\PAG\client_pag_abm_development\models\abm\ui

:: gisdk list file name
SET LSTFILE=phoenix_ui.lst

:: gisdk macro name for entry
SET ENTRY_MACRO_NAME="Run Model"

:: compile the rsc
"%TC_PATH%\rscc.exe" -c -u "%COMPILED_UI_PATH%\phoenix_ui.dbd" "%GISDK_CODE_PATH%\%LSTFILE%"

:: run macro
"%TC_PATH%\tcw.exe" -q -a "%COMPILED_UI_PATH%\phoenix_ui.dbd" -ai %ENTRY_MACRO_NAME% 

pause