rem Set the path to the Rscript executable
set PYTHON_PATH=C:/Python27/ArcGIS10.6/python.exe

rem Set the path to the project folder
set PROJECT_PATH=D:/PAG/client_pag_exploratory

rem Set scenario year
set YEAR=2035

rem Set scenario name
set SCENARIO_NAME=test

rem Set input excel file path
set INPUT_EXCEL_FILE_PATH=2035_moves4_test.xlsx

rem Set input excel file path copy
set INPUT_EXCEL_FILE_COPY_PATH=2035_moves4_test_copy.xlsx

rem Set data interim folder directory
set DATA_DIR="%PROJECT_PATH%/data/interim/"

cd /d %DATA_DIR%

rem copy the spreadsheet to another file 
copy %INPUT_EXCEL_FILE_PATH% %INPUT_EXCEL_FILE_COPY_PATH%

cd /d %PROJECT_PATH%/src

rem Set the path to the R script to execute
set PYTHON_FILE=copy_outputs_to_excel.py

rem execute the python script to copy the outputs to excel file
%PYTHON_PATH% %PYTHON_FILE% %INPUT_EXCEL_FILE_COPY_PATH% %DATA_DIR% %YEAR%

pause