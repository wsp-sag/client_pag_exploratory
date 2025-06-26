/* This is the main script of the Model. Its name follows the naming convention described in the coding standards.
   Revise the parameters in the macro "Phoenix Model Version" when establishing a different version.

   This script includes the model interface (dialog box "Phoenix Model") that calls the step macros, as well as
   a few utility macros that are used during the process of model run.

   The step macros are found in individual resource files, including: Initialization.rsc, TripGeneration.rsc,
   NetworkSkimming.rsc, TripDistribution.rsc, ModalSplit.rsc, HighwayAssignment.rsc and Utilities.rsc.

   The revision history is listed at the bottom of this script. It should be updated every time when any change
   is occured to the scripts.
*/

//Record the model version and required version of TransCAD
Macro "Phoenix Model Version"
    shared batchfile_name
    project_version_number = 20190819
    required_tc_build   = 9015
    required_tc_version = 6.0

    batchfile_name = i2s(project_version_number) + "_15_18_16b_16b_PopSyn3_CTRAMP2_TC60.rsc"

    return({project_version_number, required_tc_build, required_tc_version})
EndMacro

//Model Interface and macros to run steps and feedback
DBox "Phoenix Model"
    right, center toolbox NoKeyboard
    title: "PAG ABM 2015"

    init do
        shared  project_dbox, scenario_dbox, ui_file,  // these three variables should not be set to null in closing()
                scen_data_dir, project_name, prj_version, batchfile_name, ScenName,
                BatchTimerOpts, BatchOptions, MacroInfo, prj_dry_run, StepFlagVec, loop, loop_n,
                growth_factor, SkimExZone

        //The path and name of the .ini file. When the file is in TransCAD installation folder, its path is not required.
        ini_file = "PAGABMPATH\\phoenix20170523.ini"

        BatchTimerOpts.NoBatchTiming = True
        BatchOptions.MatrixCompression = True

        {mod_file, ui_file, scenario_file, scen_data_dir} = RunMacro("TCP Get Project Files", ini_file, &errMsg)
        if mod_file = null then do ShowMessage(errMsg) return() end

        SkimExZone = True

        project_name = "Phoenix Model"
        {MacroInfo, Args, Opts, VarInfo} = RunMacro("TCP Read Planning Model", mod_file, scen_data_dir)
        if MacroInfo = null then return()
        {StepMacro, StepTitle, StepFlag} = MacroInfo
        StageName = Args[1]
        stages = StageName.length

        if !RunMacro("TCP Update Scenarios in Project Dbox", scenario_file, &ScenArr, &ScenSel, &ScenNames, stages, 0, Args) then
            return()

        if !RunMacro("TCP Convert Step Flags", StepFlag, StageName, &StepFlagVec) then return()
        Runmacro("feedback init")

        run_type = 1
        prj_dry_run = 0
        project_dbox = 1
        growth_factor = null
        enditem

    update do
        if project_dbox = -99 then
            runMacro("closing")
        else do
            if !RunMacro("TCP Update Scenarios in Project Dbox", scenario_file, &ScenArr, &ScenSel, &ScenNames, stages, 1, Args) then
                return()
            if cur_loop <= loop_n then StepFlag = StepFlagVec[cur_loop] else StepFlag = StepFlagVec[all_loops]
            end
        endItem

    close do RunMacro("closing") endItem

    button  2,0
    icons: "C:\\Program Files\\TransCAD 6.0\\bmp\\PAG.bmp", "bmp\\PAG.bmp"

    frame 0.5, 6.5, 39.0, 7.0 prompt: "Scenarios"
    Scroll List 1.5, 7.3, 37.0, 3.5 multiple list: ScenNames variable: ScenSel do
        RunMacro("TCP Save Scenario File", ScenArr, ScenSel, scenario_file)
        RunMacro("TCP Update Scenarios Show Array", ScenArr, ScenSel, stages)
        endItem
    button 2.5, 11.3, 35, 1.8 prompt: "Setup" do
        RunDbox("TCP Scenario dBox", scenario_file, scen_data_dir,, Args)
        enditem

    radio list  0.5, 14, 39.0, 6.3 prompt: "Run" variable: run_type
    radio button   2, 15.2 prompt: "Stage"
        help: "Check to run one stage"
    radio button  14, Same prompt: "Loop"
        help: "Check to run one loop"
    radio button  26, Same prompt: "All Loops"
        help: "Check to run all loops"
    popdown menu 28, 17.0, 10, 10 prompt: "Max. # of Feedback Loops"  list: MFB_List  variable: loop_n do
        RunMacro("update feedback")
        enditem
    popdown menu 28, 18.8, 10, 10 prompt: "Feedback Loop"  list: FB_List  variable: cur_loop do
        if cur_loop <= loop_n then StepFlag = StepFlagVec[cur_loop] else StepFlag = StepFlagVec[all_loops]
        enditem

    checkbox  2, Same, 7    prompt: "Dry Run" variable: prj_dry_run

    button "phoe_b1" 1, 21.3 icons: "bmp\\plansetup.bmp", "bmp\\plansetup.bmp", "bmp\\plansetup3.bmp" do cur_stage = 1  RunMacro("set steps") enditem
    button "phoenix1" After, Same, 18, 1.6 disabled prompt:StageName[1]  do cur_stage = 1  RunMacro("run stages") enditem
    button "phoe_v1" After, Same  icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 1) endItem

    button "phoe_b2" 1, 23.6 icons: "bmp\\planskim.bmp", "bmp\\planskim.bmp", "bmp\\planskim3.bmp" do cur_stage = 2  RunMacro("set steps") enditem
    button "phoenix2" After, Same, 18, 1.6 disabled prompt:StageName[2]  do cur_stage = 2  RunMacro("run stages") enditem
    button "phoe_v2" After, Same  icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 2) endItem

    button "phoe_b3" 1, 25.9 icons: "bmp\\accessibility.bmp", "bmp\\accessibility.bmp", "bmp\\accessibility.bmp" do cur_stage = 3  RunMacro("set steps") enditem
    button "phoenix3" After, Same, 18, 1.6 disabled prompt:StageName[3]  do cur_stage = 3  RunMacro("run stages") enditem
    button "phoe_v3" After, Same  icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 3) endItem

    button "phoe_b4" 1, 28.2 icons: "bmp\\popsyn.bmp", "bmp\\popsyn.bmp", "bmp\\popsyn.bmp" do cur_stage = 4  RunMacro("set steps") enditem
    button "phoenix4" After, Same, 18, 1.6 disabled prompt:StageName[4]  do cur_stage = 4  RunMacro("run stages") enditem
    button "phoe_v4" After, Same  icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 4) endItem

//    button "phoe_b5" 1, 30.5 icons: "bmp\\long_term.bmp", "bmp\\long_term.bmp", "bmp\\long_term.bmp" do cur_stage = 5  RunMacro("set steps") enditem
//    button "phoenix5" After, Same, 18, 1.6 disabled prompt:StageName[5]  do cur_stage = 5  RunMacro("run stages") enditem
//    button "phoe_v5" After, Same  icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 5) endItem
//    
//    button "phoe_b6" 1, 32.8 icons: "bmp\\special_events.bmp", "bmp\\special_events.bmp", "bmp\\special_events.bmp" do cur_stage = 6  RunMacro("set steps") enditem
//    button "phoenix6" After, Same, 18, 1.6 disabled prompt:StageName[6]  do cur_stage = 6  RunMacro("run stages") enditem
//    button "phoe_v6" After, Same  icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 6) endItem

    button "phoe_b5" 1, 30.5 icons: "bmp\\dot-density.bmp", "bmp\\dot-density.bmp", "bmp\\dot-density.bmp" do cur_stage = 5  RunMacro("set steps") enditem
    button "phoenix5" After, Same, 18, 1.6 disabled prompt:StageName[5]  do cur_stage = 5  RunMacro("run stages") enditem
    button "phoe_v5" After, Same  icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 5) endItem

//    button "phoe_b8" 1, 37.4 icons: "bmp\\tour_form.bmp", "bmp\\tour_form.bmp", "bmp\\tour_form.bmp" do cur_stage = 8  RunMacro("set steps") enditem
//    button "phoenix8" After, Same, 18, 1.6 disabled prompt:StageName[8]  do cur_stage = 8  RunMacro("run stages") enditem
//    button "phoe_v8" After, Same  icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 8) endItem
//
//    button "phoe_b9" 1, 39.7 icons: "bmp\\planmatrix_v3.bmp", "bmp\\planmatrix_v3.bmp", "bmp\\planmatrix_v3.bmp" do cur_stage = 9  RunMacro("set steps") enditem
//    button "phoenix9" After, Same, 18, 1.6 disabled prompt:StageName[9]  do cur_stage = 9 RunMacro("run stages") enditem
//    button "phoe_v9" After, Same  icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 9) endItem
//    
//    button "phoe_b10" 1, 42.0 icons: "bmp\\planmodesplit.bmp", "bmp\\planmodesplit.bmp", "bmp\\planmodesplit.bmp" do cur_stage = 10  RunMacro("set steps") enditem
//    button "phoenix10" After, Same, 18, 1.6 disabled prompt:StageName[10]  do cur_stage = 10  RunMacro("run stages") enditem
//    button "phoe_v10" After, Same  icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 10) endItem

    button "phoe_b6" 1, 32.8 icons: "bmp\\non_abm.bmp", "bmp\\non_abm.bmp", "bmp\\non_abm.bmp" do cur_stage = 6  RunMacro("set steps") enditem
    button "phoenix6" After, Same, 18, 1.6 disabled prompt:StageName[6]  do cur_stage = 6  RunMacro("run stages") enditem
    button "phoe_v6" After, Same  icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 6) endItem

    button "phoe_b7" 1, 35.1 icons: "bmp\\planassign.bmp", "bmp\\planassign.bmp", "bmp\\planassign.bmp" do cur_stage = 7  RunMacro("set steps") enditem
    button "phoenix7" After, Same, 18, 1.6 disabled prompt:StageName[7]  do cur_stage = 7  RunMacro("run stages") enditem
    button "phoe_v7" After, Same  icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 7) endItem

    button     1,  37.6, 37.7, 2  prompt: "Quit"      do RunMacro("closing") enditem
    button  same, After, 37.7, 2  prompt: "Utilities" do RunDBox("Phoenix Utilities", ScenSel, ScenArr) enditem

    text  29, After Variable: "v 0" + i2s(prj_version)

    Macro "set steps" do
        SetAlternateInterface()
        RunMacro("TCP Set Steps", StepTitle[cur_stage], &StepFlag[cur_stage])
        enditem

    Macro "run stages" do

        ScenName = ScenArr[ ScenSel[1] ][1]
        
        ModelLogFile = GetLogFileName()
        ModelReportFile = GetReportFileName()
        ModelLogFile_info = GetFileInfo(ModelLogFile)
        ModelReportFile_info = GetFileInfo(ModelReportFile)
        if ModelLogFile_info[6] > 1048576 then ResetLogFile()   //if larger than 1 MB (1048576 byte), clear it 3145728.
        if ModelReportFile_info[6] > 1048576 then ResetReportFile()   //if larger than 1 MB (1048576 byte), clear it 3145728.

        RunMacro("TCP Run Scen Stages", cur_stage, cur_loop, run_type, StepMacro, &StepFlag, ScenArr, ScenSel,)
        runstatus = "End"

        //Copy model report and log files to the scenario folder

        {Log_drive, Log_dir, log_name, } = SplitPath(ModelLogFile)
        {Rpt_drive, Rpt_dir, Rpt_Name, } = SplitPath(ModelReportFile)

        ModelLogDictFile = Log_drive + Log_dir + log_name + ".xsl"
        ModelReportDictFile = Rpt_drive + Rpt_dir + Rpt_Name + ".xsl"

        curtime = Substitute(right(GetDateAndTime(), 20), ":", "-",)

        CopyFile(ModelLogFile, scen_data_dir + log_name + " " + curtime + ".xml")
        CopyFile(ModelLogDictFile, scen_data_dir + log_name + ".xsl")
        CopyFile(ModelReportFile, scen_data_dir + Rpt_Name + " " + curtime + ".xml")
        CopyFile(ModelLogDictFile, scen_data_dir + Rpt_Name + ".xsl")
      
        if run_type = 3 then do   // if run loops
            RunMacro("Skim Matrix RMSE", ScenArr, ScenSel, cur_loop, loop_n)

            //Record model runs information on I drive
         /*   log_file_path = "I:\\00_ADMINISTRATION\\07 LOG OF ALL MODEL RUNS\\"
            log_file = log_file_path + "DO_NOT_MODIFY_TransCAD_model_runs.log"
            curtime = GetDateAndTime()
            ProgVer = GetProgram()
            log_rec = runstatus + "," + curtime + "," + GetEnvironmentVariable("USERNAME") + ","
                    + GetEnvironmentVariable("COMPUTERNAME") + "," + ScenName + "," + scen_data_dir + "," + batchfile_name
                    + "," + ProgVer[2] + " Version " + String(ProgVer[5]) + " Build " + String(ProgVer[4])
            logfile = OpenFile(log_file, "a")
            WriteLine(logfile, log_rec)
            CloseFile(logfile) */
        end

        growth_factor = null
        endItem

    Macro "closing" do
        scen_data_dir  = null
        project_name   = null
        prj_version    = null
        BatchTimerOpts = null
        BatchOptions   = null
        MacroInfo      = null
        prj_dry_run    = null
        StepFlagVec    = null
        loop           = null
        growth_factor  = null

        if RunMacro("TCP Close Project Dbox") = 1 then
            return()
        endItem

    Macro "feedback init" do
        all_loops = StepFlagVec.length    // max. # of feedback loops
        loop_n = all_loops - 1            // max. # of loops that can be chosen, excluding final-steps loop
        single_loop = 1
        Dim MFB_List[loop_n]
        for i = 1 to loop_n do MFB_List[i] = i end
        RunMacro("update feedback")
        enditem

    Macro "update feedback" do
        FB_List = Subarray(MFB_List, 1, loop_n) + {"Final"}
        cur_loop = 1
        StepFlag = StepFlagVec[cur_loop]
        enditem

EndDbox

// Macro written/needed for the automation task of uncertainty analysis work. 
Macro "Run_Model"
    shared scen_data_dir, batch_file_name, StepFlagVec, SkimExZone, loop, loop_n, Args

    RunMacro("TCB Init")

    SkimExZone = True
	
    //All feedback loops run
    run_type = 3 

    //The path and name of the .ini file. When the file is in TransCAD installation folder, its path is not required.
    ini_file = "PAGABMPATH\\phoenix20170523.ini"

    {mod_file, ui_file, scenario_file, scen_data_dir} = RunMacro("TCP Get Project Files", ini_file, &errMsg)
    if mod_file = null then do ShowMessage(errMsg) return() end

    {MacroInfo, Args, Opts, VarInfo} = RunMacro("TCP Read Planning Model", mod_file, scen_data_dir)
    if MacroInfo = null then return()
    
    {StepMacro, StepTitle, StepFlag} = MacroInfo
	StageName = Args[1]
                         // max. # of loops that can be chosen, can be 10
    if !RunMacro("TCP Convert Step Flags", StepFlag, StageName, &StepFlagVec) then return()
    
	// create Arguments needed to run Macros
	ScenArgs = null 
	for i = 2 to Args.length do 
	    array = Args[i]
		for a = 1 to array.length do 
		    if array[a] <> null then do 
			    for s = 1 to array[a].length do
				    name = array[a][s][1]
					value = array[a][s][2]
					ScenArgs.(name) = value	
				end
			end
		end
	end

    all_loops = StepFlagVec.length      // max. # of feedback loops
    loop_n = ScenArgs.[NUMBER OF FEEDBACK LOOPS]                         // max. # of loops that can be chosen, can be 10
    // feedback iteration loop
    for loop = 1 to (loop_n + 1) do 
        log_file = scen_data_dir + "logs\\model_run.log"
//		ShowMessage("Starting Iteration: " + i2s(loop))
		
		if loop <= loop_n then loop_str = "Loop " + String(loop) else loop_str = "Final"
		
		if loop <= loop_n then StepFlag = StepFlagVec[loop] else StepFlag = StepFlagVec[all_loops]

        ModelLogFile = GetLogFileName()
        ModelReportFile = GetReportFileName()
        ModelLogFile_info = GetFileInfo(ModelLogFile)
        ModelReportFile_info = GetFileInfo(ModelReportFile)
        if ModelLogFile_info[6] > 1048576 then ResetLogFile()   //if larger than 1 MB (1048576 byte), clear it 3145728.
        if ModelReportFile_info[6] > 1048576 then ResetReportFile()   //if larger than 1 MB (1048576 byte), clear it 3145728.

        // Stage Loop
        for cur_stage = 1 to StageName.length do 
            StageFlag = StepFlag[cur_stage]

            // sub-step loop
            for step = 1 to StageFlag.length do
                step_macro_name = StepMacro[cur_stage][step]
                if StageFlag[step] = 1 then do
				    if step_macro_name = "Copy Loop Output" then do 
//					    ShowMessage("Running Macro: " + step_macro_name + "iteration " + i2s(loop))
					end
					
					start_time = GetDateAndTime()
					RunMacro("Add Log", log_file, loop_str, StageName[cur_stage], step_macro_name, start_time, , )
					if loop > loop_n then do 
//					    ShowMessage("Running Macro: " + step_macro_name)
					end
					RunMacro(step_macro_name, ScenArgs)

	                end_time = GetDateAndTime()
					RunMacro("Update Log", log_file, loop_str, StageName[cur_stage], step_macro_name, start_time, end_time)
				end
            end
			
        end
		
		RunMacro("Close All")
    end
	
    //Copy model report and log files to the scenario folder
    {Log_drive, Log_dir, log_name, } = SplitPath(ModelLogFile)
    {Rpt_drive, Rpt_dir, Rpt_Name, } = SplitPath(ModelReportFile)
    ModelLogDictFile = Log_drive + Log_dir + log_name + ".xsl"
    ModelReportDictFile = Rpt_drive + Rpt_dir + Rpt_Name + ".xsl"
    curtime = Substitute(right(GetDateAndTime(), 20), ":", "-",)
    CopyFile(ModelLogFile, scen_data_dir + log_name + " " + curtime + ".xml")
    CopyFile(ModelLogDictFile, scen_data_dir + log_name + ".xsl")
    CopyFile(ModelReportFile, scen_data_dir + Rpt_Name + " " + curtime + ".xml")
    CopyFile(ModelLogDictFile, scen_data_dir + Rpt_Name + ".xsl")
	
	Exit()
	
EndMacro

// report RMSE between skim
Macro "Skim Matrix RMSE" (ScenArr, ScenSel, first_loop, last_loop)
    shared  batch_run_mode

    if first_loop >= last_loop then
        goto quit
    Args = RunMacro("TCP Convert to Argument Options", ScenArr[ScenSel[1]][5])
    skim_mat = Args.[PK LOV Skim Matrix]
    if GetFileInfo(skim_mat) = null then   // if transit skim matrix not created yet
        goto quit
    batch_run_mode = 1
    rmse_mat = GetTempFileName("*.mtx")
    Tmp = RunMacro("TCB Create MCs", rmse_mat, {skim_mat}, {"Value"})
    rmse_mc = Tmp[1][2]
    ok = (rmse_mc <> null)
    if !ok then
        goto quit
    rmse_m = rmse_mc.mat

    {drive, dir, fname, ext} = SplitPath(skim_mat)
    head = drive + dir + fname + "_"
    for loop = first_loop to last_loop - 1 do
            // get first matrix
        if loop = first_loop then do
            mat1 = head + i2s(loop) + ext
            m1 = RunMacro("TCB OpenMatrix", mat1,)
            ok = (m1 <> null) if !ok then goto quit
            mc1 = CreateMatrixCurrency(m1, "Time",,,)
          end
        else do
            mat1 = mat2
            m1 = m2
            mc1 = mc2
          end
            // get second matrix
        mat2 = head + i2s(loop + 1) + ext
        m2 = RunMacro("TCB OpenMatrix", mat2,)
        ok = (m2 <> null) if !ok then goto quit
        mc2 = CreateMatrixCurrency(m2, "Time",,,)

        sum1 = MatrixStatistics(m1, {{"Tables", {"Time"}}})
        sum2 = MatrixStatistics(m2, {{"Tables", {"Time"}}})
        rmse_mc := Pow(mc1 - mc2, 2)
        rmse_sum = MatrixStatistics(rmse_m, {{"Tables", {"Value"}}})
        sum_sq_chg = rmse_sum.Value.Sum
        cell_n = rmse_sum.VALUE.Count
        sum_flow = sum1.("Time").Sum
        od_rmse = 100 * Sqrt(sum_sq_chg / (cell_n - 1)) * cell_n / sum_flow
        rmse_mc := abs(mc1 - mc2)
        rmse_sum = MatrixStatistics(rmse_m, {{"Tables", {"VALUE"}}})
        chg = rmse_sum.VALUE.Sum / sum_flow * 100
        AppendToReportFile(3, "Iteration " + i2s(loop+1) + " RMSE: LOV skim matrix = " + String(od_rmse) +
                                                           " (Relative Change = " + String(chg) + "%)")
      end

    ok = 1
    quit:
    RunMacro("TCU Delete Files", {rmse_mat})
    batch_run_mode = 0
    return(ok)
EndMacro

/*------------------**
** Secondary MACROS **
**------------------*/

/*
// add a new and expanded index to matrix mapping zone group to zone id
Macro "Matrix Add Group-to-Zone Index" (Args, mat)
        // inputs
    db_file = Args.[Highway DB]
    group_tb = Args.[Zone Group Table]      // zone-to-zone group equivalent table

    {node_lyr,} = RunMacro("TCB Add DB Layers", db_file,,)
    if node_lyr = null then goto quit
    cent_qry = "Select * where Centroid <> null"        //ExSkim

    {_Flds,} = GetFields(node_lyr, "All")
    //if !ArrayPosition(_Flds, {"Group"},) then do                // if group field not exists yet
        NewFlds = {{"Group", "integer"}}                            // specify new field
        ok = RunMacro("TCB Add View Fields", {node_lyr, NewFlds})   // add new field
        if !ok then goto quit
            // assign zone group ID's
        group_vw = RunMacro("TCB OpenTable",,, {group_tb})
        ok = (group_vw <> null) if !ok then goto quit
        jvw = JoinViews("jvw", "["+node_lyr + "].ID", "["+group_vw + "].ZONE_ID",)
        SetView(jvw)
        n = SelectByQuery("centroids", "Several", cent_qry,)
        vw_set = jvw + "|centroids"
        group_v = GetDataVector(vw_set, "GROUP_ID",)
        SetDataVector(vw_set, "GROUP", group_v,)
        CloseView(jvw)
      //end

        // create expanded zone-based index for penalty matrix
    midx = "Zone"
    {RIdxs,} = GetMatrixIndexNames(mat)
    if ArrayPosition(RIdxs, {midx},) then                     // if index already exists
        DeleteMatrixIndex(mat, midx)
        // create matrix index mapping districts to zones
    SetLayer(node_lyr)
    n = SelectByQuery("centroids", "Several", cent_qry,)
    vw_set = node_lyr + "|centroids"
    CreateMatrixIndexEx(midx, mat, "Both", vw_set, "Group", "ID",)

    ok = 1
    quit:
    return(ok)
EndMacro
*/

// return a matrix currency statistics
Macro "Matrix Statistics"(mc, statistics)
    row_vec = GetMatrixVector(mc, {{"Marginal", "Row " + statistics}})
    val = VectorStatistic(row_vec, statistics,)
    return(val)
EndMacro

// create temporary or output matrix
Macro "Create Matrix" (Args, mat_file, label, core_list, zone_type)
    if zone_type = "real" then do   //Real zones according to TAZ file
        zone_tb = Args.[Land Use Table]
        zone_vw = RunMacro("TCB OpenTable",,, {zone_tb})
        if zone_vw = null then goto quit
        vw_set = zone_vw + "|"
        id_fld = "ZONE"
      end
    else if zone_type = "all" then do     // "all", including dummy centroid nodes
        db_file = Args.[Highway DB]
        {node_lyr,} = RunMacro("TCB Add DB Layers", db_file,,)
        if node_lyr = null then goto quit
        SetLayer(node_lyr)
        n = SelectByQuery("centroids", "Several", "Select * where Centroid <> null & ID > 100",)
        if n < 1 then goto quit
        vw_set = node_lyr + "|centroids"
        id_fld = "ID"
      end
    else if zone_type = "real+x" then do     // "real+x", including external but no dummy centroids
        db_file = Args.[Highway DB]
        {node_lyr,} = RunMacro("TCB Add DB Layers", db_file,,)
        if node_lyr = null then goto quit
        SetLayer(node_lyr)
        n = SelectByQuery("centroids", "Several", "Select * where Centroid <> null",)   //ExSkim
        if n < 1 then goto quit
        vw_set = node_lyr + "|centroids"
        id_fld = "ID"
      end

        // create core names
    Arr = ParseString(core_list, ",")
    Cores = ""
    for i = 1 to Arr.length do
        Arr2 = ParseString(Arr[i], "-")
        if Arr2.length = 1 then  do               // if a scalar
           if Value(Arr[i]) > 0 then do
              Cores = Cores + {"mf" + Arr[i]}
           end
           else do
              Cores = Cores + {Arr[i]}
           end
        end
        else do                                 // if a range
            first = s2i(Arr2[1])
            last = s2i(Arr2[2])
            for j = first to last do
                Cores = Cores + {"mf" + i2s(j)}
              end
          end
      end

    Opts = null
    Opts.[File Name] = mat_file
    Opts.[Label] = label
    Opts.[Type] = "Float"
    Opts.[Tables] = Cores
    Opts.[Do Not Initialize] = "Yes"
    Opts.Compression = 1
    mat = CreateMatrix({vw_set, id_fld, "RCIndex"},, Opts)
    if mat = null then goto quit
    mc = CreateMatrixCurrency(mat, Cores[1],,,)
    mc := 0
    return(1)

   quit:
    RunMacro("TCB Error", "Error creating matrix " + mat_file)
    return(0)
endMacro


// add to a matrix an index for internal zones
Macro "add matrix index" (Args, mat, type, idx_name, index_type)
    db_file = Args.[Highway DB]

    {node_lyr,} = RunMacro("TCB Add DB Layers", db_file,,)
    ok = (node_lyr <> null)     if !ok then goto quit

    m = RunMacro("TCB OpenMatrix", mat,)
    ok = (m <> null)  if !ok then goto quit

    type = Lower(type)
    cent_qry = "Select * where Centroid <> null"        // this is for type = "all"
    if Lower(type) = "int+ext" then   //Modified for zone expansion by HZ
        cent_qry = cent_qry
    else if Lower(type) = "external" then
        cent_qry = cent_qry + " & ID <= 100"
    else if Lower(type) = "internal" then
        cent_qry = cent_qry + " & ID > 100"

    SetLayer(node_lyr)
    n = SelectByQuery(idx_name, "Several", cent_qry,)
    vw_set = node_lyr + "|" + idx_name
    Opts = {{"Allow non-matrix entries", "True"}}

    if Lower(index_type) = "both" then   //Modified for zone expansion by HZ
       CreateMatrixIndexEx(idx_name, m, "Both", vw_set, "ID", "ID", Opts)
    else if Lower(index_type) = "row" then
       CreateMatrixIndexEx(idx_name, m, "Row", vw_set, "ID", "ID", Opts)
    else if Lower(index_type) = "column" then
       CreateMatrixIndexEx(idx_name, m, "Column", vw_set, "ID", "ID", Opts)

    quit:
    return(ok)
EndMacro

//*************************************************************
//
// A utility macro that will close all open map windows
//
//*************************************************************
Macro "Close All"
    // RunMacro("TCB Init")
    maps = GetMapNames()

    if(maps = null) then goto view
    for i = 1 to maps.length do
      CloseMap(maps[i])
    end

    view:
    views = GetViewNames()
    if(views = null) then goto quit
    while (views <> null) do
        CloseView(views[1])
        views = GetViewNames()
    end

    quit:
    return(RunMacro("G30 File Close All"))
    Return(1)
EndMacro



Macro "File Prep"(Args)
//Prepare Input And Blank Output Files And Matrices
    Shared prj_dry_run  if prj_dry_run then return(1)
    Shared  scen_data_dir, java64path, tc6path

    db_file = Args.[Highway DB]
    {node_lyr,} = RunMacro("TCB Add DB Layers", db_file,,)
    if node_lyr = null then goto quit
    SetLayer(node_lyr)
    query = "Select * where Centroid = 'X'"  //Modified for zone expansion by HZ
    n = SelectByQuery("centroid", "Several", query,)

    if n > 0 then do
        vw_set = node_lyr + "|centroid"
        ID_v = GetDataVector(vw_set, "ID",{{"Sort Order", {{"ID", "Ascending"}}}})
    end

// create All Zones Table all_zones.bin
    zn_tb = Args.[All Zones Table]          // table of internal and external zones
    zn_vw = CreateTable("zn_tb",zn_tb, "FFB", {{"ID", "Integer", 4, null, "No"}})

    for i = 1 to n do
      rh = AddRecords(zn_vw, {"ID"},{{ i} }, null)
    end

    SetDataVector(zn_vw+"|", "ID", ID_v,{{"Sort Order", {{"ID", "Ascending"}}}})
    CloseView(zn_vw)

// create FinalBalancedPNAs.bin for truck model
    FinalBalancedPNAs_tb = Args.[FinalBalancedPNAs]          // table of FinalBalancedPNAs
    FinalBalancedPNAs_vw = CreateTable("FinalBalancedPNAs_tb",FinalBalancedPNAs_tb, "FFB",{
                           {"ID", "Integer", 4, null, "No"},
                           {"CG1P", "Real", 8, 2, "No"},
                           {"CG2P", "Real", 8, 2, "No"},
                           {"CG3P", "Real", 8, 2, "No"},
                           {"CG4P", "Real", 8, 2, "No"},
                           {"CG5P", "Real", 8, 2, "No"},
                           {"CG6P", "Real", 8, 2, "No"},
                           {"CG7P", "Real", 8, 2, "No"},
                           {"CG8P", "Real", 8, 2, "No"},
                           {"CG9P", "Real", 8, 2, "No"},
                           {"CG1A", "Real", 8, 2, "No"},
                           {"CG2A", "Real", 8, 2, "No"},
                           {"CG3A", "Real", 8, 2, "No"},
                           {"CG4A", "Real", 8, 2, "No"},
                           {"CG5A", "Real", 8, 2, "No"},
                           {"CG6A", "Real", 8, 2, "No"},
                           {"CG7A", "Real", 8, 2, "No"},
                           {"CG8A", "Real", 8, 2, "No"},
                           {"CG9A", "Real", 8, 2, "No"}})

    for i = 1 to n do
      rh = AddRecords(FinalBalancedPNAs_vw, {"ID", "CG1P", "CG2P", "CG3P", "CG4P", "CG5P", "CG6P",
                                             "CG7P", "CG8P", "CG9P", "CG1A", "CG2A", "CG3A", "CG4A",
                                             "CG5A", "CG6A", "CG7A", "CG8A", "CG9A"},{{ null, null, null,
                                             null, null, null, null, null, null, null, null, null, null,
                                             null, null, null, null, null, null}}, null)
    end

    SetDataVector(FinalBalancedPNAs_vw+"|", "ID", ID_v,)
    CloseView(FinalBalancedPNAs_vw)

    query_int = "Select * where Centroid = 'X' & ID > 100"  //Internal centroids Modified for zone expansion by HZ
    n_int = SelectByQuery("int_centroid", "Several", query_int,)

    if n_int > 0 then do
        vw_set = node_lyr + "|int_centroid"
        ID_int_v = GetDataVector(vw_set, "ID",{{"Sort Order", {{"ID", "Ascending"}}}})
    end

// create PNAsByCG.bin for truck model
    PNAsByCG_tb = Args.[PNAsByCG]          // table of PNAsByCG
    PNAsByCG_vw = CreateTable("PNAsByCG_tb", PNAsByCG_tb, "FFB",{
                           {"TAZ", "Integer", 9, null, "No"},
                           {"CG1P", "Real", 8, 2, "No"},
                           {"CG2P", "Real", 8, 2, "No"},
                           {"CG3P", "Real", 8, 2, "No"},
                           {"CG4P", "Real", 8, 2, "No"},
                           {"CG5P", "Real", 8, 2, "No"},
                           {"CG6P", "Real", 8, 2, "No"},
                           {"CG7P", "Real", 8, 2, "No"},
                           {"CG8P", "Real", 8, 2, "No"},
                           {"CG9P", "Real", 8, 2, "No"},
                           {"CG1A", "Real", 8, 2, "No"},
                           {"CG2A", "Real", 8, 2, "No"},
                           {"CG3A", "Real", 8, 2, "No"},
                           {"CG4A", "Real", 8, 2, "No"},
                           {"CG5A", "Real", 8, 2, "No"},
                           {"CG6A", "Real", 8, 2, "No"},
                           {"CG7A", "Real", 8, 2, "No"},
                           {"CG8A", "Real", 8, 2, "No"},
                           {"CG9A", "Real", 8, 2, "No"}})

    for i = 1 to n_int do
      rh = AddRecords(PNAsByCG_vw, {"TAZ", "CG1P", "CG2P", "CG3P", "CG4P", "CG5P", "CG6P",
                                   "CG7P", "CG8P", "CG9P", "CG1A", "CG2A", "CG3A", "CG4A",
                                   "CG5A", "CG6A", "CG7A", "CG8A", "CG9A"},{{ null, null, null,
                                   null, null, null, null, null, null, null, null, null, null,
                                   null, null, null, null, null, null}}, null)
    end

    SetDataVector(PNAsByCG_vw+"|", "TAZ", ID_int_v,)
    CloseView(PNAsByCG_vw)

// create FINALPNASBYCG.bin for truck model
    FINALPNASBYCG_tb = Args.[FINALPNASBYCG]          // table of FINALPNASBYCG
    //CopyFile(PNAsByCG_tb, FINALPNASBYCG_tb)      // copy PNAsByCG_tb to FINALPNASBYCG
    CopyTableFiles(null, "FFB", PNAsByCG_tb, null, FINALPNASBYCG_tb, null)


// create BalancedPnAs.bin for truck model
    BalancedPnAs_tb = Args.[BalancedPnAs]          // table of BalancedPnAs
    //CopyFile(PNAsByCG_tb, BalancedPnAs_tb)      // copy PNAsByCG_tb to BalancedPnAs
    CopyTableFiles(null, "FFB", PNAsByCG_tb, null, BalancedPnAs_tb, null)

    closeok = RunMacro("G30 File Close All")

/* Replaced by destination choice model
// create ASU PA Matrix
    asu_pa_mat = Args.[ASU PA Matrix]       // ASU trip PA matrix
    ok = RunMacro("Create Matrix", Args, asu_pa_mat, "ASU PA Matrix", "160, 157-159", "real+x")           //ExSkim
    if !ok then goto quit

// create OTHER PA Matrix
    oth_pa_mat = Args.[OTHER PA Matrix]       // Other PA matrix (HBS,HBSC,HBO,NHBW,NHBO)
    ok = RunMacro("Create Matrix", Args, oth_pa_mat, "OTHER PA Matrix", "337-342,166-167", "real+x")    //ExSkim
    if !ok then goto quit
*/

//create RMSE skims Matrix
    rmse_skim_mat = scen_data_dir+"\\out\\RMSE_Skim.mtx"           // matrix to calculate highway od trip RMSE
    ok = RunMacro("Create Matrix", Args, rmse_skim_mat, "RMSE Matrix", "squared changes", "real+x")   //ExSkim
    if !ok then goto quit
    
// create RMSE Matrix
    rmse_mat = Args.[RMSE Matrix]           // matrix to calculate highway od trip RMSE
    ok = RunMacro("Create Matrix", Args, rmse_mat, "RMSE Matrix", "302,squared changes", "real+x")   //ExSkim
    if !ok then goto quit
/*
// create XI Trk PA Matrix
    XI_pa_mat = Args.[XI Trk PA Matrix]           // External-Internal Truck PA Matrix
    ok = RunMacro("Create Matrix", Args, XI_pa_mat, "XI Trk PA Matrix", "HT,MT,OV,Total", "real+x")    //ExSkim
    if !ok then goto quit

// create empty matrix for internal truck trip distribution
    empty_mat  = Args.[empty matrix]       // Internal Truck Trip distribution matrix
    ok = RunMacro("Create Matrix", Args, empty_mat, "dummy", "dummy", "real+x")                //ExSkim
    if !ok then goto quit
*/
// create dummy matrices
    dummy_in_mat = scen_data_dir + "\\out\\dummy_in.mtx"        // dummy_in.mtx
    ok = RunMacro("Create Matrix", Args, dummy_in_mat, "Dummy", "zeros", "real+x")
    if !ok then goto quit

    dummy_out_mat = scen_data_dir + "\\out\\dummy_out.mtx"        // dummy_out.mtx
    CopyFile(dummy_in_mat, dummy_out_mat)      // copy dummy_in.mtx to dummy_out.mtx

// Create the empty file used in Autoown
    empty_file = OpenFile(scen_data_dir + "\\out\\empty", "a")
    WriteLine(empty_file, "")
    CloseFile(empty_file)

//Create DummyExTrkOD.mtx used in truck model
    DummyExTrkOD_mat = Args.[DummyExTrkOD]       // External truck OD dummy matrix
    ok = RunMacro("Create Matrix", Args, DummyExTrkOD_mat, "OD", "HvyExTrk,MedExTrk", "real+x")                //ExSkim
    if !ok then goto quit

    ok = RunMacro("add matrix index", Args, DummyExTrkOD_mat, "int+ext", "Row ID's", "Row")   //ExSkim
    if !ok then goto quit

    ok = RunMacro("add matrix index", Args, DummyExTrkOD_mat, "int+ext", "Col ID's", "Column")   //ExSkim
    if !ok then goto quit

    closeok = RunMacro("G30 File Close All")

//Initial check - find out the locations of TransCAD 6 and 64-bit Java
    ok = RunMacro("Find path")
    if !ok then goto quit

//Create debug directory in out folder
		debug_folder = scen_data_dir + "out\\debug"
		if GetDirectoryInfo(debug_folder, "Directory") = null then CreateDirectory(debug_folder)
		
//Create restart directory in out folder
		restart_folder1 = scen_data_dir + "out\\restart\\beforeModeChoiceChoice"
		if GetDirectoryInfo(restart_folder1, "Directory") = null then CreateDirectory(restart_folder1)		
		
		restart_folder2 = scen_data_dir + "out\\restart\\beforeTourFormationChoice"
		if GetDirectoryInfo(restart_folder2, "Directory") = null then CreateDirectory(restart_folder2)	

//Create carTrackIntermediate directory in out folder
		carTrackIntermediate_folder1 = scen_data_dir + "out\\carTrackIntermediate\\carChangeProb"
		if GetDirectoryInfo(carTrackIntermediate_folder1, "Directory") = null then CreateDirectory(carTrackIntermediate_folder1)		
		
		carTrackIntermediate_folder2 = scen_data_dir + "out\\carTrackIntermediate\\carUse"
		if GetDirectoryInfo(carTrackIntermediate_folder2, "Directory") = null then CreateDirectory(carTrackIntermediate_folder2)		
			
		carTrackIntermediate_folder3 = scen_data_dir + "out\\carTrackIntermediate\\tripList"
		if GetDirectoryInfo(carTrackIntermediate_folder3, "Directory") = null then CreateDirectory(carTrackIntermediate_folder3)
		
quit:
    return(ok)
endMacro

Macro "Find path"
    Shared  scen_data_dir, java64path, tc6path, pathlist

    //Create batch files to find out the locations of TransCAD 6 and 64-bit Java
    batch_file = scen_data_dir + "out\\findpath.bat"
    fptr = OpenFile(batch_file, "w")

    WriteLine(fptr, "where /R C:\\Progra~2 java.exe > " + scen_data_dir + "out\\path_JAVA64.txt")
    WriteLine(fptr, "where /R C:\\Progra~1 tcw.exe > " + scen_data_dir + "out\\path_TC6.txt")
    WriteLine(fptr, "exit 0")
    CloseFile(fptr)

    ok = RunMacro("TCB Run Command", 1, "Find locations of TransCAD 6 and 64-bit Java", batch_file)
    if !ok then goto quit

    //Read output files from the batch file
    dim pathlist[10]

    //Determine the path of TC6
    tc6path_file = OpenFile(scen_data_dir + "out\\path_TC6.txt", "r")
    n = 0
    while not FileAtEOF(tc6path_file) do
         n = n + 1
         pathlist[n] = ReadLine(tc6path_file)
    end

    CloseFile(tc6path_file)

    if n >= 2 then do
        n_select = 1 //RunDbox("Check Version", n)
        if n_select >0 then do
            tc6path = pathlist[n_select]
        end   //if
        else do
            ok = 0
            msgTxt = "More than one version of the JAVA programs have been found. User has aborted the model run."
            RunMacro("TCB Error", msgTxt)
            goto quit
        end   //else
    end  //if
    else do
    //In case no path was found
        if n = 0 then do
            showMessage("No 64-bit TransCAD 6 was found!")
            ok = 0
            goto quit
        end    //if

    //The path of 64-bit TC6
        if n = 1 then tc6path = pathlist[1]
    end    //else

    //Determine the path of JAVA
    java64path_file = OpenFile(scen_data_dir + "out\\path_JAVA64.txt", "r")
    n = 0
    while not FileAtEOF(java64path_file) do
         n = n + 1
         pathlist[n] = ReadLine(java64path_file)
         if Position(Lower(pathlist[n]),"jre") > 0 then n = n - 1
    end

    CloseFile(java64path_file)

    if n >= 2 then do
        n_select = 1 //RunDbox("Check Version", n)
        if n_select >0 then do
            java64path = Substitute(pathlist[n_select], "Program Files", "Progra~1",)
        end   //if
        else do
			  ok = 1
//            ok = 0
//            msgTxt = "More than one version of the JAVA programs have been found. User has aborted the model run."
//            RunMacro("TCB Error", msgTxt)
//            goto quit
        end   //else
    end  //if
    else do
    //In case no path was found
        if n = 0 then do
			  ok = 1
//            showMessage("No 64-bit JAVA was found!")
//            ok = 0
//            goto quit
        end    //if

    //The path of 64-bit JAVA
        if n = 1 then java64path = Substitute(pathlist[1], "Program Files", "Progra~1",)
    end    //else

quit:
    closeok = RunMacro("G30 File Close All")
    return(ok)
endMacro


dBox "Check Version" (n)  Title: "Check software version"
    Init do
        shared scen_data_dir, pathlist
        if n > 2 then ShowItem("selection3")

    EndItem

    Button "Continue" 12, 12, 8   Help:"Confirm and continue"
        do return(n_select)
    EndItem


    Button "Cancel" 30, 12, 8   Help:"Quit"
        do
        return()
    endItem

    Text "Please choose one from the following:" 1, 1

    Radio List "Results" 0.5, 2.5, 50, 8  Variable: n_select  Prompt: "Installed versions of"

    Radio Button "selection1" 1, 4.5 Prompt: pathlist[1]
    do
    enditem

    Radio Button "selection2" 1, 6.5 Prompt: pathlist[2]
    do
    enditem

    Radio Button "selection3" 1, 8.5 Prompt: pathlist[3] hidden
    do
    enditem


EndDbox


/*
                  REVISION HISTORY
 1 phoenix062906.rsc 07-Aug-2006,11:53:44,`JIAN' Converted Phoenix
      planning model dated at 6-29-2006
 2 phoenix062906.rsc 09-Aug-2006,10:44:24,`JIAN' Adding Int_Zone
      index to PK Distance Skim matrix in macro "Highway Skim"
 3 phoenix062906.rsc 09-Aug-2006,11:59:24,`JIAN' 1) Checking
      existence of skim matrix in macro "Skim Matrix RMSE"; 2) Changed
      vdf file to "phoenix-62906.vdf"
 4 phoenix062906.rsc 11-Aug-2006,13:49:46,`JIAN' Added "Drive Links"
      option to transit network building
 5 phoenix062906.rsc 15-Aug-2006,11:31:52,`JIAN' 1) in Macro
      "incsize", locating row in hhsize table based on first row value
      in the table; 2) obtaining formal parking nodes dynamically when
      computing formal/informal drive time in macro "transit skim"
 6 phoenix062906.rsc 18-Aug-2006,09:14:28,`JIAN' 1) removed shared
      variable FormalParks; 2) reading hwy-to-transit link time factor
      from model table
 7 phoenix062906.rsc 18-Aug-2006,10:17:30,`JIAN' Fixed a typo in
      "transit skim"
 8 phoenix062906.rsc 18-Aug-2006,13:33:26,`JIAN' Shared variables
      project_dbox, scenario_dbox and ui_file are no longer set to
      null in closing()
 9 phoenix062906.rsc 06-Sep-2006,11:00:50,`JIAN' 1) added rail mode;
      2) changes in transit database initialization
 10 phoenix062906.rsc 06-Sep-2006,13:58:44,`JIAN' set growth_factor
      and use_rail to null after each model run
 11 phoenix062906.rsc 15-Mar-2007,10:40:02,`JIAN' Added LinkFlds to
      macro "convert link mode flags"
 12 phoenix062906.rsc 25-Apr-2007,13:53:56,`JIAN' Moved assigning of
      transit route mode to earlier part of "transit database init"
 13 Error has been corrected in XI trip distribution now it is
      mf202 := nz(mf306) + nz(mf309) + nz(mf312)  June 21,2007
 14 Changes are made to make it the same model as batch 011806  07/31/2007
    *Non-work trip distribution parameters
    *Work distribution friction factors table rolled back
    *Family Table and Income Table changed back to the old one
    *Calibrated values in mode choice and logsum control files changed back
    *No change for elogit program since new and old versions are the same
     except for minor output changes
    *truck generation axle factor changed to 1.4
    *Error put back: FSKRAL in hbw and hbu mode choice control files
    *Error put back: Modes for PK RAIL BUS-ACC EXP IN-VEH
  15 Auto Ownership model updated to the right version      07/31/2007
  16 HOV skim, missing facility types added.       07/31/2007
  17 Code added to output convergence result to a single convergence.txt  08/09/2007
  18 Corrected MMA exclusion link set error. Excl_set is added to truck classes. 08/14/2007
  19 Corrected error in calculating non-work distribution propensity through
     gamma function. HBSC should be in a seperate category. 08/16/2007
  20 Corrected errors in saving Logsum, mode choice and non-work distributions reports
     Now reports from all the iterations can be saved. 08/16/2007
  21 phoenix062906.rsc 10-Sep-2007,09:02:46,`JIAN' Added Macro "transit
      best skim" and changes in "LR" transit skim
  22 Additional output tables, including aggregated flow and boardings/alighting,
     were added to the options in transit assignment procedure.             09/14/2007
  23 Added Boarding Summary to output total boardings to a csv file         09/17/2007
  24 Added Rail LOS skim matrix in model file and corrected Elogit to produce it. 09/21/2007
  25 Corrected the matrices used in HBW distribution                        09/21/2007
  26 Corrected the matrices used in transit best skim                       09/21/2007
  27 Steps added to initiallize temp matrix before each mode choice run     09/21/2007
  28 Corrected the position of where transit best skim is called            09/21/2007
  29 Limit matrices to the same dimension, so rail dummy zones included.    09/24/2007
  30 Corrected the mode table for proper mode usage.                        10/01/2007
  31 Corrected path modes and skim modes in Transit Skim macro.             10/01/2007
  32 Added lines in Transit Skim macro to copy the mistake in ctl file from EMME/2 model.     10/02/2007
  33 Corrected the matrix used to add Rail Use Flag in Transit Skim and transit best skim macros.     10/02/2007
  34 Rolled back rail time function to old d411.trn in 011806 model.        10/10/2007
  35 Code added to output batch file name to convergence.txt                10/10/2007
  36 Utility added to show nodes information on link records                10/11/2007
  37 Code added to generate xy.asc and xynodes.bin by Ampol                 10/12/2007
  38 Fixed dimension issue of school trip matrix.                           10/17/2007
  39 Code added to create HBW and MD Skim Matrix, which used to be inputs.  10/19/2007
  40 Code added to create AM and midday average flow tables, which used to be inputs by Ampol. 10/22/2007
  41 Code added to make Zone Group Table scenario independent.              10/22/2007
  42 Code added to process light trips before assignments.                  10/23/2007
  43 Code added to assign light rail trips. Model table is updated.         10/24/2007
  44 Fixed matrices addition issue in mode choice.                          10/31/2007
  45 Fixed Autoown FORTRAN program to use best transit skims                11/30/2007
  46 Enabled walk-only trips in set transit network allow aux trips         12/03/2007
  47 Lifted walk and drive access time limtits                              12/04/2007
  48 Corrected transit network settings error on AL/AE weights              12/10/2007
  49 Removed pnr/knr-station portion of trip table to drive-alone/SR        12/11/2007
  50 Removed null to zero function in transit skim and best skim            12/11/2007
  51 Updated "Show I J Nodes" macro                                         01/23/2008
  52 Added "Export Nodes XY" macro to export node coordinates for M6Link    01/23/2008
  53 Added "Add Link XY" macro to show coordinates on links                 01/28/2008
  54 Added "Add MODESTR Field" macro to show modes in a sigle column        02/01/2008
  55 Added "Export Tables for AQ" macro to export links to CSV for shape file conversion   02/07/2007
  56 Added quick assignment wizard in the untilities             						03/24/2008
  57 Removed RetFlag reset                                                  04/04/2008
  58 XI truck distribution balancing iterations changed from 1 to 10        04/04/2008
  59 Median truck Friction Factor corrected in trk_ff.asc (input file)      04/04/2008
  60 Weights in transit skimming and assignment made consistent.            04/07/2008
  61 Route systems point to base Highway DB.  This is then copied to the    06/19/2008 gde
     transit folder, rather than storing 3 copies of the highway links.
  62 Corrected errors in exclusion links for MD and NT assignments          07/09/2008
  63 Revised quick assignment utility to allow turn movements               07/09/2008
  64 Split out into separate files for easier code managment, including:    07/15/2008 gde
  65 Corrected imcompatibilities with 5.0 in "convert link mode flags"      07/24/2008
  66 Added lines to close all windows at various locations                  08/05/2008
  67 Added procedures to automatically generate transit access links.       08/13/2008 gde
  68 Updated max zone cap in Add Matrix Index subroutine                    10/02/2008
  69 Added procedure File Prep to prepare blank output matrices             10/06/2008
  70 Revised Create Matrix macro to allow different sizes and names         10/06/2008
  71 Revised Add MODESTR, how I J nodes, and Export Nodes XY utilities      12/16/2008
  72 Revised Quick Assignment utility with select link capability           12/16/2008
  73 Added Highway and Transit To Emme/2 Batchout utilities                 12/16/2008
  74 Added Make Maps and ValidNet utilities                                 12/16/2008
  75 Major overhaul to incorporate new transit skimming, mode choice
     and transit assignment routines.                                       02/03/2009 gde/ry
  76 Revised Make Maps and ValidNet utilities                               07/13/2009
  77 Time of day factors updated for sky harbor trips                       07/15/2009 gde
  78 Added Rail Stop-to-stop utilities to produce station matriices         08/06/2009 gde
  79 Revised utilities to export tables for AQ                              08/19/2009
  80 Corrected error in Build Highway Network                               08/21/2009
  81 Revised Reallocate HBW Sky Trips macro to use proper EGTC factor       09/23/2009
  82 Corrected coefficient error in \programs\mag.properties                09/23/2009
  83 Implemented new VDF functions                                          09/25/2010
  84 Revised transit assignment to use proper HBW trip matrix               10/16/2009
  85 To record computer and user names in \out\convergence.txt              10/16/2009
  86 Added Rail Market Factoring utility                                    10/16/2009 gde
  87 Added Create Transit Summaries utility                                 10/16/2009 gde
  88 Implemented AB/BA Length check                                         02/01/2010
  89 Added option of highway initialization in Quick Assignment             02/01/2010
  90 Implemented new truck model scripts and tables                         02/18/2010
  91 Log model runs information                                             04/23/2010
  92 Fixed error in mag.jar in dealing with floating number storage         05/15/2010
  93 Fixed error in highway assignment to feed in loop assigned times       06/01/2010
  94 Simplified version logging procedure and added more comments           06/18/2010
  95 Fixed error in mag.jar in dealing with space in folder names           06/22/2010
  96 Fixed iteration error for loop MD assignment in highway assignment     06/24/2010
  97 New MD cpacities were implemented                                      06/27/2010
  98 Added lines to close all windows at various locations                  06/28/2010
  99 Fixed issue in temp matrices in II truck distribution                  07/12/2010
 100 Fixed issue in transit access links to select WALK_ALLOWED links       07/30/2010
 101 Added procedure to verify horizon years from SE and truck input data   08/06/2010
 102 Fixed issue in II truck dist for temp file memory issue                08/06/2010
 103 Revised various script for expanded zonal system                       08/26/2010
 104 Added procedure to check Restrict, Type, Lanes and VDF fields          12/08/2010
 105 Adjusted sequence of commands in update Directory                      12/08/2010
 106 To automatically generate empty matrix file and d211.in file           11/12/2010
 107 To produce terminal times                                              11/12/2010
 108 Fixed issue in temp matrices in II truck distribution                  11/12/2010
 109 To check available disk space and mandate mile as map unit             11/12/2010
 110 Fixed error in TAZ file field name used in walk access percent         11/12/2010
 111 Adjust the sequence of commands in Update Directory                    02/01/2011
 112 Updated terminal times macro                                           02/01/2011
 113 Fixed error in Output XY macro                                         02/01/2011
 114 Fixed error in light rail time function                                02/01/2011
 115 Updated Check input macro to include more checkups                     02/01/2011
 116 Added external zones to skim and all the other mtx calculations        03/03/2011
 117 Added highway trip post processing macro                               06/01/2011
 118 Revised "Add matrix index" to handle internal only index               07/08/2011
 119 Added procedure to create DummyExTrkOD.mtx used in truck model         07/08/2011
 120 Added procedure to create FinalBalancedPNAs.bin, PNAsByCG.bin, FINALPNASBYCG.bin
      and BalancedPnAs.bin for truck model                                  07/08/2011
 121 Updated "ExtTruckTG" according to CS's recommendations                 07/08/2011
 122 Added procedure to create SPMAT.mtx for the truck model                07/11/2011
 123 Fixed error when running multiple scenarios about growth_factor        07/11/2011
 124 Fixed error for not overwriting NodeID on stop layer                   07/11/2011
 125 Fixed incorrect TAZ field used in generating walk percentage           07/11/2011
 126 Revised "CreateProductionMatrix" for model choice model                07/16/2011
 127 Revised "Add matrix index" to handle Row or Column only index          07/17/2011
 128 Removed hard coded paths in truck related scripts                      07/17/2011
 129 Added procedure to generate model choice batch files                   07/20/2011
 130 Updated Indian reservation zones                                       07/20/2011
 131 Updated PNR selection criteria in Highway Database Init                07/21/2011

                  REVISION HISTORY

*/