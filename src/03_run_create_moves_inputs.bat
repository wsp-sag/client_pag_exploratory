@echo off

set PROJECT_PATH=D:/PAG/client_pag_exploratory

set PYTHON_PATH=C:/Python27/ArcGIS10.6/python.exe

cd /d %PROJECT_PATH%/src

%PYTHON_PATH% %PROJECT_PATH%/src/create_moves_inputs.py

pause