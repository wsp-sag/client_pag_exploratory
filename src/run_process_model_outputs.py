import sys, caliper

if __name__ == "__main__":

    args = sys.argv

    macro_name = args[1]  
    ui_dbd = args[2]
    model_folder = args[3]
    output_folder = args[4]
    iteration = args[5]

    dk = caliper.Gisdk('TransCAD')

    dk.RunMacro(macro_name, ui_dbd, model_folder, output_folder, iteration)
    
    dk.Close()
