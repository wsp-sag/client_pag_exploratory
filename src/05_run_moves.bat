rem Set the path to the Rscript executable
set RSCRIPT="C:\Program Files\R\R-4.0.5\bin\Rscript.exe"

rem Set the path to the project folder
set PROJECT_PATH="D:/PAG/client_pag_exploratory"

rem Set scenario year
set YEAR=2035

rem Set scenario name
set SCENARIO_NAME=test
cd /d %PROJECT_PATH%/src

rem Set the path to the R script to execute
set RSCRIPT_FILE="write_moves_input_database_xml.R"

rem Execute the R script
%RSCRIPT% %RSCRIPT_FILE%

rem Set the path to the R script to execute
set RSCRIPT_FILE="write_moves_run_spec.R"

rem Execute the R script
%RSCRIPT% %RSCRIPT_FILE%

::set RunSpecDir=%PROJECT_PATH%/src
::
::set MOVESDir=C:\Users\Public\EPA\MOVES\MOVES4.0
::
::cd /d %MOVESDir%
::call setenv.bat
::
::call ant dbimporter -Dimport="%RunSpecDir%\%YEAR%_moves4_%SCENARIO_NAME%.xml"
::
::call ant run -Drunspec="%RunSpecDir%\%YEAR%_moves4_%SCENARIO_NAME%.mrs"
::
::rem Set the path to the R script to execute
::set RSCRIPT_FILE="process_moves_outputs.R"
::
::rem Execute the R script
::%RSCRIPT% %RSCRIPT_FILE%

cd /d %RunSpecDir%

pause