import sys, caliper

if __name__ == "__main__":

    args = sys.argv

    project_folder = args[1]
    interim_folder = args[2]
    model_iteration = args[3]
    ui_file = args[4]
    macro_name = args[5]  

    dk = caliper.Gisdk('TransCAD')

    dk.RunMacro(macro_name, ui_file, project_folder, interim_folder, model_iteration)



