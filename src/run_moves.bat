set moves_dir=C:/Users/Public/EPA/MOVES/MOVES4.0
set input_xml_file=D:/PAG/client_pag_exploratory/data/interim\2035_moves4_test.xml
set input_spec_file=D:/PAG/client_pag_exploratory/data/interim\2035_moves4_test.mrs


cd /d "%moves_dir%"
call setenv.bat

call ant dbimporter -Dimport="%input_xml_file%"

call ant run -Drunspec="%input_spec_file%"
