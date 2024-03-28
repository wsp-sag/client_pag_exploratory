import sys, caliper

if __name__ == "__main__":

    args = sys.argv

    ui_file = args[1]
    macro_name = args[2]  

    dk = caliper.Gisdk('TransCAD')

    dk.apply(macro_name, ui_file)
    
    dk.Close()


