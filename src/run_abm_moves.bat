@echo off

set PROJECT_PATH=D:/PAG/client_pag_exploratory

cd /d %PROJECT_PATH%/src

call run_pag_travel_model.bat
call run_moves_input.bat
call run_python_moves.bat

pause