//Updated 8/9/2021 by Hyunsoo
//Updated 12/23/2024 by Xiao Replace the maz folder if the model crashed.


Macro "Performance_Measures_ABM"
	RunMacro("TCB Init")
    year = "SCENARIONAMEREPLACE"
	//************** Change Here ******************************************
	sceFolder="MODELFOLDER"
	projectFolder=sceFolder + "out\\"
	//**********************************************************************
	RunMacro("SEDataProcessing",sceFolder,projectFolder)
	RunMacro("Network Processing",sceFolder,projectFolder)
	RunMacro("Calculate All Accessibility",sceFolder,projectFolder)
	RunMacro("Average_Transit_Speed",sceFolder,projectFolder, year)	
	RunMacro("Pop_Emp_QuarterMile",sceFolder,projectFolder, year) //**** make sure that you have maz.dbd under maz folder
	RunMacro("Transit_Travel_Time",sceFolder,projectFolder, year)
	RunMacro("Travel_Time_Index",sceFolder,projectFolder, year)
	RunMacro("Highway_Lane_Miles",sceFolder,projectFolder, year) 		//output_HighwayLaneMiles.csv
	RunMacro("Transit_Service_by_Route",sceFolder,projectFolder, year)	//output_TransitService"+tod+".csv
	RunMacro("Tucson Subzone LOS Calculations",sceFolder,projectFolder, year)
	RunMacro("Close All")
	Exit()
	quit:
		//ShowMessage("Finished Performance Measures")
		
endMacro

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

Macro "SEDataProcessing" (sceFolder,projectFolder)     //Developed by Xiao Li to read ABM SE input files and write them to maz.dbd and taz.dbd
	RunMacro("TCB Init")

	se = OpenTable("SE","CSV",{sceFolder + "inputs\\socec_maz.csv"},)
	emp = OpenTable("EMP","CSV",{sceFolder + "inputs\\naics_maz.csv"},)
	{maz_lyr} = RunMacro("TCB Add DB Layers", sceFolder+"maz\\maz.dbd")
	{taz_lyr} = RunMacro("TCB Add DB Layers", sceFolder+"maz\\taz.dbd")
	
	NewFldsMAZ = {{"TOTAL_POP",        "real"},
               {"TOTAL_EMP",        "real"},
               {"BASICNEED",        "real"}	   
			   }
	NewFldsTAZ = {{"POP",        "real"},
               {"TOTAL_EMP",        "real"},
               {"BASICNEED",        "real"}	   
			   }			   
	ok = RunMacro("TCB Add View Fields", {maz_lyr, NewFldsMAZ})
	ok = RunMacro("TCB Add View Fields", {taz_lyr, NewFldsTAZ})

	
	JoinedMAZ = JoinViews("total pop and emp", maz_lyr+".MAZ", se+".zone", {{"A", }, {"Fields", aggr}})
	
	totPop =  GetDataVector(JoinedMAZ + "|", "RESPOP",)
	SetDataVector(maz_lyr + "|", "TOTAL_POP", totPop,)
	CloseView(JoinedMAZ)
	
	JoinedMAZ = JoinViews("total pop and emp", maz_lyr+".MAZ", emp+".MAZ", {{"A", }, {"Fields", aggr}})
	totEMP =  GetDataVector(JoinedMAZ + "|", "Total",)
	hospital = GetDataVector(JoinedMAZ + "|", "n62",)
	school = GetDataVector(JoinedMAZ + "|", "n61",)
	retail1 = GetDataVector(JoinedMAZ + "|", "n44",)
	retail2 = GetDataVector(JoinedMAZ + "|", "n45",)
	basicneed = hospital+school+retail1+retail2
	SetDataVector(maz_lyr + "|", "TOTAL_EMP", totEMP,)
	SetDataVector(maz_lyr + "|", "BASICNEED", basicneed,)
	CloseView(JoinedMAZ)

	ColumnAggregate(taz_lyr + "|", 0, maz_lyr + "|", {{"POP", "Sum", "TOTAL_POP", },{"TOTAL_EMP", "Sum", "TOTAL_EMP", },{"BASICNEED", "Sum", "BASICNEED", }}, null)
	//ColumnAggregate(taz_lyr + "|", 0, maz_lyr + "|", {{"POP", "Sum", "TOTAL_POP", },{"TOTAL_EMP", "Sum", "TOTAL_EMP", }}, null)
	
endMacro

Macro "Network Processing" (sceFolder,projectFolder)     //Developed by Xiao Li to Process VC Ration for ASN_subzone.dbd
	RunMacro("TCB Init")
	highway_db=sceFolder+"out\\ASN_subzone.dbd"
	pk_spd_tb=sceFolder+"maz\\lookup_tb.bin"
	{node_lyr,link_lyr} = RunMacro("TCB Add DB Layers", highway_db,,)
	
	cap_factor_freeway = 2.0
	cap_factor_arterial = 1.5
	

    NewFlds = {{"AB AM CAP OLD",        "real"},
               {"BA AM CAP OLD",        "real"},
               {"AB MD CAP OLD",        "real"},
               {"BA MD CAP OLD",        "real"},
               {"AB PM CAP OLD",        "real"},
               {"BA PM CAP OLD",        "real"},
               {"AB NT CAP OLD",        "real"},
               {"BA NT CAP OLD",        "real"},
               {"AB AM VC",        "real"},
               {"BA AM VC",        "real"},
               {"AB MD VC",        "real"},
               {"BA MD VC",        "real"},
               {"AB PM VC",        "real"},
               {"BA PM VC",        "real"},
               {"AB NT VC",        "real"},
               {"BA NT VC",        "real"}				   
			   }	

	ok = RunMacro("TCB Add View Fields", {link_lyr, NewFlds})
	
	pk_spd_vw = RunMacro("TCB OpenTable",,, {pk_spd_tb})
	Dir = {"AB", "BA"}
	Periods = {"AM", "MD", "PM", "NT"}
	

	for i = 1 to 2 do
	    dir = Dir[i]
        vdf_fld = "[" + dir + " VDF]"
		lanes_fld = "[" + dir + " Lanes]"
		
		

		jvw = JoinViews("jvw", "["+link_lyr+"]." + vdf_fld, pk_spd_vw+".CLASSABM",)
        vw_set = jvw + "|" 
		
		lanes = GetDataVector(vw_set, lanes_fld,)
		vdf_type = GetDataVector(vw_set, "CLASS",)

		for j = 1 to Periods.length do
            period = Periods[j]
			vc = GetDataVector(vw_set, dir + " Flow " + period,)  //read volume
            capa = GetDataVector(vw_set, "CAP",)      // read capacity
            capa =  if vdf_type = null | capa <= 0 then 0 else capa * lanes
                        
            // Capacity Factor
			if period = "AM" then do
			    capa = capa * 1.7
            end
			if period = "MD" then do
			    capa = capa * 7
            end
			if period = "PM" then do
			    capa = capa * 1.8
            end
			if period = "NT" then do
			    capa = capa * 11
            end
			vc = vc/capa
            SetDataVector(vw_set, dir + " " + period + " CAP OLD", capa,) // set capacity
			SetDataVector(vw_set, dir + " " + period + " VC", vc,) // set VC
        end
        CloseView(jvw)
    end		



	
endMacro

Macro "Calculate All Accessibility" (sceFolder,projectFolder)    //Developed by Xiao Li to Merge All Accessibility Calculation in 1 Macro
	
	RunMacro("TCB Init")
    //Should run after SEDataProcessing	
	
	outputFilePath = "AllAccessibility.csv"
	outputFilePath_BN = "AllAccessibility_BasicNeed.csv"
	
	{taz_lyr} = RunMacro("TCB Add DB Layers", sceFolder+"maz\\taz.dbd")
    SortOpts = null
	SortOpts.[Sort Order] = {{"TAZ", "Ascending"}}
	totEmp =  GetDataVector(taz_lyr + "|", "TOTAL_EMP", SortOpts)
	totPop =  GetDataVector(taz_lyr + "|", "POP", SortOpts)
	basicNeed = GetDataVector(taz_lyr + "|", "BASICNEED", SortOpts)

//Total Job Accessibilities	
	Dim auto_accessibility_OP[totEmp.length]
	Dim auto_accessibility_OP_30[totEmp.length]
	Dim auto_accessibility_PK[totEmp.length]
	Dim auto_accessibility_PK_30[totEmp.length]
	Dim transit_accessibility_OP[totEmp.length]
	Dim transit_accessibility_OP_45[totEmp.length]
	Dim transit_accessibility_OP_60[totEmp.length]
	Dim transit_accessibility_OP_90[totEmp.length]
	Dim transit_accessibility_PK[totEmp.length]
	Dim transit_accessibility_PK_45[totEmp.length]
	Dim transit_accessibility_PK_60[totEmp.length]
	Dim transit_accessibility_PK_90[totEmp.length]
	Dim bike_accessibility_25_5[totEmp.length]
	Dim walk_accessibility_20_1[totEmp.length]

//Basic Need Accessibilities
	Dim auto_accessibility_OP_BN[totEmp.length]
	Dim auto_accessibility_OP_30_BN[totEmp.length]
	Dim auto_accessibility_PK_BN[totEmp.length]
	Dim auto_accessibility_PK_30_BN[totEmp.length]
	Dim transit_accessibility_OP_BN[totEmp.length]
	Dim transit_accessibility_OP_45_BN[totEmp.length]
	Dim transit_accessibility_OP_60_BN[totEmp.length]
	Dim transit_accessibility_OP_90_BN[totEmp.length]
	Dim transit_accessibility_PK_BN[totEmp.length]
	Dim transit_accessibility_PK_45_BN[totEmp.length]
	Dim transit_accessibility_PK_60_BN[totEmp.length]
	Dim transit_accessibility_PK_90_BN[totEmp.length]
	Dim bike_accessibility_25_5_BN[totEmp.length]
	Dim walk_accessibility_20_1_BN[totEmp.length]

	
	//Generate All Skim Matrices
	index = null
	for j = 1 to totEmp.length do
		index = index + {i2s(j)}
	end	
	
	//Off Peak Auto Skim and Distance Skim
	skimMtxFileName="mdLovSkm.mtx"
	skimMtx = OpenMatrix(projectFolder + skimMtxFileName, )
	skimCores = GetMatrixCoreNames(skimMtx)
	skimCurAuto = CreateMatrixCurrency(skimMtx, skimCores[1], , , ) 
	OPtimeSkimAuto = GetMatrixValues(skimCurAuto, index, index)
	skimCurDist = CreateMatrixCurrency(skimMtx, skimCores[2], , , ) 
	distSkimActive = GetMatrixValues(skimCurDist, index, index)

    //Peak Auto Skim
	skimMtxFileName="pmLovSkm.mtx"
	skimMtx = OpenMatrix(projectFolder + skimMtxFileName, )
	skimCores = GetMatrixCoreNames(skimMtx)
	skimCurAuto = CreateMatrixCurrency(skimMtx, skimCores[1], , , ) 
	PKtimeSkimAuto = GetMatrixValues(skimCurAuto, index, index)
	
	//Peak Transit Skim
	PKtransitMatFileName = "tskm_PK_WLK_TRN_WLK.mtx"
	transitSkimMat = OpenMatrix(projectFolder+PKtransitMatFileName,)
	transitTmpCores = GetMatrixCoreNames(transitSkimMat)
	transitIVT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[2],,,)
	transitIWaitT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[3],,,)
	transitTWaitT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[4],,,)
	transitTWalkT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[5],,,)
	transitAWT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[6],,,)
	transitEWT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[7],,,)
	position = ArrayPosition(transitTmpCores, {"Total Time"},)
	if position = 0 then AddMatrixCore(transitSkimMat, "Total Time")
	totaltransitTimeCurr = CreateMatrixCurrency(transitSkimMat, "Total Time", , , )
	totaltransitTimeCurr := NulltoZero(transitIVT) + NulltoZero(transitIWaitT) + NulltoZero(transitTWaitT) + NulltoZero(transitTWalkT) + NulltoZero(transitAWT) + NulltoZero(transitEWT)
	totaltransitTimeCurr := if totaltransitTimeCurr < 0.1 then 99999 else totaltransitTimeCurr //process the time to the TAZs that are non-accessible
	tmpVector=Vector(totaltransitTimeCurr.cols, "float", {{"Constant", 5.0}}) 
	SetMatrixVector(totaltransitTimeCurr, tmpVector, {{"Diagonal"}})
	PKtimeSkimTransit = GetMatrixValues(totaltransitTimeCurr, index, index)
	
	OPtransitMatFileName="tskm_OP_WLK_TRN_WLK.mtx"
	transitSkimMat = OpenMatrix(projectFolder+OPtransitMatFileName,)
	transitTmpCores = GetMatrixCoreNames(transitSkimMat)
	transitIVT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[2],,,)
	transitIWaitT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[3],,,)
	transitTWaitT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[4],,,)
	transitTWalkT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[5],,,)
	transitAWT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[6],,,)
	transitEWT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[7],,,)
	position = ArrayPosition(transitTmpCores, {"Total Time"},)
	if position = 0 then AddMatrixCore(transitSkimMat, "Total Time")
	totaltransitTimeCurr = CreateMatrixCurrency(transitSkimMat, "Total Time", , , )
	totaltransitTimeCurr := NulltoZero(transitIVT) + NulltoZero(transitIWaitT) + NulltoZero(transitTWaitT) + NulltoZero(transitTWalkT) + NulltoZero(transitAWT) + NulltoZero(transitEWT)
	totaltransitTimeCurr := if totaltransitTimeCurr < 0.1 then 99999 else totaltransitTimeCurr //process the time to the TAZs that are non-accessible
	tmpVector=Vector(totaltransitTimeCurr.cols, "float", {{"Constant", 5.0}}) 
	SetMatrixVector(totaltransitTimeCurr, tmpVector, {{"Diagonal"}})
	OPtimeSkimTransit = GetMatrixValues(totaltransitTimeCurr, index, index)
	
	
//Calculate all accessibilities
    SetStatus(2, "Calculate Accessibility, Might takes 20 minutes",)
	for i = 1 to totEmp.length do
		auto_accessibility_OP[i] = 0.
		auto_accessibility_OP_30[i] = 0.
		auto_accessibility_PK[i] = 0.
		auto_accessibility_PK_30[i] = 0.
		transit_accessibility_OP[i] = 0.
		transit_accessibility_OP_45[i] = 0.
		transit_accessibility_OP_60[i] = 0.
		transit_accessibility_OP_90[i] = 0.
		transit_accessibility_PK[i] = 0.
		transit_accessibility_PK_45[i] = 0.
		transit_accessibility_PK_60[i] = 0.
		transit_accessibility_PK_90[i] = 0.
		bike_accessibility_25_5[i] = 0.
		walk_accessibility_20_1[i] = 0.
		
		
		auto_accessibility_OP_BN[i] = 0.
		auto_accessibility_OP_30_BN[i] = 0.
		auto_accessibility_PK_BN[i] = 0.
		auto_accessibility_PK_30_BN[i] = 0.
		transit_accessibility_OP_BN[i] = 0.
		transit_accessibility_OP_45_BN[i] = 0.
		transit_accessibility_OP_60_BN[i] = 0.
		transit_accessibility_OP_90_BN[i] = 0.
		transit_accessibility_PK_BN[i] = 0.
		transit_accessibility_PK_45_BN[i] = 0.
		transit_accessibility_PK_60_BN[i] = 0.
		transit_accessibility_PK_90_BN[i] = 0.
		bike_accessibility_25_5_BN[i] = 0.
		walk_accessibility_20_1_BN[i] = 0.
		
		
		for j = 1 to totEmp.length do
			if totEmp[j] > 0 then do//log () in the numerator is eliminated which is only applied for running SAM as input file
				if OPtimeSkimAuto[i][j] < 9999 then 
					auto_accessibility_OP[i] = auto_accessibility_OP[i] + totEmp[j]/Exp(OPtimeSkimAuto[i][j]/10.)
					auto_accessibility_OP_BN[i] = auto_accessibility_OP_BN[i] + basicNeed[j]/Exp(OPtimeSkimAuto[i][j]/10.)
				if OPtimeSkimTransit[i][j] < 9999 then 
					transit_accessibility_OP[i] = transit_accessibility_OP[i] + totEmp[j]/Exp(OPtimeSkimTransit[i][j]/10.)
					transit_accessibility_OP_BN[i] = transit_accessibility_OP_BN[i] + basicNeed[j]/Exp(OPtimeSkimTransit[i][j]/10.)
				if PKtimeSkimAuto[i][j] < 9999 then 
					auto_accessibility_PK[i] = auto_accessibility_PK[i] + totEmp[j]/Exp(PKtimeSkimAuto[i][j]/10.)
					auto_accessibility_PK_BN[i] = auto_accessibility_PK_BN[i] + basicNeed[j]/Exp(PKtimeSkimAuto[i][j]/10.)
				if PKtimeSkimTransit[i][j] < 9999 then 
					transit_accessibility_PK[i] = transit_accessibility_PK[i] + totEmp[j]/Exp(PKtimeSkimTransit[i][j]/10.)
					transit_accessibility_PK_BN[i] = transit_accessibility_PK_BN[i] + basicNeed[j]/Exp(PKtimeSkimTransit[i][j]/10.)
			end
			if OPtimeSkimAuto[i][j] <= 30 then do
				auto_accessibility_OP_30[i] = auto_accessibility_OP_30[i] + totEmp[j]
				auto_accessibility_OP_30_BN[i] = auto_accessibility_OP_30_BN[i] + basicNeed[j]
			end
			if PKtimeSkimAuto[i][j] <= 30 then do
				auto_accessibility_PK_30[i] = auto_accessibility_PK_30[i] + totEmp[j]
				auto_accessibility_PK_30_BN[i] = auto_accessibility_PK_30_BN[i] + basicNeed[j]
			end
			if OPtimeSkimTransit[i][j] <= 45 then do
				transit_accessibility_OP_45[i] = transit_accessibility_OP_45[i] + totEmp[j]
				transit_accessibility_OP_45_BN[i] = transit_accessibility_OP_45_BN[i] + basicNeed[j]
			end
			if OPtimeSkimTransit[i][j] <= 60 then do
				transit_accessibility_OP_60[i] = transit_accessibility_OP_60[i] + totEmp[j]
				transit_accessibility_OP_60_BN[i] = transit_accessibility_OP_60_BN[i] + basicNeed[j]
			end
			if OPtimeSkimTransit[i][j] <= 90 then do
				transit_accessibility_OP_90[i] = transit_accessibility_OP_90[i] + totEmp[j]
				transit_accessibility_OP_90_BN[i] = transit_accessibility_OP_90_BN[i] + basicNeed[j]
			end
			if PKtimeSkimTransit[i][j] <= 45 then do
				transit_accessibility_PK_45[i] = transit_accessibility_PK_45[i] + totEmp[j]
				transit_accessibility_PK_45_BN[i] = transit_accessibility_PK_45_BN[i] + basicNeed[j]
			end
			if PKtimeSkimTransit[i][j] <= 60 then do
				transit_accessibility_PK_60[i] = transit_accessibility_PK_60[i] + totEmp[j]
				transit_accessibility_PK_60_BN[i] = transit_accessibility_PK_60_BN[i] + basicNeed[j]
			end
			if PKtimeSkimTransit[i][j] <= 90 then do
				transit_accessibility_PK_90[i] = transit_accessibility_PK_90[i] + totEmp[j]
				transit_accessibility_PK_90_BN[i] = transit_accessibility_PK_90_BN[i] + basicNeed[j]
			end
			if distSkimActive[i][j] <= 5 then do
				bike_accessibility_25_5[i] = bike_accessibility_25_5[i] + totEmp[j]
				bike_accessibility_25_5_BN[i] = bike_accessibility_25_5_BN[i] + basicNeed[j]
			end
			if distSkimActive[i][j] <= 1 then do
				walk_accessibility_20_1[i] = walk_accessibility_20_1[i] + totEmp[j]
				walk_accessibility_20_1_BN[i] = walk_accessibility_20_1_BN[i] + basicNeed[j]
			end
		end

	end
	
	//Write Alll Accessibilities
	title = "TAZ,auto_accessibility_OP,auto_accessibility_OP_30,auto_accessibility_PK,auto_accessibility_PK_30," + "transit_accessibility_OP,transit_accessibility_OP_45,transit_accessibility_OP_60,transit_accessibility_OP_90," + "transit_accessibility_PK,transit_accessibility_PK_45,transit_accessibility_PK_60,transit_accessibility_PK_90," + "bike_accessibility_25_5,walk_accessibility_20_1"
	outputFile = OpenFile(projectFolder+outputFilePath,"w")
	WriteLine(outputFile,title)
	for i = 1 to auto_accessibility_OP.length do
		WriteLine(outputFile, String(i)+","+String(auto_accessibility_OP[i]) + "," + String(auto_accessibility_OP_30[i]) + "," + String(auto_accessibility_PK[i]) + "," + String(auto_accessibility_PK_30[i]) + "," + String(transit_accessibility_OP[i]) + "," + String(transit_accessibility_OP_45[i]) + "," + String(transit_accessibility_OP_60[i]) + "," + String(transit_accessibility_OP_90[i]) + "," + String(transit_accessibility_PK[i]) + "," + String(transit_accessibility_PK_45[i]) + "," + String(transit_accessibility_PK_60[i]) + "," + String(transit_accessibility_PK_90[i]) + "," + String(bike_accessibility_25_5[i]) + "," + String(walk_accessibility_20_1[i]))
	end
	closeFile(outputFile)
	
	title = "TAZ,auto_accessibility_OP,auto_accessibility_OP_30,auto_accessibility_PK,auto_accessibility_PK_30," + "transit_accessibility_OP,transit_accessibility_OP_45,transit_accessibility_OP_60,transit_accessibility_OP_90," + "transit_accessibility_PK,transit_accessibility_PK_45,transit_accessibility_PK_60,transit_accessibility_PK_90," + "bike_accessibility_25_5,walk_accessibility_20_1"
	outputFile = OpenFile(projectFolder+outputFilePath_BN,"w")
	WriteLine(outputFile,title)
	for i = 1 to auto_accessibility_OP.length do
		WriteLine(outputFile, String(i)+","+String(auto_accessibility_OP_BN[i]) + "," + String(auto_accessibility_OP_30_BN[i]) + "," + String(auto_accessibility_PK_BN[i]) + "," + String(auto_accessibility_PK_30_BN[i]) + "," + String(transit_accessibility_OP_BN[i]) + "," + String(transit_accessibility_OP_45_BN[i]) + "," + String(transit_accessibility_OP_60_BN[i]) + "," + String(transit_accessibility_OP_90_BN[i]) + "," + String(transit_accessibility_PK_BN[i]) + "," + String(transit_accessibility_PK_45_BN[i]) + "," + String(transit_accessibility_PK_60_BN[i]) + "," + String(transit_accessibility_PK_90_BN[i]) + "," + String(bike_accessibility_25_5_BN[i]) + "," + String(walk_accessibility_20_1_BN[i]))
	end
	closeFile(outputFile)
	
endMacro

Macro "Calculate Transit Accessibility" (sceFolder,projectFolder)
	
	RunMacro("TCB Init")
	
	//Aggregate total pop and tatal emp in MAZ to TAZ
	{maz_lyr} = RunMacro("TCB Add DB Layers", sceFolder+"maz\\maz.dbd")
	{taz_lyr} = RunMacro("TCB Add DB Layers", sceFolder+"maz\\taz.dbd")
	
	//****This is only for temporary since the outputs are a little bit off in aggregation
	//Using ColumnAggregate
	//ColumnAggregate(taz_lyr + "|", 0, maz_lyr + "|", {{"POP", "Sum", "TOTAL_POP", },{"TOTAL_EMP", "Sum", "TOTAL_EMP", }}, null)
	//Using JoinView
	//aggr = {{"TOTAL_POP", {{"Sum"}}}, {"TOTAL_EMP", {{"Sum"}}}}
	//view2 = JoinViews("total pop and emp", taz_lyr+".TAZ", maz_lyr+".TAZ", {{"A", }, {"Fields", aggr}})
	
	//output file
	trOutputFile = "output_accessibility_transit" //.csv"
	
	//accessibility parameter
	beta = 2.25
	timeBoundary_transit={45,60,90} //minutes
	
	//get TAZ population and employment
	SortOpts = null
	SortOpts.[Sort Order] = {{"TAZ", "Ascending"}}
	totEmp =  GetDataVector(taz_lyr + "|", "TOTAL_EMP", SortOpts)
	totPop =  GetDataVector(taz_lyr + "|", "POP", SortOpts)
	
	//transit skim: tskm_PK_WLK_CON_WLK.mtx
	TOD_skim = {"md","pm"}
	TODF = {"OP","PK"}
	transitAccessEgress = {{"WLK","WLK"},{"WLK","KNR"},{"WLK","PNR"},{"KNR","WLK"},{"PNR","WLK"}}
	transitLineHaul = {"PRE","CON"}
	
    index = null
	for j = 1 to totEmp.length do
		index = index + {i2s(j)}
	end	
	skimMtxFileName = "mdLovSkm.mtx"
	skimMtx = OpenMatrix(projectFolder + skimMtxFileName, )
	skimCores = GetMatrixCoreNames(skimMtx)
	skimCurAuto=CreateMatrixCurrency(skimMtx, skimCores[1], , , ) 
	OPtimeSkimAuto = GetMatrixValues(skimCur, index, index)
	skimCurDist = CreateMatrixCurrency(skimMtx, skimCores[2], , , ) 
	distSkimActive = GetMatrixValues(skimCur, index, index)
	
	skimMtxFileName = "pmLovSkm.mtx"
	skimMtx = OpenMatrix(projectFolder + skimMtxFileName, )
	skimCores = GetMatrixCoreNames(skimMtx)
	skimCurAuto = CreateMatrixCurrency(skimMtx, skimCores[1], , , ) 
	PKtimeSkimAuto = GetMatrixValues(skimCur, index, index)	
	
	PKtransitMatFileName = "tskm_PK_WLK_TRN_WLK.mtx"
	transitSkimMat = OpenMatrix(projectFolder+PKtransitMatFileName,)
	transitTmpCores = GetMatrixCoreNames(transitSkimMat)
	transitIVT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[2],,,)
	transitIWaitT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[3],,,)
	transitTWaitT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[4],,,)
	transitTWalkT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[5],,,)
	transitAWT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[6],,,)
	transitEWT = CreateMatrixCurrency(transitSkimMat,transitTmpCores[7],,,)
	position = ArrayPosition(transitTmpCores, {"Total Time"},)
	if position = 0 then AddMatrixCore(transitSkimMat, "Total Time")
	totaltransitTimeCurr = CreateMatrixCurrency(transitSkimMat, "Total Time", , , )
	totaltransitTimeCurr := transitIVT + transitIWaitT + transitTWaitT + transitTWalkT + transitAWT + transitEWT
	totaltransitTimeCurr := if totaltransitTimeCurr < 0.1 then 99999 else totaltransitTimeCurr //process the time to the TAZs that are non-accessible
	tmpVector=Vector(totaltransitTimeCurr.cols, "float", {{"Constant", 5.0}}) 
	SetMatrixVector(totaltransitTimeCurr, tmpVector, {{"Diagonal"}})


	OKtransitMatFileName="tskm_OP_WLK_TRN_WLK.mtx"

	
	
	for i = 1 to TOD_skim.length do
		//index for getting the size of skim
		index = null
		for j = 1 to totEmp.length do
			index = index + {i2s(j)}
		end
		
		skimMtxFileName=TOD_skim[i]+"LovSkm.mtx"
		skimMtx = OpenMatrix(projectFolder + skimMtxFileName, )
		skimCores = GetMatrixCoreNames(skimMtx)
		skimCurAuto=CreateMatrixCurrency(skimMtx, skimCores[1], , , ) 
		timeSkimAuto = GetMatrixValues(skimCur, index, index)
	
		//skim mtx (1121x1121)
		for j=1 to 1 do //******** transitAccessEgress.length do only consider WLK access and egress mode for accessibility
			for k=1 to transitLineHaul.length do
				//read transit skim matrix
				transitMatFileName="tskm_"+TODF[i]+"_"+transitAccessEgress[i][1]+"_"+transitLineHaul[k]+"_"+transitAccessEgress[i][2]+".mtx"
				transitSkimMat=OpenMatrix(projectFolder+transitMatFileName,)
				transitTmpCores=GetMatrixCoreNames(transitSkimMat)
				
				transitSkimCurArr=null
				tmpCur=null
				for m=1 to transitTmpCores.length do
					tmpCur=CreateMatrixCurrency(transitSkimMat,transitTmpCores[m],,,)
					transitSkimCurArr=transitSkimCurArr+{tmpCur}
				end
				
				//Add Total Time core which aggregates all transit travel time pieces
				position = ArrayPosition(transitTmpCores, {"Total Time"},)
				if position = 0 then AddMatrixCore(transitSkimMat, "Total Time")
				totalTimeCur = CreateMatrixCurrency(transitSkimMat, "Total Time", , , )
				//outputMatCur=CreateMatrixCurrency(outputMat,transitCores[counter],,,)
				//totalTimeCur := if transitSkimCurArr[3] > 750 then 750/100 else transitSkimCurArr[3]/100 //the initial waiting time upper bound 7.5 minutes
				totalTimeCur := (transitSkimCurArr[2]+transitSkimCurArr[3]+transitSkimCurArr[4]+transitSkimCurArr[5]+transitSkimCurArr[6]+transitSkimCurArr[7]+transitSkimCurArr[8]) //in minutes
				totalTimeCur := if totalTimeCur < 0.1 then 99999 else totalTimeCur //process the time to the TAZs that are non-accessible
				
				//intrazonal trips are assumed to take 5 minutes
				tmpVector=Vector(totalTimeCur.cols, "float", {{"Constant", 5.0}}) 
				SetMatrixVector(totalTimeCur, tmpVector, {{"Diagonal"}})
				
				timeSkim = GetMatrixValues(totalTimeCur, index, index)
				totalTimeCur = null
				
				//accessibility
				accessibility = RunMacro("Accessibility Calculation",beta, totEmp, timeSkim)
				outputFile = OpenFile(projectFolder+trOutputFile+"_"+transitLineHaul[k]+"_"+TODF[i]+".csv","w")
				RunMacro("Write Accessibility",accessibility, totPop, outputFile, "TAZ, Accessibility")
				
				//jobs accessible in 60, 90 minutes by transit
				for j = 1 to timeBoundary_transit.length do
					accessibility = RunMacro("Accessible_within_hr_for_jobs",totEmp, timeSkim, timeBoundary_transit[j])
					outputFile = OpenFile(projectFolder+trOutputFile+"_"+transitLineHaul[k]+"_"+TODF[i]+"_"+i2s(timeBoundary_transit[j])+"mins.csv","w")
					RunMacro("Write_Accessible_in_Hr",accessibility, outputFile, totEmp, "TAZ, AccessibleJobs, Coverage(%)")
				end
			end
		end		
	end
	
endMacro

Macro "Transit_Travel_Time" (sceFolder,projectFolder, year)
	RunMacro("TCB Init")
	
	//transit skim: tskm_PK_WLK_CON_WLK.mtx
	//transit trip: transit_op.mtx
	
	//output file
	outputFile1 = projectFolder + "output_TransitTimeDistribution.csv"
	//outputFile2 = projectFolder + "output_TotalTime.csv"
	
	//tod
	TODF={"OP","PK"}
	TOD_skim={"md","pm"}

	
	//transit cores
	transitAccessEgress={{"WLK","WLK"},{"WLK","KNR"},{"WLK","PNR"},{"KNR","WLK"},{"PNR","WLK"}}
	transitLineHaul={"PRE","CON"}
	
	//copy transit trip matrix to creat an empty matrix
	pkTripMatFile = "transit_pk.mtx"
	opTripMatfile = "transit_op.mtx"
	tripMat={pkTripMatFile,opTripMatfile}
	
	//create transit cores for transit trips
	transitCores=null
	for j=1 to transitLineHaul.length do
		//tmpCores=null
		for i=1 to transitAccessEgress.length do
			tmpCores=tmpCores+{transitAccessEgress[i][1]+"-"+transitLineHaul[j]+"-"+transitAccessEgress[i][2]}
		end
	end
	transitCores=tmpCores

	//init
	TTTime_Transit=null
	TTTrip_Transit=null
	
	for i=1 to TODF.length do
		//create 1121x1121 matrix and copty the content of 1110x1110 matrix
		tripMtxFileName = "transit_"+TODF[i]+".mtx" //1110x1110 matrix
		tripMtx = OpenMatrix(projectFolder + tripMtxFileName, ) //1110
		tmpCores = GetMatrixCoreNames(tripMtx) //get matrix core names
		
		//Create 1121x1121 trip mtx and copy 1110x1110 trip mtx
		Opts=null
		Opts.[File Name] = projectFolder+"transit_1121_"+TODF[i]+".mtx"
		Opts.Label = "Transit Trip 1121"
		Opts.Tables = tmpCores
		Opts.[Column Major] = "No"
		Opts.[File Based] = "Yes"
		Opts.Compression = True
		tripMat_1121 = CreateSimpleMatrix("Transit Trip 1121", 1121, 1121, Opts)
		
		for p=1 to tmpCores.length do
			tmp_mc_1110 = CreateMatrixCurrency(tripMtx, tmpCores[p], , , )
			tmp_mc_1121 = CreateMatrixCurrency(tripMat_1121, tmpCores[p], , , )
			MergeMatrixElements(tmp_mc_1121, {tmp_mc_1110}, null, null,{{"Force Missing", "Yes"}})
		end
	
		//create empty matrix for outputs
		MCmat=OpenMatrix(projectFolder+"transit_1121_"+TODF[i]+".mtx",)
		MCcores=transitCores
		MCCurArr=null
		for j=1 to MCcores.length do
			tmpCur=CreateMatrixCurrency(MCmat,MCcores[j],,,)
			MCCurArr=MCCurArr+{tmpCur}
		end
		
		Opts=null
		Opts.[File Name]=projectFolder+"output_TravelTrime_transit_"+TODF[i]+".mtx"
		Opts.Label=TODF[i]+" Total Travel Time by Transit"
		Opts.Tables=MCcores
		outputMat=CopyMatrixStructure(MCCurArr,Opts)
		AddMatrixCore(outputMat,"TotTrvTime_Transit")
		AddMatrixCore(outputMat,"TotTrip_Transit")		
		totTimeMatCur_Transit=CreateMatrixCurrency(outputMat,"TotTrvTime_Transit",,,)
		totTripMatCur_Transit=CreateMatrixCurrency(outputMat,"TotTrip_Transit",,,)	
	
		//flows vector for weighting average speed of transit service
		counter=0
		for j=1 to transitAccessEgress.length do
			for k=1 to transitLineHaul.length do
				counter=counter+1 //array counter
			
				//3. read transit skim matrix
				transitMatFileName="tskm_"+TODF[i]+"_"+transitAccessEgress[i][1]+"_"+transitLineHaul[k]+"_"+transitAccessEgress[i][2]+".mtx"
				transitSkimMat=OpenMatrix(projectFolder+transitMatFileName,)
				transitTmpCores=GetMatrixCoreNames(transitSkimMat)
				
				transitSkimCurArr=null
				for m=1 to transitTmpCores.length do
					tmpCur=CreateMatrixCurrency(transitSkimMat,transitTmpCores[m],,,)
					transitSkimCurArr=transitSkimCurArr+{tmpCur}
				end
				tmpCur=null
				
				//4. Estimate transit travel time
				curIndex=ArrayPosition(MCcores,{transitCores[counter]},)
				transitTripCur=MCCurArr[curIndex]
				
				outputMatCur=CreateMatrixCurrency(outputMat,transitCores[counter],,,)
				//outputMatCur := if transitSkimCurArr[3] > 750 then 750/100 else transitSkimCurArr[3]/100 //the initial waiting time upper bound 7.5 minutes
				outputMatCur := (transitSkimCurArr[2]+transitSkimCurArr[3]+transitSkimCurArr[4]+transitSkimCurArr[5]+transitSkimCurArr[6]+transitSkimCurArr[7]+transitSkimCurArr[8]) //in minutes
				outputMatCur := if outputMatCur < 0.1 then 0 else outputMatCur //process the time to the TAZs that are non-accessible
				
				//intrazonal trips are assumed to take 5 minutes
				tmpVector=Vector(outputMatCur.cols, "float", {{"Constant", 5.0}}) 
				SetMatrixVector(outputMatCur, tmpVector, {{"Diagonal"}})
				
				outputMatCur := outputMatCur*transitTripCur
				
				if j=1 and k=1 then do
					totTimeMatCur_Transit:=outputMatCur
					totTripMatCur_Transit:=transitTripCur
				end
				else do
					totTimeMatCur_Transit:=totTimeMatCur_Transit+outputMatCur
					totTripMatCur_Transit:=totTripMatCur_Transit+transitTripCur
				end
				
				for m = 1 to transitSkimCurArr.length do
					transitSkimCurArr[m] = null
				end
			
				transitSkimM = null
			end
		end	
		//total transit travel time and trips
		TTTime_Transit = TTTime_Transit + {VectorToArray(GetMatrixVector(totTimeMatCur_Transit, {{"Marginal", "Row Sum"}}))}
		TTTrip_Transit = TTTrip_Transit + {VectorToArray(GetMatrixVector(totTripMatCur_Transit, {{"Marginal", "Row Sum"}}))}
		
	end	
	
	//************ output file ***************
	outFile1=OpenFile(outputFile1,"w")
	TotalTransitTime = 0
	TotalTransitTrips = 0
	//WriteLine(outFile1,"TAZ,PK_TTime_Transit,OP_TTime_Transit,PK_TTrip_Transit,OP_TTrip_Transit")
	for i=1 to TTTime_Transit[1].length do
	    TotalTransitTime = TotalTransitTime +  TTTime_Transit[1][i] + TTTime_Transit[2][i]
		TotalTransitTrips = TotalTrasitTrips  + TTTrip_Transit[1][i] + TTTrip_Transit[2][i]
		//WriteLine(outFile1,i2s(i)+","+r2s(TTTime_Transit[1][i])+","+r2s(TTTime_Transit[2][i])+","+r2s(TTTrip_Transit[1][i])+","+r2s(TTTrip_Transit[2][i]))
	end
	AverageTransitTime = TotalTransitTime/TotalTransitTrips
	WriteLine(outFile1,"source,measures,dim1,dim1_value,dim2,dim2_value,Scenario,measure_name,measure_value")
	WriteLine(outFile1,"ABM,AverageTransitTravelTime,,,,," + year + ",AverageTransitTravelTime," + r2s(AverageTransitTime))

	CloseFile(outFile1)
	
	/*outFile2=OpenFile(outputFile2,"w")
	WriteLine(outFile2,"TAZ,PK_TTTime_All,OP_TTTime_All,PK_TTTrip_All,OP_TTTrip_All")
	for i=1 to TTTime_Transit[1].length do
		WriteLine(outFile2,i2s(i)+","+r2s(TTTime_Auto[1][i]+TTTime_Transit[1][i]+TTTime_Walk[1][i]+TTTime_Bike[1][i])+","+r2s(TTTime_Auto[2][i]+TTTime_Transit[2][i]+TTTime_Walk[2][i]+TTTime_Bike[2][i])+","+r2s(TTTrip_Auto[1][i]+TTTrip_Transit[1][i]+TTTrip_Walk[1][i]+TTTrip_Bike[1][i])+","+r2s(TTTrip_Auto[2][i]+TTTrip_Transit[2][i]+TTTrip_Walk[2][i]+TTTrip_Bike[2][i]))
	end	
	CloseFile(outFile2)
	*/
	
endMacro

Macro "Calculate Auto Accessibility" (sceFolder,projectFolder)
	
	RunMacro("TCB Init")
	
	//Aggregate total pop and tatal emp in MAZ to TAZ
	{maz_lyr} = RunMacro("TCB Add DB Layers", sceFolder+"maz\\maz.dbd")
	{taz_lyr} = RunMacro("TCB Add DB Layers", sceFolder+"maz\\taz.dbd")
	
	//This is only for temporary since the outputs are a little bit off in aggregation
	//Using ColumnAggregate
	//ColumnAggregate(taz_lyr + "|", 0, maz_lyr + "|", {{"POP", "Sum", "TOTAL_POP", },{"TOTAL_EMP", "Sum", "TOTAL_EMP", }}, null)
	//Using JoinView
	//aggr = {{"TOTAL_POP", {{"Sum"}}}, {"TOTAL_EMP", {{"Sum"}}}}
	//view2 = JoinViews("total pop and emp", taz_lyr+".TAZ", maz_lyr+".TAZ", {{"A", }, {"Fields", aggr}})
	
	//output file
	hyOutputFile = "output_accessibility_highway" //.csv"
	
	//accessibility parameter
	beta = 2.25
	timeBoundary_auto={30,45} //minutes
	
	//get TAZ population and employment
	SortOpts = null
	SortOpts.[Sort Order] = {{"TAZ", "Ascending"}}
	totEmp =  GetDataVector(taz_lyr + "|", "TOTAL_EMP", SortOpts)
	totPop =  GetDataVector(taz_lyr + "|", "POP", SortOpts)
	
	//skim
	TOD_skim={"am","md","pm"}
	
	for i = 1 to TOD_skim.length do
		//index for getting the size of skim
		index = null
		for j = 1 to totEmp.length do
			index = index + {i2s(j)}
		end
	
		//skim mtx (1121x1121)
		skimMtxFileName=TOD_skim[i]+"LovSkm.mtx"
		skimMtx = OpenMatrix(projectFolder + skimMtxFileName, )
		skimCores = GetMatrixCoreNames(skimMtx)
		skimCur=CreateMatrixCurrency(skimMtx, skimCores[1], , , ) 
		timeSkim = GetMatrixValues(skimCur, index, index)
		
		//accessibility
		accessibility = RunMacro("Accessibility Calculation",beta, totEmp, timeSkim)
		outputFile = OpenFile(projectFolder+hyOutputFile+"_"+TOD_skim[i]+".csv","w")
		RunMacro("Write Accessibility",accessibility, totPop, outputFile, "TAZ, Accessibility")
		
		//jobs accessible in 30,45,60 minutes by auto
		for j = 1 to timeBoundary_auto.length do
			accessibility = RunMacro("Accessible_within_hr_for_jobs",totEmp, timeSkim, timeBoundary_auto[j])
			outputFile = OpenFile(projectFolder+hyOutputFile+"_"+TOD_skim[i]+"_"+i2s(timeBoundary_auto[j])+"mins.csv","w")
			RunMacro("Write_Accessible_in_Hr",accessibility, outputFile, totEmp, "TAZ, AccessibleJobs, Coverage(%)")
		end
	end
endMacro

Macro "Calculate Active Accessibility" (sceFolder,projectFolder)
	
	RunMacro("TCB Init")
	
	//Aggregate total pop and tatal emp in MAZ to TAZ
	{maz_lyr} = RunMacro("TCB Add DB Layers", sceFolder+"maz\\maz.dbd")
	{taz_lyr} = RunMacro("TCB Add DB Layers", sceFolder+"maz\\taz.dbd")
	
	//This is only for temporary since the outputs are a little bit off in aggregation
	//Using ColumnAggregate
	ColumnAggregate(taz_lyr + "|", 0, maz_lyr + "|", {{"POP", "Sum", "TOTAL_POP", },{"TOTAL_EMP", "Sum", "TOTAL_EMP", }}, null)
	//Using JoinView
	//aggr = {{"TOTAL_POP", {{"Sum"}}}, {"TOTAL_EMP", {{"Sum"}}}}
	//view2 = JoinViews("total pop and emp", taz_lyr+".TAZ", maz_lyr+".TAZ", {{"A", }, {"Fields", aggr}})
	
	//output file
	hyOutputFile = "output_accessibility_active" //.csv"
	
	//accessibility parameter
	beta = 2.25
	timeBoundary_auto={30,45} //20 minutes for bike 15 minutes for walk
	
	//get TAZ population and employment
	SortOpts = null
	SortOpts.[Sort Order] = {{"TAZ", "Ascending"}}
	totEmp =  GetDataVector(taz_lyr + "|", "TOTAL_EMP", SortOpts)
	totPop =  GetDataVector(taz_lyr + "|", "POP", SortOpts)
	
	//skim
	TOD_skim={"am","md","pm"}
	skimMtxFileName="pmLovSkm.mtx"
	
	
	for i = 1 to TOD_skim.length do
		//index for getting the size of skim
		index = null
		for j = 1 to totEmp.length do
			index = index + {i2s(j)}
		end
	
		//skim mtx (1121x1121)
		skimMtxFileName=TOD_skim[i]+"LovSkm.mtx"
		skimMtx = OpenMatrix(projectFolder + skimMtxFileName, )
		skimCores = GetMatrixCoreNames(skimMtx)
		skimCur=CreateMatrixCurrency(skimMtx, skimCores[1], , , ) 
		timeSkim = GetMatrixValues(skimCur, index, index)
		
		//accessibility
		accessibility = RunMacro("Accessibility Calculation",beta, totEmp, timeSkim)
		outputFile = OpenFile(projectFolder+hyOutputFile+"_"+TOD_skim[i]+".csv","w")
		RunMacro("Write Accessibility",accessibility, totPop, outputFile, "TAZ, Accessibility")
		
		//jobs accessible in 30,45,60 minutes by auto
		for j = 1 to timeBoundary_auto.length do
			accessibility = RunMacro("Accessible_within_hr_for_jobs",totEmp, timeSkim, timeBoundary_auto[j])
			outputFile = OpenFile(projectFolder+hyOutputFile+"_"+TOD_skim[i]+"_"+i2s(timeBoundary_auto[j])+"mins.csv","w")
			RunMacro("Write_Accessible_in_Hr",accessibility, outputFile, totEmp, "TAZ, AccessibleJobs, Coverage(%)")
		end
	end
endMacro

Macro "Write_Accessible_in_Hr" (accessibility,outputFile,Jobs,title)
	totJobs=VectorStatistic(Jobs,"Sum",)
	WriteLine(outputFile,title)
	for i = 1 to accessibility.length do
		WriteLine(outputFile, String(i)+","+String(accessibility[i])+","+String(accessibility[i]/totJobs*100))
	end
endMacro

Macro "Accessible_within_hr_for_jobs" (jobs, travelTime, boundMinutes)
	Dim accessibility[jobs.length]
	
	if jobs.length <> travelTime.length or jobs.length <> travelTime[1].length then do
		ShowMessage("The size of jobs is incompatible with the size of travel time")
		accessibility = null
		goto quit
	end
	
	for i = 1 to jobs.length do
		
		accessibility[i] = 0.
		for j = 1 to jobs.length do
			if travelTime[i][j]<=boundMinutes then do
				accessibility[i] = accessibility[i] + jobs[j]
			end
		end
	end
	
	quit:
		return(accessibility)
	
endMacro

Macro "Write Accessibility" (accessibility, totPop, outputFile, title)
	
	WriteLine(outputFile,title)        
	
	if accessibility <> null then do
		sumWghtPopAcc=0
		for i = 1 to accessibility.length do
			sumWghtPopAcc = sumWghtPopAcc + accessibility[i]*totPop[i]
			WriteLine(outputFile, String(i)+","+String(accessibility[i]))
		end
	end
	
	//Regional Accessibility
	sumPop=VectorStatistic(totPop,"Sum",)
	regionalAcc=sumWghtPopAcc/sumPop
	WriteLine(outputFile, "regionalAcc,"+String(regionalAcc))
	
	//WriteLine("")
	CloseFile(outputFile)

endMacro

Macro "Accessibility Calculation" (beta, sizeVariable, impedance)

	Dim accessibility[sizeVariable.length]
	
	if sizeVariable.length <> impedance.length or sizeVariable.length <> impedance[1].length then do
		ShowMessage("The size of size variable is incompatible with the size of impedanace variable")
		accessibility = null
		goto quit
	end
	
	for i = 1 to sizeVariable.length do

		accessibility[i] = 0.
		for j = 1 to sizeVariable.length do
			/*if sizeVariable[j] > 1 then do//if the size variable is less than 1, the log function of it will contribute negatively to the total accessibility
				if impedance[i][j] < 9999 then 
					accessibility[i] = accessibility[i] + Log(sizeVariable[j])/Exp(impedance[i][j]/10.)
			end*/
			if sizeVariable[j] > 0 then do//log () in the numerator is eliminated which is only applied for running SAM as input file
				if impedance[i][j] < 9999 then 
					accessibility[i] = accessibility[i] + sizeVariable[j]/Exp(impedance[i][j]/10.)
			end
			
			//if j = 42 and (i >= 41 and i <= 43) then do
			//	ShowMessage(String(i) + "," + String(j) + "," + String(sizeVariable[j]) + "," + String(Log(sizeVariable[j])) + "," + String(impedance[i][j]) +"," + String(Exp(impedance[i][j]/10.))+"," + String(Log(sizeVariable[j])/Exp(impedance[i][j]/10.)))
			//end
			
		end
	end
			
	quit:
		return(accessibility)

endMacro

Macro "Transit_Service_by_Route" (sceFolder,projectFolder,year)
	
	RunMacro("TCB Init")
	
	TOD={"PM","MID"}
	OutputTOD = {"PK","OP"}

	//get highway layer
	rdFileName = sceFolder +"highway\\roadway.dbd"
	{node_lyr,link_lyr} = RunMacro("TCB Add DB Layers", rdFileName,,) 
	//ok = (link_lyr <> null)  
	//if !ok then goto quit
	
	//SortOpts = null
	//SortOpts.[Sort Order] = {{"ID", "Ascending"}}
	//linkVector = GetDataVectors(link_lyr+"|",{"ID","Length"},SortOpts)
	linkVector = VectorToArray(GetDataVector(link_lyr+"|","ID",))
	lengthVector = VectorToArray(GetDataVector(link_lyr+"|","Length",))
	
	//get route and stop layer from *.rst file
	transitFolder=sceFolder+"transit\\"
	pm_outputArray = null
	mid_outputArray = null

	for i = 1 to TOD.length do
		tod=TOD[i]
		rs_file=transitFolder+tod+"ETRNWTW.rts"
		
		{rt_lyr} = RunMacro("TCB Add RS Layers", rs_file, "ALL",)
		//ok = (rt_lyr <> null & stop_lyr <> null)  
		//if !ok then goto quit
		
		routeVectors = null
		routeVectors =  GetDataVectors(rt_lyr + "|", {"Route_ID","Route_Name","Mode","Headway","Distance","Time"},)
		
		for r=1 to routeVectors[1].length do
			rteName=routeVectors[2][r]
			links=GetRouteLinks(rt_lyr,rteName)
			
			routeDist=0
			for l=1 to links.length do
				linkID1 = links[l][1]
				index = ArrayPosition(linkVector,{linkID1},) //look-up table in-built
				if index = 0 then do 
					ShowMessage("Can't find the link index")
					goto quit
				end
				else do
					dist = lengthVector[index]
					routeDist = routeDist + dist
				end
			end
			
			routeVectors[5][r]=routeDist
			headway=routeVectors[4][r]
			routeVectors[6][r]=routeDist/headway*60
			//routeVectors[6][r]=(60/headway)/routeDist //frequency per mile
		end
		
		if tod="PM" then do
			pm_outputArray={routeVectors[2],routeVectors[3],routeVectors[5],routeVectors[4],routeVectors[6]}
		end
		else do
			mid_outputArray={routeVectors[2],routeVectors[3],routeVectors[5],routeVectors[4],routeVectors[6]}
		end
	end
	
	//output
	strOutputHeader="RouteName,Mode,Dist,Headway,DistPerFreq(PerHr)"
	//Rural  5
    //Regular 6 
    //Express 7
    //CatTran 9
    //BRT 10
    outputFile = projectFolder + "output_TransitPerFreq.csv"
	outFile=OpenFile(outputFile,"w")
	WriteLine(outFile,"source,measures,dim1,dim1_value,dim2,dim2_value,Scenario,measure_name,measure_value")
	for i = 1 to TOD.length do
		tod=TOD[i]
		//outputFile = projectFolder + "output_TransitService"+tod+".csv"
		//outFile=OpenFile(outputFile,"w")
		//WriteLine(outFile,strOutputHeader)
			
		outputArray=null
		if tod="PM" then do
			outputArray=pm_outputArray
		end
		else do
			outputArray=mid_outputArray
		end
		
		/*for j=1 to outputArray[1].length do
			strOutLine = outputArray[j][1] + ","+ r2s(outputArray[j][2]) + ","+ r2s(outputArray[j][3]) + ","+ r2s(outputArray[j][4]) + ","+ r2s(outputArray[j][5]) + ","+ r2s(outputArray[j][6])
		end*/
		
		// j is time of day
		// k  = 2 Mode k = 5 prequency?
		RuralPrequency = 0
		RegularPrequency = 0
		ExpressPrequency = 0
		CatTranPrequency = 0
		BRTPrequency = 0
		for k = 1 to outputArray[1].length do
			if outputArray[2][k] = 5 then do
				RuralPrequency = RuralPrequency + outputArray[5][k]
			end
			else if outputArray[2][k] = 6 then do
				 RegularPrequency  = RegularPrequency + outputArray[5][k]
			end
			else if outputArray[2][k] = 7 then do
				ExpressPrequency  = ExpressPrequency + outputArray[5][k]
			end
			else if outputArray[2][k] = 9 then do
				CatTranPrequency  = CatTranPrequency + outputArray[5][k]
			end
			else if outputArray[2][k] = 10 then do
				BRTPrequency  = BRTPrequency + outputArray[5][k]
            end					
		end
		WriteLine(outFile,"ABM,TransitMilesPerFrequency,Mode,Rural,TimePeriod,"+OutputTOD[i]+","+year+",TransitMilesPerFrequency," + r2s(RuralPrequency))
		WriteLine(outFile,"ABM,TransitMilesPerFrequency,Mode,Regular,TimePeriod,"+OutputTOD[i]+","+year+",TransitMilesPerFrequency," + r2s(RegularPrequency))
		WriteLine(outFile,"ABM,TransitMilesPerFrequency,Mode,Express,TimePeriod,"+OutputTOD[i]+","+year+",TransitMilesPerFrequency," + r2s(ExpressPrequency))
		WriteLine(outFile,"ABM,TransitMilesPerFrequency,Mode,CatTran,TimePeriod,"+OutputTOD[i]+","+year+",TransitMilesPerFrequency," + r2s(CatTranPrequency))
		WriteLine(outFile,"ABM,TransitMilesPerFrequency,Mode,BRT,TimePeriod,"+OutputTOD[i]+","+year+",TransitMilesPerFrequency," + r2s(BRTPrequency))	
	end
	quit:
	
endMacro

Macro "Highway_Lane_Miles" (sceFolder,projectFolder, year)
	
	RunMacro("TCB Init")
	
	linkClassSet={"freeway","parkway","major_arterial","minor_arterial","collector","ramp","frontage_road"}
	outputArr={0,0,0,0,0,0,0}
	
	//get highway layer
	rdFileName = sceFolder +"highway\\roadway.dbd"
	{node_lyr,link_lyr} = RunMacro("TCB Add DB Layers", rdFileName,,) 
	
	SetLayer(link_lyr)
	for i=1 to linkClassSet.length do
		linkclass=linkClassSet[i]
		qry = if linkclass="freeway" then
			"Select * where [AB LINKCLASS] = 1 or [BA LINKCLASS] = 1"
		else if linkclass="parkway" then
			"Select * where [AB LINKCLASS] = 2 or [BA LINKCLASS] = 2"
		else if linkclass="major_arterial" then
			"Select * where [AB LINKCLASS] = 3 or [BA LINKCLASS] = 3"
		else if linkclass="minor_arterial" then
			"Select * where [AB LINKCLASS] = 4 or [BA LINKCLASS] = 4"
		else if linkclass="collector" then
			"Select * where [AB LINKCLASS] = 5 or [BA LINKCLASS] = 5"
		else if linkclass="ramp" then
			"Select * where [AB LINKCLASS] = 6 or [BA LINKCLASS] = 6"
		else
			"Select * where [AB LINKCLASS] = 7 or [BA LINKCLASS] = 7"
			
		curSelection=SelectByQuery("Selection", "Several", qry,)
		
		laneMilesArr=null
		linkVector = GetDataVectors(link_lyr+"|Selection",{"ID","Length","[AB LANES]","[BA LANES]"},{{"Column Based","True"},{"Missing as Zero","True"}})
		laneMilesArr=linkVector[2]*(linkVector[3]+linkVector[4])
		totalLaneMiles=VectorStatistic(laneMilesArr,"Sum",)
		outputArr[i]=totalLaneMiles
	end
	//linkclass lanemile
	outputFile = projectFolder + "output_HighwayLaneMiles.csv"
	outFile=OpenFile(outputFile,"w")
	WriteLine(outFile,"source,measures,dim1,dim1_value,dim2,dim2_value,Scenario,measure_name,measure_value")
	
	//WriteLine(outFile,"LINKCLASS,TotalLaneMiles")
	for i=1 to outputArr.length do
	    WriteLine(outFile,"ABM,HighwayLaneMiles,LINKCLASS,"+linkClassSet[i]+",,," + year + ",HighwayLaneMiles,"+r2s(outputArr[i]))
		//WriteLine(outFile,linkClassSet[i]+","+r2s(outputArr[i]))
	end
	
endMacro

Macro "Travel_Time_Index" (sceFolder,projectFolder,year)
//Update AM and PM TTI

	RunMacro("TCB Init")
	
	//highway
	highway_db=sceFolder+"out\\ASN_subzone.dbd"
	{node_lyr,line_lyr} = RunMacro("TCB Add DB Layers", highway_db,,)
	
	TOD={"AM","PM"}
	
	sumAMtimes=0
	sumPMtimes=0
	for i=1 to TOD.length do
		tod=TOD[i]
		
		flowFileName="ASN_subzone.bin"
		vwFlows = RunMacro("TCB OpenTable", "Flow Table",, {sceFolder+"out\\"+flowFileName,})
		//vwJoin = JoinViews("Highway+Flow Table", line_lyr + ".ID", vwFlows + ".ID1",)
		//vecABLinkTimes = GetDataVectors(vwJoin+"|",{"[AB LINKCLASS]",vwFlows+".AB_Time",vwFlows+".BA_Time","[AB FF TIME]","[BA FF TIME]",vwFlows+".AB_Flow",vwFlows+".BA_Flow"},{{"Column Based","True"},{"Missing as Zero","True"}})
		vecABLinkTimes = GetDataVectors(vwFlows+"|",{"[AB LINKCLASS]","[AB "+TOD[i]+" Time]","[BA "+TOD[i]+" Time]","[AB FF Time]","[BA FF Time]","AB Flow "+TOD[i],"BA Flow "+TOD[i]},{{"Column Based","True"},{"Missing as Zero","True"}})

		vecLinkType=vecABLinkTimes[1]
		vecABTimes=vecABLinkTimes[2]
		vecBATimes=vecABLinkTimes[3]
		vecABFFtimes=vecABLinkTimes[4]
		vecBAFFtimes=vecABLinkTimes[5]
		vecABFlows=vecABLinkTimes[6]
		vecBAFlows=vecABLinkTimes[7]
		
		for j=1 to vecLinkType.length do
			if vecLinkType[j]<> 9 then do
				if vecABFFtimes[j]>=99999 then do
					vecABFFtimes[j]=0
				end
				if vecBAFFtimes[j]>=99999 then do
					vecBAFFtimes[j]=0
				end
				if vecABTimes[j]>=99999 then do
					vecABTimes[j]=0
				end
				if vecBATimes[j]>=99999 then do
					vecBATimes[j]=0
				end
			end
			else do //exclude centroid connector info
				vecABTimes[j]=0
				vecBATimes[j]=0
				vecABFFtimes[j]=0
				vecBAFFtimes[j]=0
			end
		end
		
		//weighted by flows
		vecABTimes = vecABTimes*vecABFlows
		vecBATimes = vecBATimes*vecBAFlows
		vecABFFtimes = vecABFFtimes*vecABFlows
		vecBAFFtimes = vecBAFFtimes*vecBAFlows
		
		//TTI Calculation
		if tod="AM" then do
			sumAMtimes=VectorStatistic(vecABTimes,"Sum",)+VectorStatistic(vecBATimes,"Sum",)
			sumFFtimes=VectorStatistic(vecABFFtimes,"Sum",)+VectorStatistic(vecBAFFtimes,"Sum",)
			TTI_AM=sumAMtimes/sumFFtimes
		end
		else do
			sumPMtimes=sumPMtimes+VectorStatistic(vecABTimes,"Sum",)+VectorStatistic(vecBATimes,"Sum",)
			sumFFtimes=VectorStatistic(vecABFFtimes,"Sum",)+VectorStatistic(vecBAFFtimes,"Sum",)
			TTI_PM=sumPMtimes/sumFFtimes
		end
	end
	
	outputFile = projectFolder + "output_TravelTimeIndex.csv"
	outFile=OpenFile(outputFile,"w")
	WriteLine(outFile,"source,measures,dim1,dim1_value,dim2,dim2_value,Scenario,measure_name,measure_value")
	WriteLine(outFile,"ABM,TravelTimeIndex,TimePeriod,AM,,," + year + ",TravelTimeIndex," + r2s(TTI_AM))
	WriteLine(outFile,"ABM,TravelTimeIndex,TimePeriod,PM,,," + year + ",TravelTimeIndex," + r2s(TTI_PM))
 	//quit:
	//	ShowMessage("Finished: Travel Time Index (output_TravelTimeIndex.csv)")

endMacro

Macro "Pop_Emp_QuarterMile" (sceFolder,projectFolder, year)
	RunMacro("TCB Init")

	outputFile1 = projectFolder + "output_TransitQuarterMilePopEmp.csv"
	
	//transit route
	route_db=sceFolder+"transit\\PMETRNWTWS.dbd"
	{route_lyr} = RunMacro("TCB Add DB Layers", route_db,,)
	SetLayer(route_lyr)
	
	//create buffers
	qry = "Select * where ID > 0"
	SelectByQuery("curSelection", "Several", qry,)
	bufferDB=projectFolder+"QuarterBuffer.dbd"
	CreateBuffers(bufferDB ,"Quarter buffer", {"curSelection"}, "Value", {0.25}, {{"Exterior", "Merged"}, {"Interior", "Merged"}, {"Units", "Miles"}})
	
	//calc overlap percentage
	bufferlyr = null
	{bufferlyr} = RunMacro("TCB Add DB Layers", projectFolder+"QuarterBuffer.dbd") 
	{mazlyr} = RunMacro("TCB Add DB Layers", sceFolder+"maz\\maz.dbd")
	ComputeIntersectionPercentages({bufferlyr,mazlyr}, projectFolder+"Intersect.dbf",{{"Database", projectFolder+"Intersect1.dbd"},{"Optimize", "False"}})
	
	//calc share of pop and emp within quarter-mile of transit stops
	setLayer(mazlyr)
	vecMAZs = GetDataVector(mazlyr+"|", "ID",)
	vecQPerct = Vector(vecMAZs.length, "Float", {{"Constant", 0.0}})
	vecPopAndEmp= GetDataVectors(mazlyr+"|", {"ID","TOTAL_POP","TOTAL_EMP","DISADV"},{{"Sort Order",{{"ID", "Ascending"}}},{"Column Based","True"}})
	intersectDBF = OpenTable("intersection", "DBASE", {projectFolder+"Intersect.dbf"},{{"Shared", "True"}})
	vecIntDBF = GetDataVectors(intersectDBF+"|",{"ID","AREA_1","AREA_2","PERCENT_2"},{{"Column Based","True"}})
	
	tmpMAZVec=vecIntDBF[2]*vecIntDBF[3]
	tmpPertVec=vecIntDBF[2]*vecIntDBF[4]
	
	for i = 1 to tmpMAZVec.length do
		if tmpMAZVec[i] > 0 then do
			mazID=tmpMAZVec[i]
			vecQPerct[mazID]=tmpPertVec[i]
		end
	end
	
	vecPop=vecPopAndEmp[2]
	sumPop=VectorStatistic(vecPop,"Sum",)
	vecEmp=vecPopAndEmp[3]
	sumEmp=VectorStatistic(vecEmp,"Sum",)
	vecDisADV=vecPopAndEmp[4]
	
	
	vecPopQPerct = Vector(vecMAZs.length, "Float", {{"Constant", 0.0}})
	vecPopQPerctDISADV = Vector(vecMAZs.length, "Float", {{"Constant", 0.0}})
	sumPopDisADV = Vector(vecMAZs.length, "Float", {{"Constant", 0.0}})

	vecEmpQPerct = Vector(vecMAZs.length, "Float", {{"Constant", 0.0}})
	vecEmpQPerctDISADV = Vector(vecMAZs.length, "Float", {{"Constant", 0.0}})
	sumEmpDisADV = Vector(vecMAZs.length, "Float", {{"Constant", 0.0}})


	for i=1 to vecMAZs.length do
		vecPopQPerct[i]=vecQPerct[i]*vecPop[i]
		vecPopQPerctDISADV[i]= vecQPerct[i]*vecPop[i]*vecDisADV[i]
		sumPopDisADV[i] = vecPop[i]*vecDisADV[i]
		vecEmpQPerct[i]=vecQPerct[i]*vecEmp[i]
		vecEmpQPerctDISADV[i]=vecQPerct[i]*vecEmp[i]*vecDisADV[i]
		sumEmpDisADV[i] = vecEmp[i]*vecDisADV[i]
	end
	
	sumQPop=VectorStatistic(vecPopQPerct,"Sum",)
	sumQEmp=VectorStatistic(vecEmpQPerct,"Sum",)
	
	
	sumQPopDisADV = VectorStatistic(vecPopQPerctDISADV,"Sum",)
	sumQEmpDisADV = VectorStatistic(vecEmpQPerctDISADV,"Sum",)
	
	TotalsumQPopDisADV = VectorStatistic(sumPopDisADV,"Sum",)
	TotalsumQEmpDisADV = VectorStatistic(sumEmpDisADV,"Sum",)


	ratioPop=sumQPop/sumPop
	ratioEmp=sumQEmp/sumEmp
	
	ratioPopDisADV = sumQPopDisADV/TotalsumQPopDisADV
	ratioEmpDisADV = sumQEmpDisADV/TotalsumQEmpDisADV
	
	outFile1=OpenFile(outputFile1,"w")
	WriteLine(outFile1,"source,measures,dim1,dim1_value,dim2,dim2_value,Scenario,measure_name,measure_value")
	WriteLine(outFile1,"ABM,TransitQuarterMilePopEmp,Type,Total,,," + year + ",Population," + r2s(sumPop))
	WriteLine(outFile1,"ABM,TransitQuarterMilePopEmp,Type,Number,,," + year + ",Population," + r2s(sumQPop))
	WriteLine(outFile1,"ABM,TransitQuarterMilePopEmp,Type,Percentage,,," + year + ",Population," + r2s(ratioPop))
	WriteLine(outFile1,"ABM,TransitQuarterMilePopEmp,Type,TotalDISADV,,," + year + ",Population," + r2s(TotalsumQPopDisADV))
	WriteLine(outFile1,"ABM,TransitQuarterMilePopEmp,Type,NumberDISADV,,," + year + ",Population," + r2s(sumQPopDisADV))
	WriteLine(outFile1,"ABM,TransitQuarterMilePopEmp,Type,PercentageDISADV,,," + year + ",Population," + r2s(ratioPopDisADV))
	WriteLine(outFile1,"ABM,TransitQuarterMilePopEmp,Type,Total,,," + year + ",Jobs," + r2s(sumEmp))
	WriteLine(outFile1,"ABM,TransitQuarterMilePopEmp,Type,Number,,," + year + ",Jobs," + r2s(sumQEmp))
	WriteLine(outFile1,"ABM,TransitQuarterMilePopEmp,Type,Percentage,,," + year + ",Jobs," + r2s(ratioEmp))
	WriteLine(outFile1,"ABM,TransitQuarterMilePopEmp,Type,TotalDISADV,,," + year + ",Jobs," + r2s(TotalsumQEmpDisADV))
	WriteLine(outFile1,"ABM,TransitQuarterMilePopEmp,Type,NumberDISADV,,," + year + ",Jobs," + r2s(sumQEmpDisADV))
	WriteLine(outFile1,"ABM,TransitQuarterMilePopEmp,Type,PercentageDISADV,,," + year + ",Jobs," + r2s(ratioEmpDisADV))
	//WriteLine(outFile1,"Pop_1/4_mile, Emp_1/4_mile,Pop,Emp,ratio_Pop,ratio_Emp")
	//WriteLine(outFile1,r2s(sumQPop)+","+r2s(sumQEmp)+","+r2s(sumPop)+","+r2s(sumEmp)+","+r2s(ratioPop)+","+r2s(ratioEmp))
	
	//quit:
	//	ShowMessage("Finished: Quarter-Mile POP and EMP (output_TransitQuarterMilePopEmp.csv)")
	
endMacro

Macro "Average_Transit_Speed" (sceFolder,projectFolder, year)
	RunMacro("TCB Init")
	//tassn_flow_OP_KNR_CON_WLK.bin
	
	//tod
	TODF={"OP","PK"}
	
	//transit cores
	transitAccessEgress={{"WLK","WLK"},{"WLK","KNR"},{"WLK","PNR"},{"KNR","WLK"},{"PNR","WLK"}}
	transitLineHaul={"PRE","CON"}
	//transitAccessF = {{{"w","w"},{"w","a"},{"w","k"}},{{"w","w"},{"a","w"},{"k","w"}}}
	
	sumIVT=0
	sumDist=0
	sumWIVT=0
	sumWDist=0
	for i=1 to TODF.length do
		//flows vector for weighting average speed of transit service
		for j=1 to transitAccessEgress.length do
			for k=1 to transitLineHaul.length do
				lineFileName="tassn_flow_"+TODF[i]+"_"+transitAccessEgress[i][1]+"_"+transitLineHaul[k]+"_"+transitAccessEgress[i][2]+".bin"	
				vwLineFlows = OpenTable("Line Info", "FFB", {projectFolder+lineFileName,})
				tmpLineFlows=GetDataVector(vwLineFlows+"|","TransitFlow",{{"Column Based","True"}})
				if j=1 and k=1then do
					vecFlows=tmpLineFlows
				end
				else do
					for m=1 to vecFlows.length do
						vecFlows[m]=vecFlows[m]+tmpLineFlows[m]
					end
				end
				
			end
		end
		
		sumIVT_TOD=0
		sumDist_TOD=0
		sumWIVT_TOD=0
		sumWDist_TOD=0
		for j=1 to transitAccessEgress.length do
			for k=1 to transitLineHaul.length do
				lineFileName="tassn_flow_"+TODF[i]+"_"+transitAccessEgress[i][1]+"_"+transitLineHaul[k]+"_"+transitAccessEgress[i][2]+".bin"	
				vwLineFlows = OpenTable("Line Info", "FFB", {projectFolder+lineFileName,})
				vecLineFlows = GetDataVectors(vwLineFlows+"|",{"Route","From_MP","To_MP","BaseIVTT"},{{"Column Based","True"},{"Missing as Zero","True"}})
				vecLineIVT=vecLineFlows[4]
				vecLineDist=vecLineFlows[3]-vecLineFlows[2]
			
				//for zero IVT: need to set Dist zero since it causes overestimate the speed (mile/hr)
				//and add dwelling time 30 seconds (0.5 minute)
				for m=1 to vecLineIVT.length do
					if vecLineIVT[m]=0 then do
						vecLineDist[m]=0
					end
					else do
						vecLineIVT[m]=vecLineIVT[m]+0.5
					end
				end
			
				//weighted values
				vecWeightedLineIVT=vecLineIVT*vecFlows
				vecWeightedLineDist=vecLineDist*vecFlows
				
				sumIVT_TOD=sumIVT_TOD+VectorStatistic(vecLineIVT,"Sum",)
				sumDist_TOD=sumDist_TOD+VectorStatistic(vecLineDist,"Sum",)
				sumWIVT_TOD=sumWIVT_TOD+VectorStatistic(vecWeightedLineIVT,"Sum",)
				sumWDist_TOD=sumWDist_TOD+VectorStatistic(vecWeightedLineDist,"Sum",)
				
			end
		end
		
		if i=1 then do //op
			avgPMspeed=sumDist_TOD/sumIVT_TOD*60
			wAvgPMspeed=sumWDist_TOD/sumWIVT_TOD*60
		end
		else do //pk
			avgMIDspeed=sumDist_TOD/sumIVT_TOD*60
			wAvgMIDspeed=sumWDist_TOD/sumWIVT_TOD*60
		end
		
		sumIVT=sumIVT+sumIVT_TOD
		sumDist=sumDist+sumDist_TOD
		sumWIVT=sumWIVT+sumWIVT_TOD
		sumWDist=sumWDist+sumWDist_TOD
		
	end
	
	avgSpeed=sumDist/sumIVT*60 //mph
	wAvgSpeed=sumWDist/sumWIVT*60
	
	outputFile = projectFolder + "output_TransitSpeed.csv"
	outFile=OpenFile(outputFile,"w")
	WriteLine(outFile,"source,measures,dim1,dim1_value,dim2,dim2_value,Scenario,measure_name,measure_value")
	WriteLine(outFile,"ABM,AverageTransitSpeed,TimePeriod,PK,,," + year + ",AverageTransitSpeed,"  + r2s(wAvgPMspeed))
	WriteLine(outFile,"ABM,AverageTransitSpeed,TimePeriod,OP,,," + year + ",AverageTransitSpeed,"  + r2s(wAvgMIDspeed))
	WriteLine(outFile,"ABM,AverageTransitSpeed,TimePeriod,DY,,," + year + ",AverageTransitSpeed,"  + r2s(wAvgSpeed))
    //SetGlobal varaible. PK-PM OP-MID DY-wAvg   
	//WriteLine(outFile,","+r2s(avgPMspeed)+","+r2s(avgMIDspeed)+","+r2s(avgSpeed))
	//WriteLine(outFile,"FlowWeighted,"+r2s(wAvgPMspeed)+","+r2s(wAvgMIDspeed)+","+r2s(wAvgSpeed))
	
	quit:
		//ShowMessage("Finished: Average Transit Speed (output_TransitSpeed.csv)")
	
endMacro


Macro "Tucson Subzone LOS Calculations" (sceFolder,projectFolder, year)
RunMacro("TCB Init")
//Peak Hour factors for AM/PM
AM_PHF = "0.5920"
PM_PHF = "0.5131"
//Upper bound for highway service flow rate (pc/h/ln). LOSF is > HWYxxE
HWY75A = "820"
HWY75B = "1350"
HWY75C = "1830"
HWY75D = "2170"
HWY75E = "2400"
HWY70A = "770"
HWY70B = "1260"
HWY70C = "1770"
HWY70D = "2150"
HWY70E = "2400"
HWY65A = "710"
HWY65B = "1170"
HWY65C = "1680"
HWY65D = "2090"
HWY65E = "2350"
HWY60A = "660"
HWY60B = "1080"
HWY60C = "1560"
HWY60D = "2020"
HWY60E = "2300"
HWY55A = "600"
HWY55B = "990"
HWY55C = "1430"
HWY55D = "1910"
HWY55E = "2250"
//Lower bound of speed bin
Urb50A = "42"
Urb50B = "34"
Urb50C = "27"
Urb50D = "21"
Urb50E = "16"
Urb40A = "35"
Urb40B = "28"
Urb40C = "22"
Urb40D = "17"
Urb40E = "13"
Urb30A = "25"
Urb30B = "19"
Urb30C = "13"
Urb30D = "9"
Urb30E = "7"
//Create AM/PM Peak Hour fields===============================================================
highway_db=sceFolder+"out\\ASN_subzone.dbd"
{node_lyr,link_lyr} = RunMacro("TCB Add DB Layers", highway_db,,)
line_lyr = RenameLayer(link_lyr, "subzonelinelayer", {{"Permanent","true"}})



NewFlds = {{"AB_AM_PH_Q",   "real"},
   {"BA_AM_PH_Q",   "real"},
   {"AB_PM_PH_Q",   "real"},
   {"BA_PM_PH_Q",   "real"},
   {"AB_AM_PH_V",   "real"},
   {"BA_AM_PH_V",   "real"},
   {"AB_PM_PH_V",   "real"},
   {"BA_PM_PH_V",   "real"}
   }
populateFlds = {"AB_AM_PH_Q","BA_AM_PH_Q","AB_PM_PH_Q","BA_PM_PH_Q","AB_AM_PH_V","BA_AM_PH_V","AB_PM_PH_V","BA_PM_PH_V"}
ok = RunMacro("TCB Add View Fields", {"subzonelinelayer", NewFlds})



Opts = null
Opts.Input.[Dataview Set] = {highway_db+"|subzonelinelayer", "subzonelinelayer"}
Opts.Global.Fields = {"AB_AM_PH_Q", "BA_AM_PH_Q", "AB_PM_PH_Q", "BA_PM_PH_Q"}
Opts.Global.Method = "Formula"
Opts.Global.Parameter = {"[AB Flow AM] * " + AM_PHF, 
						"[BA Flow AM] * " + AM_PHF, 
						"[AB Flow PM] * " + PM_PHF, 
						"[BA Flow PM] * " + PM_PHF}
ok = RunMacro("TCB Run Operation", "Fill Dataview", Opts) 
if !ok then goto quit

Opts = null
Opts.Input.[Dataview Set] = {highway_db+"|subzonelinelayer", "subzonelinelayer"}
Opts.Global.Fields = {"AB_AM_PH_V", "BA_AM_PH_V", "AB_PM_PH_V", "BA_PM_PH_V"}
Opts.Global.Method = "Formula"
Opts.Global.Parameter = {"nulltozero(if AB_GC >0 then 1 else 0)",
						"nulltozero(if BA_GC >0 then 1 else 0)",
						"nulltozero(if AB_GC >0 then 1 else 0)",
						"nulltozero(if BA_GC >0 then 1 else 0)"}
ok = RunMacro("TCB Run Operation", "Fill Dataview", Opts) 
if !ok then goto quit

Opts = null
Opts.Input.[Dataview Set] = {highway_db+"|subzonelinelayer", "subzonelinelayer"}
Opts.Global.Fields = {"AB_AM_PH_V", "BA_AM_PH_V", "AB_PM_PH_V", "BA_PM_PH_V"}
Opts.Global.Method = "Formula"
Opts.Global.Parameter = {"nulltozero(AB_AM_PH_V * AB_PF * AB_Cycle / 2 * Pow((1 - AB_GC),2))", 
						"nulltozero(BA_AM_PH_V * BA_PF * BA_Cycle / 2 * Pow((1 - BA_GC),2))", 
						"nulltozero(AB_PM_PH_V * AB_PF * AB_Cycle / 2 * Pow((1 - AB_GC),2))", 
						"nulltozero(BA_PM_PH_V * BA_PF * BA_Cycle / 2 * Pow((1 - BA_GC),2))"}
ok = RunMacro("TCB Run Operation", "Fill Dataview", Opts) 
if !ok then goto quit

Opts = null
Opts.Input.[Dataview Set] = {highway_db+"|subzonelinelayer", "subzonelinelayer"}
Opts.Global.Fields = {"AB_AM_PH_V", "BA_AM_PH_V", "AB_PM_PH_V", "BA_PM_PH_V"}
Opts.Global.Method = "Formula"
Opts.Global.Parameter = {"nulltozero(AB_AM_PH_V * (1+[AB Alpha2] * Pow((0.85 * AB_AM_PH_Q / ([AB AM CAP] * AB_GC / 2)), [AB Beta2])))", 
						"nulltozero(BA_AM_PH_V * (1+[BA Alpha2] * Pow((0.85 * BA_AM_PH_Q / ([BA AM CAP] * BA_GC / 2)), [BA Beta2])))", 
						"nulltozero(AB_PM_PH_V * (1+[AB Alpha2] * Pow((0.85 * AB_PM_PH_Q / ([AB PM CAP] * AB_GC / 2)), [AB Beta2])))", 
						"nulltozero(BA_PM_PH_V * (1+[BA Alpha2] * Pow((0.85 * BA_PM_PH_Q / ([BA PM CAP] * BA_GC / 2)), [BA Beta2])))"}
ok = RunMacro("TCB Run Operation", "Fill Dataview", Opts) 
if !ok then goto quit

Opts = null
Opts.Input.[Dataview Set] = {highway_db+"|subzonelinelayer", "subzonelinelayer"}
Opts.Global.Fields = {"AB_AM_PH_V", "BA_AM_PH_V", "AB_PM_PH_V", "BA_PM_PH_V"}
Opts.Global.Method = "Formula"
Opts.Global.Parameter = {"nulltozero(AB_AM_PH_V)", 
						"nulltozero(BA_AM_PH_V)", 
						"nulltozero(AB_PM_PH_V)", 
						"nulltozero(BA_PM_PH_V)"}
ok = RunMacro("TCB Run Operation", "Fill Dataview", Opts) 
if !ok then goto quit

Opts = null
Opts.Input.[Dataview Set] = {highway_db+"|subzonelinelayer", "subzonelinelayer"}
Opts.Global.Fields = {"AB_AM_PH_V", "BA_AM_PH_V", "AB_PM_PH_V", "BA_PM_PH_V"}
Opts.Global.Method = "Formula"
Opts.Global.Parameter = {"AB_AM_PH_V + [AB FF TIME]*(1+[AB Alpha]* Pow(AB_AM_PH_Q/([AB AM CAP]/2),[AB Beta]))", 
						"BA_AM_PH_V + [BA FF TIME]*(1+[BA Alpha]* Pow(BA_AM_PH_Q/([BA AM CAP]/2),[BA Beta]))", 
						"AB_PM_PH_V + [AB FF TIME]*(1+[AB Alpha]* Pow(AB_PM_PH_Q/([AB PM CAP]/2),[AB Beta]))", 
						"BA_PM_PH_V + [BA FF TIME]*(1+[BA Alpha]* Pow(BA_PM_PH_Q/([BA PM CAP]/2),[BA Beta]))"}
ok = RunMacro("TCB Run Operation", "Fill Dataview", Opts) 
if !ok then goto quit

Opts = null
Opts.Input.[Dataview Set] = {highway_db+"|subzonelinelayer", "subzonelinelayer"}
Opts.Global.Fields = {"AB_AM_PH_V", "BA_AM_PH_V", "AB_PM_PH_V", "BA_PM_PH_V"}
Opts.Global.Method = "Formula"
Opts.Global.Parameter = {"([AB Length] * 60) / AB_AM_PH_V", 
						"([BA Length] * 60) / BA_AM_PH_V", 
						"([AB Length] * 60) / AB_PM_PH_V", 
						"([BA Length] * 60) / BA_PM_PH_V"}
ok = RunMacro("TCB Run Operation", "Fill Dataview", Opts) 
if !ok then goto quit



//Create LOS fields===============================================================
SetLayer("subzonelinelayer")
	NewFlds = {{"AB_AM_PH_LOS",   "integer"},
   {"BA_AM_PH_LOS",   "integer"},
   {"AB_AM_LOS",   "integer"},
   {"BA_AM_LOS",   "integer"},
   {"AB_Mid_LOS",   "integer"},
   {"BA_Mid_LOS",   "integer"},
   {"AB_PM_PH_LOS",   "integer"},
   {"BA_PM_PH_LOS",   "integer"},
   {"AB_PM_LOS",   "integer"},
   {"BA_PM_LOS",   "integer"},
   {"AB_Ni_LOS",   "integer"},
   {"BA_Ni_LOS",   "integer"}
   }
	populateFlds = {"AB_AM_LOS","BA_AM_LOS","AB_Mid_LOS","BA_Mid_LOS","AB_PM_LOS","BA_PM_LOS","AB_Ni_LOS","BA_Ni_LOS"}
	ok = RunMacro("TCB Add View Fields", {"subzonelinelayer", NewFlds})

//==================================================================================================
//AB AM PH LOSA
HwyLOS_ABAM_A_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and ((AB_AM_PH_Q / [AB LANES]) <= " + HWY75A +")"
HwyLOS_ABAM_A_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and ((AB_AM_PH_Q / [AB LANES]) <= " + HWY70A +")"
HwyLOS_ABAM_A_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and ((AB_AM_PH_Q / [AB LANES]) <= " + HWY65A +")"
HwyLOS_ABAM_A_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and ((AB_AM_PH_Q / [AB LANES]) <= " + HWY60A +")"
HwyLOS_ABAM_A_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and ((AB_AM_PH_Q / [AB LANES]) <= " + HWY55A+")"
UrbLOS_ABAM_A_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and (AB_AM_PH_V > " + Urb50A + ")"
UrbLOS_ABAM_A_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and (AB_AM_PH_V > " + Urb40A + ")"
UrbLOS_ABAM_A_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and (AB_AM_PH_V > " + Urb30A + ")"


LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "several", HwyLOS_ABAM_A_75,)
LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "more", HwyLOS_ABAM_A_70,)
LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "more", HwyLOS_ABAM_A_65,)
LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "more", HwyLOS_ABAM_A_60,)
LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "more", HwyLOS_ABAM_A_55,)
LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "more", UrbLOS_ABAM_A_50,)
LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "more", UrbLOS_ABAM_A_40,)
LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "more", UrbLOS_ABAM_A_30,)

if LOS_A_ABAM > 0 then do
	LOS_A_ABAM_Vector = Vector(LOS_A_ABAM,"Short",{{"Constant",1}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|"+ "HwyLOS_A_ABAM","AB_AM_PH_LOS", LOS_A_ABAM_Vector,)
end

//BA AM PH LOSA
HwyLOS_BAAM_A_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and ((BA_AM_PH_Q / [BA LANES]) <= " + HWY75A +")"
HwyLOS_BAAM_A_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and ((BA_AM_PH_Q / [BA LANES]) <= " + HWY70A +")"
HwyLOS_BAAM_A_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and ((BA_AM_PH_Q / [BA LANES]) <= " + HWY65A +")"
HwyLOS_BAAM_A_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and ((BA_AM_PH_Q / [BA LANES]) <= " + HWY60A +")"
HwyLOS_BAAM_A_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and ((BA_AM_PH_Q / [BA LANES]) <= " + HWY55A +")"
UrbLOS_BAAM_A_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and (BA_AM_PH_V > " + Urb50A + ")"
UrbLOS_BAAM_A_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and (BA_AM_PH_V > " + Urb40A + ")"
UrbLOS_BAAM_A_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and (BA_AM_PH_V > " + Urb30A + ")"

LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "several", HwyLOS_BAAM_A_75,)
LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "more", HwyLOS_BAAM_A_70,)
LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "more", HwyLOS_BAAM_A_65,)
LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "more", HwyLOS_BAAM_A_60,)
LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "more", HwyLOS_BAAM_A_55,)
LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "more", UrbLOS_BAAM_A_50,)
LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "more", UrbLOS_BAAM_A_40,)
LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "more", UrbLOS_BAAM_A_30,)

if LOS_A_BAAM > 0 then do
	LOS_A_BAAM_Vector = Vector(LOS_A_BAAM,"Short",{{"Constant",1}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_A_BAAM","BA_AM_PH_LOS", LOS_A_BAAM_Vector,)
end

//==================================================================================================
//Highway AB AM PH LOSB
HwyLOS_ABAM_B_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY75A +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY75B +")"
HwyLOS_ABAM_B_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY70A +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY70B +")"
HwyLOS_ABAM_B_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY65A +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY65B +")"
HwyLOS_ABAM_B_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY60A +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY60B +")"
HwyLOS_ABAM_B_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY55A +" and (AB_AM_PH_Q /  [AB LANES]) <=  " + HWY55B +")"
UrbLOS_ABAM_B_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and (AB_AM_PH_V >  " + Urb50B+" and AB_AM_PH_V <= " + Urb50A + ")"
UrbLOS_ABAM_B_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and (AB_AM_PH_V >  " + Urb40B +" and AB_AM_PH_V <= " + Urb40A + ")"
UrbLOS_ABAM_B_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and (AB_AM_PH_V >  " + Urb30B+" and AB_AM_PH_V <= " + Urb30A + ")"

LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "several", HwyLOS_ABAM_B_75,)
LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "more", HwyLOS_ABAM_B_70,)
LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "more", HwyLOS_ABAM_B_65,)
LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "more", HwyLOS_ABAM_B_60,)
LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "more", HwyLOS_ABAM_B_55,)
LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "more", UrbLOS_ABAM_B_50,)
LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "more", UrbLOS_ABAM_B_40,)
LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "more", UrbLOS_ABAM_B_30,)

if LOS_B_ABAM > 0 then do
	LOS_B_ABAM_Vector = Vector(LOS_B_ABAM,"Short",{{"Constant",2}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_B_ABAM","AB_AM_PH_LOS", LOS_B_ABAM_Vector,)
end

//Highway BA AM PH LOSB
HwyLOS_BAAM_B_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY75A +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY75B +")"
HwyLOS_BAAM_B_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY70A +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY70B +")"
HwyLOS_BAAM_B_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY65A +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY65B +")"
HwyLOS_BAAM_B_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY60A +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY60B +")"
HwyLOS_BAAM_B_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (BA_AM_PH_Q / [BA LANES] >  " + HWY55A +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY55B +")"
UrbLOS_BAAM_B_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and (BA_AM_PH_V >  " + Urb50B+" and BA_AM_PH_V <= " + Urb50A + ")"
UrbLOS_BAAM_B_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and (BA_AM_PH_V >  " + Urb40B +" and BA_AM_PH_V <= " + Urb40A + ")"
UrbLOS_BAAM_B_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and (BA_AM_PH_V >  " + Urb30B+" and BA_AM_PH_V <= " + Urb30A + ")"

LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "several", HwyLOS_BAAM_B_75,)
LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "more", HwyLOS_BAAM_B_70,)
LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "more", HwyLOS_BAAM_B_65,)
LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "more", HwyLOS_BAAM_B_60,)
LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "more", HwyLOS_BAAM_B_55,)
LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "more", UrbLOS_BAAM_B_50,)
LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "more", UrbLOS_BAAM_B_40,)
LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "more", UrbLOS_BAAM_B_30,)


if LOS_B_BAAM > 0 then do
	LOS_B_BAAM_Vector = Vector(LOS_B_BAAM,"Short",{{"Constant",2}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_B_BAAM","BA_AM_PH_LOS", LOS_B_BAAM_Vector,)
end

//==================================================================================================
//Highway AB AM PH LOS C
HwyLOS_ABAM_C_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY75B +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY75C +")"
HwyLOS_ABAM_C_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY70B +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY70C +")"
HwyLOS_ABAM_C_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY65B +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY65C +")"
HwyLOS_ABAM_C_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY60B +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY60C +")"
HwyLOS_ABAM_C_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY55B +" and (AB_AM_PH_Q /  [AB LANES]) <=  " + HWY55C +")"
UrbLOS_ABAM_C_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and (AB_AM_PH_V >  " + Urb50C+" and AB_AM_PH_V <=  " + Urb50B+")"
UrbLOS_ABAM_C_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and (AB_AM_PH_V >  " + Urb40C +" and AB_AM_PH_V <=  " + Urb40B +")"
UrbLOS_ABAM_C_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and (AB_AM_PH_V >  " + Urb30C+" and AB_AM_PH_V <=  " + Urb30B+")"

LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "several", HwyLOS_ABAM_C_75,)
LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "more", HwyLOS_ABAM_C_70,)
LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "more", HwyLOS_ABAM_C_65,)
LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "more", HwyLOS_ABAM_C_60,)
LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "more", HwyLOS_ABAM_C_55,)
LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "more", UrbLOS_ABAM_C_50,)
LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "more", UrbLOS_ABAM_C_40,)
LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "more", UrbLOS_ABAM_C_30,)

if LOS_C_ABAM > 0 then do
	LOS_C_ABAM_Vector = Vector(LOS_C_ABAM,"Short",{{"Constant",3}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_C_ABAM","AB_AM_PH_LOS", LOS_C_ABAM_Vector,)
end

//Highway BA AM PH LOS C
HwyLOS_BAAM_C_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY75B +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY75C +")"
HwyLOS_BAAM_C_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY70B +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY70C +")"
HwyLOS_BAAM_C_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY65B +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY65C +")"
HwyLOS_BAAM_C_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY60B +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY60C +")"
HwyLOS_BAAM_C_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY55B +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY55C +")"
UrbLOS_BAAM_C_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and (BA_AM_PH_V >  " + Urb50C+" and BA_AM_PH_V <=  " + Urb50B+")"
UrbLOS_BAAM_C_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and (BA_AM_PH_V >  " + Urb40C +" and BA_AM_PH_V <=  " + Urb40B +")"
UrbLOS_BAAM_C_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and (BA_AM_PH_V >  " + Urb30C+" and BA_AM_PH_V <=  " + Urb30B+")"


LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "several", HwyLOS_BAAM_C_75,)
LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "more", HwyLOS_BAAM_C_70,)
LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "more", HwyLOS_BAAM_C_65,)
LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "more", HwyLOS_BAAM_C_60,)
LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "more", HwyLOS_BAAM_C_55,)
LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "more", UrbLOS_BAAM_C_50,)
LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "more", UrbLOS_BAAM_C_40,)
LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "more", UrbLOS_BAAM_C_30,)

if LOS_C_BAAM > 0 then do
	LOS_C_BAAM_Vector = Vector(LOS_C_BAAM,"Short",{{"Constant",3}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_C_BAAM","BA_AM_PH_LOS", LOS_C_BAAM_Vector,)
end

//==================================================================================================
//Highway AB AM PH LOS D
HwyLOS_ABAM_D_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY75C +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY75D +")"
HwyLOS_ABAM_D_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY70C +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY70D +")"
HwyLOS_ABAM_D_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY65C +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY65D +")"
HwyLOS_ABAM_D_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY60C +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY60D +")"
HwyLOS_ABAM_D_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY55C +" and (AB_AM_PH_Q /  [AB LANES]) <=  " + HWY55D +")"
UrbLOS_ABAM_D_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and (AB_AM_PH_V >  " + Urb50D +" and AB_AM_PH_V <=  " + Urb50C+")"
UrbLOS_ABAM_D_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and (AB_AM_PH_V >  " + Urb40D +" and AB_AM_PH_V <=  " + Urb40C +")"
UrbLOS_ABAM_D_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and (AB_AM_PH_V >  " + Urb30D +" and AB_AM_PH_V <=  " + Urb30C+")"

LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "several", HwyLOS_ABAM_D_75,)
LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "more", HwyLOS_ABAM_D_70,)
LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "more", HwyLOS_ABAM_D_65,)
LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "more", HwyLOS_ABAM_D_60,)
LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "more", HwyLOS_ABAM_D_55,)
LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "more", UrbLOS_ABAM_D_50,)
LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "more", UrbLOS_ABAM_D_40,)
LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "more", UrbLOS_ABAM_D_30,)

if LOS_D_ABAM > 0 then do
	LOS_D_ABAM_Vector = Vector(LOS_D_ABAM,"Short",{{"Constant",4}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_D_ABAM","AB_AM_PH_LOS", LOS_D_ABAM_Vector,)
end

//Highway BA AM PH LOS D
HwyLOS_BAAM_D_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY75C +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY75D +")"
HwyLOS_BAAM_D_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY70C +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY70D +")"
HwyLOS_BAAM_D_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY65C +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY65D +")"
HwyLOS_BAAM_D_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY60C +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY60D +")"
HwyLOS_BAAM_D_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY55C +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY55D +")"
UrbLOS_BAAM_D_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and (BA_AM_PH_V >  " + Urb50D +" and BA_AM_PH_V <=  " + Urb50C+")"
UrbLOS_BAAM_D_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and (BA_AM_PH_V >  " + Urb40D +" and BA_AM_PH_V <=  " + Urb40C +")"
UrbLOS_BAAM_D_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and (BA_AM_PH_V >  " + Urb30D +" and BA_AM_PH_V <=  " + Urb30C+")"

LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "several", HwyLOS_BAAM_D_75,)
LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "more", HwyLOS_BAAM_D_70,)
LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "more", HwyLOS_BAAM_D_65,)
LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "more", HwyLOS_BAAM_D_60,)
LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "more", HwyLOS_BAAM_D_55,)
LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "more", UrbLOS_BAAM_D_50,)
LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "more", UrbLOS_BAAM_D_40,)
LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "more", UrbLOS_BAAM_D_30,)

if LOS_D_BAAM > 0 then do
	LOS_D_BAAM_Vector = Vector(LOS_D_BAAM,"Short",{{"Constant",4}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_D_BAAM","BA_AM_PH_LOS", LOS_D_BAAM_Vector,)
end

//==================================================================================================
//Highway AB AM PH LOS E
HwyLOS_ABAM_E_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY75D +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY75E +")"
HwyLOS_ABAM_E_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY70D +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY70E +")"
HwyLOS_ABAM_E_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY65D +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY65E +")"
HwyLOS_ABAM_E_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY60D +" and (AB_AM_PH_Q / [AB LANES]) <=  " + HWY60E +")"
HwyLOS_ABAM_E_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY55D +" and (AB_AM_PH_Q /  [AB LANES]) <=  " + HWY55E +")"
UrbLOS_ABAM_E_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and (AB_AM_PH_V >  " + Urb50E +" and AB_AM_PH_V <=  " + Urb50D +")"
UrbLOS_ABAM_E_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and (AB_AM_PH_V > " + Urb40E + " and AB_AM_PH_V <=  " + Urb40D +")"
UrbLOS_ABAM_E_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and (AB_AM_PH_V > " + Urb30E + " and AB_AM_PH_V <=  " + Urb30D +" )"

LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "several", HwyLOS_ABAM_E_75,)
LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "more", HwyLOS_ABAM_E_70,)
LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "more", HwyLOS_ABAM_E_65,)
LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "more", HwyLOS_ABAM_E_60,)
LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "more", HwyLOS_ABAM_E_55,)
LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "more", UrbLOS_ABAM_E_50,)
LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "more", UrbLOS_ABAM_E_40,)
LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "more", UrbLOS_ABAM_E_30,)

if LOS_E_ABAM > 0 then do
	LOS_E_ABAM_Vector = Vector(LOS_E_ABAM,"Short",{{"Constant",5}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_E_ABAM","AB_AM_PH_LOS", LOS_E_ABAM_Vector,)
end

//Highway BA AM PH LOS E
HwyLOS_BAAM_E_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY75D +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY75E +")"
HwyLOS_BAAM_E_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY70D +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY70E +")"
HwyLOS_BAAM_E_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY65D +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY65E +")"
HwyLOS_BAAM_E_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY60D +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY60E +")"
HwyLOS_BAAM_E_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY55D +" and (BA_AM_PH_Q / [BA LANES]) <=  " + HWY55E +")"
UrbLOS_BAAM_E_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and (BA_AM_PH_V >  " + Urb50E +" and BA_AM_PH_V <=  " + Urb50D +")"
UrbLOS_BAAM_E_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and (BA_AM_PH_V > " + Urb40E + " and BA_AM_PH_V <=  " + Urb40D +")"
UrbLOS_BAAM_E_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and (BA_AM_PH_V > " + Urb30E + " and BA_AM_PH_V <=  " + Urb30D +" )"

LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "several", HwyLOS_BAAM_E_75,)
LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "more", HwyLOS_BAAM_E_70,)
LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "more", HwyLOS_BAAM_E_65,)
LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "more", HwyLOS_BAAM_E_60,)
LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "more", HwyLOS_BAAM_E_55,)
LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "more", UrbLOS_BAAM_E_50,)
LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "more", UrbLOS_BAAM_E_40,)
LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "more", UrbLOS_BAAM_E_30,)

if LOS_E_BAAM > 0 then do
	LOS_E_BAAM_Vector = Vector(LOS_E_BAAM,"Short",{{"Constant",5}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_E_BAAM","BA_AM_PH_LOS", LOS_E_BAAM_Vector,)
end

//==================================================================================================
//Highway AB AM PH LOS F
HwyLOS_ABAM_F_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY75E +")"
HwyLOS_ABAM_F_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY70E +")"
HwyLOS_ABAM_F_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY65E +")"
HwyLOS_ABAM_F_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY60E +")"
HwyLOS_ABAM_F_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and ((AB_AM_PH_Q / [AB LANES]) >  " + HWY55E +")"
UrbLOS_ABAM_F_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and (AB_AM_PH_V <=  " + Urb50E +")"
UrbLOS_ABAM_F_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and (AB_AM_PH_V <=  " + Urb40E+")"
UrbLOS_ABAM_F_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and (AB_AM_PH_V <= " + Urb30E + ")"

LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "several", HwyLOS_ABAM_F_75,)
LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "more", HwyLOS_ABAM_F_70,)
LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "more", HwyLOS_ABAM_F_65,)
LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "more", HwyLOS_ABAM_F_60,)
LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "more", HwyLOS_ABAM_F_55,)
LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "more", UrbLOS_ABAM_F_50,)
LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "more", UrbLOS_ABAM_F_40,)
LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "more", UrbLOS_ABAM_F_30,)

if LOS_F_ABAM > 0 then do
	LOS_F_ABAM_Vector = Vector(LOS_F_ABAM,"Short",{{"Constant",6}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_F_ABAM","AB_AM_PH_LOS", LOS_F_ABAM_Vector,)
end

//Highway BA AM PH LOS F
HwyLOS_BAAM_F_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY75E +")"
HwyLOS_BAAM_F_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY70E +")"
HwyLOS_BAAM_F_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY65E +")"
HwyLOS_BAAM_F_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY60E +")"
HwyLOS_BAAM_F_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and ((BA_AM_PH_Q / [BA LANES]) >  " + HWY55E +")"
UrbLOS_BAAM_F_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and (BA_AM_PH_V <=  " + Urb50E +")"
UrbLOS_BAAM_F_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and (BA_AM_PH_V <=  " + Urb40E+")"
UrbLOS_BAAM_F_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and (BA_AM_PH_V <= " + Urb30E + ")"

LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "several", HwyLOS_BAAM_F_75,)
LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "more", HwyLOS_BAAM_F_70,)
LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "more", HwyLOS_BAAM_F_65,)
LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "more", HwyLOS_BAAM_F_60,)
LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "more", HwyLOS_BAAM_F_55,)
LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "more", UrbLOS_BAAM_F_50,)
LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "more", UrbLOS_BAAM_F_40,)
LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "more", UrbLOS_BAAM_F_30,)

if LOS_F_BAAM > 0 then do
	LOS_F_BAAM_Vector = Vector(LOS_F_BAAM,"Short",{{"Constant",6}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_F_BAAM","BA_AM_PH_LOS", LOS_F_BAAM_Vector,)
end

//****************Whole AM Period LOS

//AB AM LOSA
HwyLOS_ABAM_A_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow AM] /  [AB LANES]/2) <= " + HWY75A +")"
HwyLOS_ABAM_A_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow AM] /  [AB LANES]/2) <= " + HWY70A +")"
HwyLOS_ABAM_A_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow AM] /  [AB LANES]/2) <= " + HWY65A +")"
HwyLOS_ABAM_A_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow AM] /  [AB LANES]/2) <= " + HWY60A +")"
HwyLOS_ABAM_A_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow AM] /  [AB LANES]/2) <= " + HWY55A+")"
UrbLOS_ABAM_A_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed AM] > " + Urb50A + ")"
UrbLOS_ABAM_A_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed AM] > " + Urb40A + ")"
UrbLOS_ABAM_A_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed AM] > " + Urb30A + ")"


LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "several", HwyLOS_ABAM_A_75,)
LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "more", HwyLOS_ABAM_A_70,)
LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "more", HwyLOS_ABAM_A_65,)
LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "more", HwyLOS_ABAM_A_60,)
LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "more", HwyLOS_ABAM_A_55,)
LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "more", UrbLOS_ABAM_A_50,)
LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "more", UrbLOS_ABAM_A_40,)
LOS_A_ABAM = SelectByQuery("HwyLOS_A_ABAM", "more", UrbLOS_ABAM_A_30,)

if LOS_A_ABAM > 0 then do
	LOS_A_ABAM_Vector = Vector(LOS_A_ABAM,"Short",{{"Constant",1}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|"+ "HwyLOS_A_ABAM","AB_AM_LOS", LOS_A_ABAM_Vector,)
end

//BA AM LOSA
HwyLOS_BAAM_A_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow AM] /  [BA LANES]/2) <= " + HWY75A +")"
HwyLOS_BAAM_A_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow AM] /  [BA LANES]/2) <= " + HWY70A +")"
HwyLOS_BAAM_A_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow AM] /  [BA LANES]/2) <= " + HWY65A +")"
HwyLOS_BAAM_A_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow AM] /  [BA LANES]/2) <= " + HWY60A +")"
HwyLOS_BAAM_A_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow AM] /  [BA LANES]/2) <= " + HWY55A +")"
UrbLOS_BAAM_A_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed AM] > " + Urb50A + ")"
UrbLOS_BAAM_A_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed AM] > " + Urb40A + ")"
UrbLOS_BAAM_A_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed AM] > " + Urb30A + ")"

LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "several", HwyLOS_BAAM_A_75,)
LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "more", HwyLOS_BAAM_A_70,)
LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "more", HwyLOS_BAAM_A_65,)
LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "more", HwyLOS_BAAM_A_60,)
LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "more", HwyLOS_BAAM_A_55,)
LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "more", UrbLOS_BAAM_A_50,)
LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "more", UrbLOS_BAAM_A_40,)
LOS_A_BAAM = SelectByQuery("HwyLOS_A_BAAM", "more", UrbLOS_BAAM_A_30,)

if LOS_A_BAAM > 0 then do
	LOS_A_BAAM_Vector = Vector(LOS_A_BAAM,"Short",{{"Constant",1}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_A_BAAM","BA_AM_LOS", LOS_A_BAAM_Vector,)
end

//==================================================================================================
//Highway AB AM LOSB
HwyLOS_ABAM_B_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY75A +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY75B +")"
HwyLOS_ABAM_B_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY70A +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY70B +")"
HwyLOS_ABAM_B_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY65A +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY65B +")"
HwyLOS_ABAM_B_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY60A +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY60B +")"
HwyLOS_ABAM_B_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY55A +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY55B +")"
UrbLOS_ABAM_B_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed AM] >  " + Urb50B+" and [AB Speed AM] <= " + Urb50A + ")"
UrbLOS_ABAM_B_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed AM] >  " + Urb40B +" and [AB Speed AM] <= " + Urb40A + ")"
UrbLOS_ABAM_B_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed AM] >  " + Urb30B+" and [AB Speed AM] <= " + Urb30A + ")"

LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "several", HwyLOS_ABAM_B_75,)
LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "more", HwyLOS_ABAM_B_70,)
LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "more", HwyLOS_ABAM_B_65,)
LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "more", HwyLOS_ABAM_B_60,)
LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "more", HwyLOS_ABAM_B_55,)
LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "more", UrbLOS_ABAM_B_50,)
LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "more", UrbLOS_ABAM_B_40,)
LOS_B_ABAM = SelectByQuery("HwyLOS_B_ABAM", "more", UrbLOS_ABAM_B_30,)

if LOS_B_ABAM > 0 then do
	LOS_B_ABAM_Vector = Vector(LOS_B_ABAM,"Short",{{"Constant",2}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_B_ABAM","AB_AM_LOS", LOS_B_ABAM_Vector,)
end

//Highway BA AM LOSB
HwyLOS_BAAM_B_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY75A +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY75B +")"
HwyLOS_BAAM_B_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY70A +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY70B +")"
HwyLOS_BAAM_B_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY65A +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY65B +")"
HwyLOS_BAAM_B_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY60A +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY60B +")"
HwyLOS_BAAM_B_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and ([BA Flow AM] /  [BA LANES]/2 >  " + HWY55A +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY55B +")"
UrbLOS_BAAM_B_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed AM] >  " + Urb50B+" and [BA Speed AM] <= " + Urb50A + ")"
UrbLOS_BAAM_B_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed AM] >  " + Urb40B +" and [BA Speed AM] <= " + Urb40A + ")"
UrbLOS_BAAM_B_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed AM] >  " + Urb30B+" and [BA Speed AM] <= " + Urb30A + ")"

LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "several", HwyLOS_BAAM_B_75,)
LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "more", HwyLOS_BAAM_B_70,)
LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "more", HwyLOS_BAAM_B_65,)
LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "more", HwyLOS_BAAM_B_60,)
LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "more", HwyLOS_BAAM_B_55,)
LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "more", UrbLOS_BAAM_B_50,)
LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "more", UrbLOS_BAAM_B_40,)
LOS_B_BAAM = SelectByQuery("HwyLOS_B_BAAM", "more", UrbLOS_BAAM_B_30,)


if LOS_B_BAAM > 0 then do
	LOS_B_BAAM_Vector = Vector(LOS_B_BAAM,"Short",{{"Constant",2}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_B_BAAM","BA_AM_LOS", LOS_B_BAAM_Vector,)
end

//==================================================================================================
//Highway AB AM LOS C
HwyLOS_ABAM_C_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY75B +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY75C +")"
HwyLOS_ABAM_C_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY70B +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY70C +")"
HwyLOS_ABAM_C_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY65B +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY65C +")"
HwyLOS_ABAM_C_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY60B +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY60C +")"
HwyLOS_ABAM_C_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY55B +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY55C +")"
UrbLOS_ABAM_C_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed AM] >  " + Urb50C+" and [AB Speed AM] <=  " + Urb50B+")"
UrbLOS_ABAM_C_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed AM] >  " + Urb40C +" and [AB Speed AM] <=  " + Urb40B +")"
UrbLOS_ABAM_C_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed AM] >  " + Urb30C+" and [AB Speed AM] <=  " + Urb30B+")"

LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "several", HwyLOS_ABAM_C_75,)
LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "more", HwyLOS_ABAM_C_70,)
LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "more", HwyLOS_ABAM_C_65,)
LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "more", HwyLOS_ABAM_C_60,)
LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "more", HwyLOS_ABAM_C_55,)
LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "more", UrbLOS_ABAM_C_50,)
LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "more", UrbLOS_ABAM_C_40,)
LOS_C_ABAM = SelectByQuery("HwyLOS_C_ABAM", "more", UrbLOS_ABAM_C_30,)

if LOS_C_ABAM > 0 then do
	LOS_C_ABAM_Vector = Vector(LOS_C_ABAM,"Short",{{"Constant",3}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_C_ABAM","AB_AM_LOS", LOS_C_ABAM_Vector,)
end

//Highway BA AM LOS C
HwyLOS_BAAM_C_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY75B +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY75C +")"
HwyLOS_BAAM_C_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY70B +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY70C +")"
HwyLOS_BAAM_C_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY65B +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY65C +")"
HwyLOS_BAAM_C_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY60B +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY60C +")"
HwyLOS_BAAM_C_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY55B +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY55C +")"
UrbLOS_BAAM_C_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed AM] >  " + Urb50C+" and [BA Speed AM] <=  " + Urb50B+")"
UrbLOS_BAAM_C_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed AM] >  " + Urb40C +" and [BA Speed AM] <=  " + Urb40B +")"
UrbLOS_BAAM_C_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed AM] >  " + Urb30C+" and [BA Speed AM] <=  " + Urb30B+")"


LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "several", HwyLOS_BAAM_C_75,)
LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "more", HwyLOS_BAAM_C_70,)
LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "more", HwyLOS_BAAM_C_65,)
LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "more", HwyLOS_BAAM_C_60,)
LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "more", HwyLOS_BAAM_C_55,)
LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "more", UrbLOS_BAAM_C_50,)
LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "more", UrbLOS_BAAM_C_40,)
LOS_C_BAAM = SelectByQuery("HwyLOS_C_BAAM", "more", UrbLOS_BAAM_C_30,)

if LOS_C_BAAM > 0 then do
	LOS_C_BAAM_Vector = Vector(LOS_C_BAAM,"Short",{{"Constant",3}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_C_BAAM","BA_AM_LOS", LOS_C_BAAM_Vector,)
end

//==================================================================================================
//Highway AB AM LOS D
HwyLOS_ABAM_D_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY75C +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY75D +")"
HwyLOS_ABAM_D_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY70C +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY70D +")"
HwyLOS_ABAM_D_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY65C +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY65D +")"
HwyLOS_ABAM_D_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY60C +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY60D +")"
HwyLOS_ABAM_D_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY55C +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY55D +")"
UrbLOS_ABAM_D_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed AM] >  " + Urb50D +" and [AB Speed AM] <=  " + Urb50C+")"
UrbLOS_ABAM_D_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed AM] >  " + Urb40D +" and [AB Speed AM] <=  " + Urb40C +")"
UrbLOS_ABAM_D_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed AM] >  " + Urb30D +" and [AB Speed AM] <=  " + Urb30C+")"

LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "several", HwyLOS_ABAM_D_75,)
LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "more", HwyLOS_ABAM_D_70,)
LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "more", HwyLOS_ABAM_D_65,)
LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "more", HwyLOS_ABAM_D_60,)
LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "more", HwyLOS_ABAM_D_55,)
LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "more", UrbLOS_ABAM_D_50,)
LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "more", UrbLOS_ABAM_D_40,)
LOS_D_ABAM = SelectByQuery("HwyLOS_D_ABAM", "more", UrbLOS_ABAM_D_30,)

if LOS_D_ABAM > 0 then do
	LOS_D_ABAM_Vector = Vector(LOS_D_ABAM,"Short",{{"Constant",4}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_D_ABAM","AB_AM_LOS", LOS_D_ABAM_Vector,)
end

//Highway BA AM LOS D
HwyLOS_BAAM_D_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY75C +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY75D +")"
HwyLOS_BAAM_D_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY70C +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY70D +")"
HwyLOS_BAAM_D_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY65C +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY65D +")"
HwyLOS_BAAM_D_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY60C +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY60D +")"
HwyLOS_BAAM_D_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY55C +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY55D +")"
UrbLOS_BAAM_D_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed AM] >  " + Urb50D +" and [BA Speed AM] <=  " + Urb50C+")"
UrbLOS_BAAM_D_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed AM] >  " + Urb40D +" and [BA Speed AM] <=  " + Urb40C +")"
UrbLOS_BAAM_D_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed AM] >  " + Urb30D +" and [BA Speed AM] <=  " + Urb30C+")"

LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "several", HwyLOS_BAAM_D_75,)
LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "more", HwyLOS_BAAM_D_70,)
LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "more", HwyLOS_BAAM_D_65,)
LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "more", HwyLOS_BAAM_D_60,)
LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "more", HwyLOS_BAAM_D_55,)
LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "more", UrbLOS_BAAM_D_50,)
LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "more", UrbLOS_BAAM_D_40,)
LOS_D_BAAM = SelectByQuery("HwyLOS_D_BAAM", "more", UrbLOS_BAAM_D_30,)

if LOS_D_BAAM > 0 then do
	LOS_D_BAAM_Vector = Vector(LOS_D_BAAM,"Short",{{"Constant",4}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_D_BAAM","BA_AM_LOS", LOS_D_BAAM_Vector,)
end

//==================================================================================================
//Highway AB AM LOS E
HwyLOS_ABAM_E_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY75D +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY75E +")"
HwyLOS_ABAM_E_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY70D +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY70E +")"
HwyLOS_ABAM_E_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY65D +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY65E +")"
HwyLOS_ABAM_E_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY60D +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY60E +")"
HwyLOS_ABAM_E_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY55D +" and ([AB Flow AM] /  [AB LANES]/2) <=  " + HWY55E +")"
UrbLOS_ABAM_E_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed AM] >  " + Urb50E +" and [AB Speed AM] <=  " + Urb50D +")"
UrbLOS_ABAM_E_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed AM] > " + Urb40E + " and [AB Speed AM] <=  " + Urb40D +")"
UrbLOS_ABAM_E_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed AM] > " + Urb30E + " and [AB Speed AM] <=  " + Urb30D +" )"

LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "several", HwyLOS_ABAM_E_75,)
LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "more", HwyLOS_ABAM_E_70,)
LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "more", HwyLOS_ABAM_E_65,)
LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "more", HwyLOS_ABAM_E_60,)
LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "more", HwyLOS_ABAM_E_55,)
LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "more", UrbLOS_ABAM_E_50,)
LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "more", UrbLOS_ABAM_E_40,)
LOS_E_ABAM = SelectByQuery("HwyLOS_E_ABAM", "more", UrbLOS_ABAM_E_30,)

if LOS_E_ABAM > 0 then do
	LOS_E_ABAM_Vector = Vector(LOS_E_ABAM,"Short",{{"Constant",5}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_E_ABAM","AB_AM_LOS", LOS_E_ABAM_Vector,)
end

//Highway BA AM LOS E
HwyLOS_BAAM_E_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY75D +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY75E +")"
HwyLOS_BAAM_E_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY70D +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY70E +")"
HwyLOS_BAAM_E_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY65D +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY65E +")"
HwyLOS_BAAM_E_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY60D +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY60E +")"
HwyLOS_BAAM_E_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY55D +" and ([BA Flow AM] /  [BA LANES]/2) <=  " + HWY55E +")"
UrbLOS_BAAM_E_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed AM] >  " + Urb50E +" and [BA Speed AM] <=  " + Urb50D +")"
UrbLOS_BAAM_E_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed AM] > " + Urb40E + " and [BA Speed AM] <=  " + Urb40D +")"
UrbLOS_BAAM_E_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed AM] > " + Urb30E + " and [BA Speed AM] <=  " + Urb30D +" )"

LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "several", HwyLOS_BAAM_E_75,)
LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "more", HwyLOS_BAAM_E_70,)
LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "more", HwyLOS_BAAM_E_65,)
LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "more", HwyLOS_BAAM_E_60,)
LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "more", HwyLOS_BAAM_E_55,)
LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "more", UrbLOS_BAAM_E_50,)
LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "more", UrbLOS_BAAM_E_40,)
LOS_E_BAAM = SelectByQuery("HwyLOS_E_BAAM", "more", UrbLOS_BAAM_E_30,)

if LOS_E_BAAM > 0 then do
	LOS_E_BAAM_Vector = Vector(LOS_E_BAAM,"Short",{{"Constant",5}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_E_BAAM","BA_AM_LOS", LOS_E_BAAM_Vector,)
end

//==================================================================================================
//Highway AB AM LOS F
HwyLOS_ABAM_F_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY75E +")"
HwyLOS_ABAM_F_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY70E +")"
HwyLOS_ABAM_F_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY65E +")"
HwyLOS_ABAM_F_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY60E +")"
HwyLOS_ABAM_F_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow AM] /  [AB LANES]/2) >  " + HWY55E +")"
UrbLOS_ABAM_F_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed AM] <=  " + Urb50E +")"
UrbLOS_ABAM_F_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed AM] <=  " + Urb40E+")"
UrbLOS_ABAM_F_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed AM] <= " + Urb30E + ")"

LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "several", HwyLOS_ABAM_F_75,)
LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "more", HwyLOS_ABAM_F_70,)
LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "more", HwyLOS_ABAM_F_65,)
LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "more", HwyLOS_ABAM_F_60,)
LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "more", HwyLOS_ABAM_F_55,)
LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "more", UrbLOS_ABAM_F_50,)
LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "more", UrbLOS_ABAM_F_40,)
LOS_F_ABAM = SelectByQuery("HwyLOS_F_ABAM", "more", UrbLOS_ABAM_F_30,)

if LOS_F_ABAM > 0 then do
	LOS_F_ABAM_Vector = Vector(LOS_F_ABAM,"Short",{{"Constant",6}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_F_ABAM","AB_AM_LOS", LOS_F_ABAM_Vector,)
end

//Highway BA AM LOS F
HwyLOS_BAAM_F_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY75E +")"
HwyLOS_BAAM_F_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY70E +")"
HwyLOS_BAAM_F_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY65E +")"
HwyLOS_BAAM_F_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY60E +")"
HwyLOS_BAAM_F_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow AM] /  [BA LANES]/2) >  " + HWY55E +")"
UrbLOS_BAAM_F_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed AM] <=  " + Urb50E +")"
UrbLOS_BAAM_F_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed AM] <=  " + Urb40E+")"
UrbLOS_BAAM_F_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed AM] <= " + Urb30E + ")"

LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "several", HwyLOS_BAAM_F_75,)
LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "more", HwyLOS_BAAM_F_70,)
LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "more", HwyLOS_BAAM_F_65,)
LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "more", HwyLOS_BAAM_F_60,)
LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "more", HwyLOS_BAAM_F_55,)
LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "more", UrbLOS_BAAM_F_50,)
LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "more", UrbLOS_BAAM_F_40,)
LOS_F_BAAM = SelectByQuery("HwyLOS_F_BAAM", "more", UrbLOS_BAAM_F_30,)

if LOS_F_BAAM > 0 then do
	LOS_F_BAAM_Vector = Vector(LOS_F_BAAM,"Short",{{"Constant",6}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_F_BAAM","BA_AM_LOS", LOS_F_BAAM_Vector,)
end

//==================================================================================================
//AB Mid LOSA

HwyLOS_ABMid_A_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow MD] /  [AB LANES] / 7.5) <= " + HWY75A +")"
HwyLOS_ABMid_A_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow MD] /  [AB LANES] / 7.5) <= " + HWY70A +")"
HwyLOS_ABMid_A_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow MD] /  [AB LANES] / 7.5) <= " + HWY65A +")"
HwyLOS_ABMid_A_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow MD] /  [AB LANES] / 7.5) <= " + HWY60A +")"
HwyLOS_ABMid_A_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow MD] /  [AB LANES] / 7.5) <= " + HWY55A +")"
UrbLOS_ABMid_A_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed MD] > " + Urb50A + ")"
UrbLOS_ABMid_A_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed MD] > " + Urb40A + ")"
UrbLOS_ABMid_A_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed MD] > " + Urb30A + ")"


LOS_A_ABMid = SelectByQuery("HwyLOS_A_ABMid", "several", HwyLOS_ABMid_A_75,)
LOS_A_ABMid = SelectByQuery("HwyLOS_A_ABMid", "more", HwyLOS_ABMid_A_70,)
LOS_A_ABMid = SelectByQuery("HwyLOS_A_ABMid", "more", HwyLOS_ABMid_A_65,)
LOS_A_ABMid = SelectByQuery("HwyLOS_A_ABMid", "more", HwyLOS_ABMid_A_60,)
LOS_A_ABMid = SelectByQuery("HwyLOS_A_ABMid", "more", HwyLOS_ABMid_A_55,)
LOS_A_ABMid = SelectByQuery("HwyLOS_A_ABMid", "more", UrbLOS_ABMid_A_50,)
LOS_A_ABMid = SelectByQuery("HwyLOS_A_ABMid", "more", UrbLOS_ABMid_A_40,)
LOS_A_ABMid = SelectByQuery("HwyLOS_A_ABMid", "more", UrbLOS_ABMid_A_30,)

if LOS_A_ABMid > 0 then do
	LOS_A_ABMid_Vector = Vector(LOS_A_ABMid,"Short",{{"Constant",1}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|"+ "HwyLOS_A_ABMid","AB_Mid_LOS", LOS_A_ABMid_Vector,)
end

//BA Mid LOSA
HwyLOS_BAMid_A_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY75A +")"
HwyLOS_BAMid_A_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY70A +")"
HwyLOS_BAMid_A_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY65A +")"
HwyLOS_BAMid_A_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY60A +")"
HwyLOS_BAMid_A_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY55A +")"
UrbLOS_BAMid_A_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed MD] > " + Urb50A + ")"
UrbLOS_BAMid_A_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed MD] > " + Urb40A + ")"
UrbLOS_BAMid_A_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed MD] > " + Urb30A + ")"

LOS_A_BAMid = SelectByQuery("HwyLOS_A_BAMid", "several", HwyLOS_BAMid_A_75,)
LOS_A_BAMid = SelectByQuery("HwyLOS_A_BAMid", "more", HwyLOS_BAMid_A_70,)
LOS_A_BAMid = SelectByQuery("HwyLOS_A_BAMid", "more", HwyLOS_BAMid_A_65,)
LOS_A_BAMid = SelectByQuery("HwyLOS_A_BAMid", "more", HwyLOS_BAMid_A_60,)
LOS_A_BAMid = SelectByQuery("HwyLOS_A_BAMid", "more", HwyLOS_BAMid_A_55,)
LOS_A_BAMid = SelectByQuery("HwyLOS_A_BAMid", "more", UrbLOS_BAMid_A_50,)
LOS_A_BAMid = SelectByQuery("HwyLOS_A_BAMid", "more", UrbLOS_BAMid_A_40,)
LOS_A_BAMid = SelectByQuery("HwyLOS_A_BAMid", "more", UrbLOS_BAMid_A_30,)

if LOS_A_BAMid > 0 then do
	LOS_A_BAMid_Vector = Vector(LOS_A_BAMid,"Short",{{"Constant",1}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_A_BAMid","BA_Mid_LOS", LOS_A_BAMid_Vector,)
end

//==================================================================================================
//Highway AB Mid LOSB
HwyLOS_ABMid_B_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY75A +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY75B +")"
HwyLOS_ABMid_B_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY70A +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY70B +")"
HwyLOS_ABMid_B_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY65A +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY65B +")"
HwyLOS_ABMid_B_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY60A +" and ([AB Flow MD] /  [AB LANES] / 7.5)<=  " + HWY60B +")"
HwyLOS_ABMid_B_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY55A +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY55B +")"
UrbLOS_ABMid_B_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed MD] >  " + Urb50B+" and [AB Speed MD] <= " + Urb50A + ")"
UrbLOS_ABMid_B_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed MD] >  " + Urb40B +" and [AB Speed MD] <= " + Urb40A + ")"
UrbLOS_ABMid_B_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed MD] >  " + Urb30B+" and [AB Speed MD] <= " + Urb30A + ")"

LOS_B_ABMid = SelectByQuery("HwyLOS_B_ABMid", "several", HwyLOS_ABMid_B_75,)
LOS_B_ABMid = SelectByQuery("HwyLOS_B_ABMid", "more", HwyLOS_ABMid_B_70,)
LOS_B_ABMid = SelectByQuery("HwyLOS_B_ABMid", "more", HwyLOS_ABMid_B_65,)
LOS_B_ABMid = SelectByQuery("HwyLOS_B_ABMid", "more", HwyLOS_ABMid_B_60,)
LOS_B_ABMid = SelectByQuery("HwyLOS_B_ABMid", "more", HwyLOS_ABMid_B_55,)
LOS_B_ABMid = SelectByQuery("HwyLOS_B_ABMid", "more", UrbLOS_ABMid_B_50,)
LOS_B_ABMid = SelectByQuery("HwyLOS_B_ABMid", "more", UrbLOS_ABMid_B_40,)
LOS_B_ABMid = SelectByQuery("HwyLOS_B_ABMid", "more", UrbLOS_ABMid_B_30,)

if LOS_B_ABMid > 0 then do
	LOS_B_ABMid_Vector = Vector(LOS_B_ABMid,"Short",{{"Constant",2}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_B_ABMid","AB_Mid_LOS", LOS_B_ABMid_Vector,)
end

//Highway BA Mid LOSB
HwyLOS_BAMid_B_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY75A +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY75B +")"
HwyLOS_BAMid_B_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY70A +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY70B +")"
HwyLOS_BAMid_B_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY65A +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY65B +")"
HwyLOS_BAMid_B_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY60A +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY60B +")"
HwyLOS_BAMid_B_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY55A +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY55B +")"
UrbLOS_BAMid_B_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed MD] >  " + Urb50B+" and [BA Speed MD] <= " + Urb50A + ")"
UrbLOS_BAMid_B_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed MD] >  " + Urb40B +" and [BA Speed MD] <= " + Urb40A + ")"
UrbLOS_BAMid_B_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed MD] >  " + Urb30B+" and [BA Speed MD] <= " + Urb30A + ")"

LOS_B_BAMid = SelectByQuery("HwyLOS_B_BAMid", "several", HwyLOS_BAMid_B_75,)
LOS_B_BAMid = SelectByQuery("HwyLOS_B_BAMid", "more", HwyLOS_BAMid_B_70,)
LOS_B_BAMid = SelectByQuery("HwyLOS_B_BAMid", "more", HwyLOS_BAMid_B_65,)
LOS_B_BAMid = SelectByQuery("HwyLOS_B_BAMid", "more", HwyLOS_BAMid_B_60,)
LOS_B_BAMid = SelectByQuery("HwyLOS_B_BAMid", "more", HwyLOS_BAMid_B_55,)
LOS_B_BAMid = SelectByQuery("HwyLOS_B_BAMid", "more", UrbLOS_BAMid_B_50,)
LOS_B_BAMid = SelectByQuery("HwyLOS_B_BAMid", "more", UrbLOS_BAMid_B_40,)
LOS_B_BAMid = SelectByQuery("HwyLOS_B_BAMid", "more", UrbLOS_BAMid_B_30,)


if LOS_B_BAMid > 0 then do
	LOS_B_BAMid_Vector = Vector(LOS_B_BAMid,"Short",{{"Constant",2}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_B_BAMid","BA_Mid_LOS", LOS_B_BAMid_Vector,)
end

//==================================================================================================
//Highway AB Mid LOS C
HwyLOS_ABMid_C_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY75B +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY75C +")"
HwyLOS_ABMid_C_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY70B +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY70C +")"
HwyLOS_ABMid_C_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY65B +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY65C +")"
HwyLOS_ABMid_C_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY60B +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY60C +")"
HwyLOS_ABMid_C_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY55B +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY55C +")"
UrbLOS_ABMid_C_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed MD] >  " + Urb50C+" and [AB Speed MD] <=  " + Urb50B+")"
UrbLOS_ABMid_C_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed MD] >  " + Urb40C +" and [AB Speed MD] <=  " + Urb40B +")"
UrbLOS_ABMid_C_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed MD] >  " + Urb30C+" and [AB Speed MD] <=  " + Urb30B+")"

LOS_C_ABMid = SelectByQuery("HwyLOS_C_ABMid", "several", HwyLOS_ABMid_C_75,)
LOS_C_ABMid = SelectByQuery("HwyLOS_C_ABMid", "more", HwyLOS_ABMid_C_70,)
LOS_C_ABMid = SelectByQuery("HwyLOS_C_ABMid", "more", HwyLOS_ABMid_C_65,)
LOS_C_ABMid = SelectByQuery("HwyLOS_C_ABMid", "more", HwyLOS_ABMid_C_60,)
LOS_C_ABMid = SelectByQuery("HwyLOS_C_ABMid", "more", HwyLOS_ABMid_C_55,)
LOS_C_ABMid = SelectByQuery("HwyLOS_C_ABMid", "more", UrbLOS_ABMid_C_50,)
LOS_C_ABMid = SelectByQuery("HwyLOS_C_ABMid", "more", UrbLOS_ABMid_C_40,)
LOS_C_ABMid = SelectByQuery("HwyLOS_C_ABMid", "more", UrbLOS_ABMid_C_30,)

if LOS_C_ABMid > 0 then do
	LOS_C_ABMid_Vector = Vector(LOS_C_ABMid,"Short",{{"Constant",3}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_C_ABMid","AB_Mid_LOS", LOS_C_ABMid_Vector,)
end

//Highway BA Mid LOS C
HwyLOS_BAMid_C_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY75B +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY75C +")"
HwyLOS_BAMid_C_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY70B +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY70C +")"
HwyLOS_BAMid_C_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY65B +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY65C +")"
HwyLOS_BAMid_C_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY60B +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY60C +")"
HwyLOS_BAMid_C_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY55B +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY55C +")"
UrbLOS_BAMid_C_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed MD] >  " + Urb50C+" and [BA Speed MD] <=  " + Urb50B+")"
UrbLOS_BAMid_C_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed MD] >  " + Urb40C +" and [BA Speed MD] <=  " + Urb40B +")"
UrbLOS_BAMid_C_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed MD] >  " + Urb30C+" and [BA Speed MD] <=  " + Urb30B+")"


LOS_C_BAMid = SelectByQuery("HwyLOS_C_BAMid", "several", HwyLOS_BAMid_C_75,)
LOS_C_BAMid = SelectByQuery("HwyLOS_C_BAMid", "more", HwyLOS_BAMid_C_70,)
LOS_C_BAMid = SelectByQuery("HwyLOS_C_BAMid", "more", HwyLOS_BAMid_C_65,)
LOS_C_BAMid = SelectByQuery("HwyLOS_C_BAMid", "more", HwyLOS_BAMid_C_60,)
LOS_C_BAMid = SelectByQuery("HwyLOS_C_BAMid", "more", HwyLOS_BAMid_C_55,)
LOS_C_BAMid = SelectByQuery("HwyLOS_C_BAMid", "more", UrbLOS_BAMid_C_50,)
LOS_C_BAMid = SelectByQuery("HwyLOS_C_BAMid", "more", UrbLOS_BAMid_C_40,)
LOS_C_BAMid = SelectByQuery("HwyLOS_C_BAMid", "more", UrbLOS_BAMid_C_30,)

if LOS_C_BAMid > 0 then do
	LOS_C_BAMid_Vector = Vector(LOS_C_BAMid,"Short",{{"Constant",3}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_C_BAMid","BA_Mid_LOS", LOS_C_BAMid_Vector,)
end

//==================================================================================================
//Highway AB Mid LOS D
HwyLOS_ABMid_D_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY75C +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY75D +")"
HwyLOS_ABMid_D_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY70C +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY70D +")"
HwyLOS_ABMid_D_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY65C +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY65D +")"
HwyLOS_ABMid_D_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY60C +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY60D +")"
HwyLOS_ABMid_D_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY55C +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY55D +")"
UrbLOS_ABMid_D_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed MD] >  " + Urb50D +" and [AB Speed MD] <=  " + Urb50C+")"
UrbLOS_ABMid_D_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed MD] >  " + Urb40D +" and [AB Speed MD] <=  " + Urb40C +")"
UrbLOS_ABMid_D_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed MD] >  " + Urb30D +" and [AB Speed MD] <=  " + Urb30C+")"

LOS_D_ABMid = SelectByQuery("HwyLOS_D_ABMid", "several", HwyLOS_ABMid_D_75,)
LOS_D_ABMid = SelectByQuery("HwyLOS_D_ABMid", "more", HwyLOS_ABMid_D_70,)
LOS_D_ABMid = SelectByQuery("HwyLOS_D_ABMid", "more", HwyLOS_ABMid_D_65,)
LOS_D_ABMid = SelectByQuery("HwyLOS_D_ABMid", "more", HwyLOS_ABMid_D_60,)
LOS_D_ABMid = SelectByQuery("HwyLOS_D_ABMid", "more", HwyLOS_ABMid_D_55,)
LOS_D_ABMid = SelectByQuery("HwyLOS_D_ABMid", "more", UrbLOS_ABMid_D_50,)
LOS_D_ABMid = SelectByQuery("HwyLOS_D_ABMid", "more", UrbLOS_ABMid_D_40,)
LOS_D_ABMid = SelectByQuery("HwyLOS_D_ABMid", "more", UrbLOS_ABMid_D_30,)

if LOS_D_ABMid > 0 then do
	LOS_D_ABMid_Vector = Vector(LOS_D_ABMid,"Short",{{"Constant",4}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_D_ABMid","AB_Mid_LOS", LOS_D_ABMid_Vector,)
end

//Highway BA Mid LOS D
HwyLOS_BAMid_D_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY75C +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY75D +")"
HwyLOS_BAMid_D_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY70C +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY70D +")"
HwyLOS_BAMid_D_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY65C +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY65D +")"
HwyLOS_BAMid_D_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY60C +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY60D +")"
HwyLOS_BAMid_D_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY55C +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY55D +")"
UrbLOS_BAMid_D_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed MD] >  " + Urb50D +" and [BA Speed MD] <=  " + Urb50C+")"
UrbLOS_BAMid_D_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed MD] >  " + Urb40D +" and [BA Speed MD] <=  " + Urb40C +")"
UrbLOS_BAMid_D_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed MD] >  " + Urb30D +" and [BA Speed MD] <=  " + Urb30C+")"

LOS_D_BAMid = SelectByQuery("HwyLOS_D_BAMid", "several", HwyLOS_BAMid_D_75,)
LOS_D_BAMid = SelectByQuery("HwyLOS_D_BAMid", "more", HwyLOS_BAMid_D_70,)
LOS_D_BAMid = SelectByQuery("HwyLOS_D_BAMid", "more", HwyLOS_BAMid_D_65,)
LOS_D_BAMid = SelectByQuery("HwyLOS_D_BAMid", "more", HwyLOS_BAMid_D_60,)
LOS_D_BAMid = SelectByQuery("HwyLOS_D_BAMid", "more", HwyLOS_BAMid_D_55,)
LOS_D_BAMid = SelectByQuery("HwyLOS_D_BAMid", "more", UrbLOS_BAMid_D_50,)
LOS_D_BAMid = SelectByQuery("HwyLOS_D_BAMid", "more", UrbLOS_BAMid_D_40,)
LOS_D_BAMid = SelectByQuery("HwyLOS_D_BAMid", "more", UrbLOS_BAMid_D_30,)

if LOS_D_BAMid > 0 then do
	LOS_D_BAMid_Vector = Vector(LOS_D_BAMid,"Short",{{"Constant",4}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_D_BAMid","BA_Mid_LOS", LOS_D_BAMid_Vector,)
end

//==================================================================================================
//Highway AB Mid LOS E
HwyLOS_ABMid_E_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY75D +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY75E +")"
HwyLOS_ABMid_E_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY70D +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY70E +")"
HwyLOS_ABMid_E_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY65D +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY65E +")"
HwyLOS_ABMid_E_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY60D +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY60E +")"
HwyLOS_ABMid_E_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY55D +" and ([AB Flow MD] /  [AB LANES] / 7.5) <=  " + HWY55E +")"
UrbLOS_ABMid_E_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed MD] >  " + Urb50E +" and [AB Speed MD] <=  " + Urb50D +")"
UrbLOS_ABMid_E_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed MD] >  " + Urb40E+" and [AB Speed MD] <=  " + Urb40D +")"
UrbLOS_ABMid_E_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed MD] > " + Urb30E + " and [AB Speed MD] <=  " + Urb30D + ")"

LOS_E_ABMid = SelectByQuery("HwyLOS_E_ABMid", "several", HwyLOS_ABMid_E_75,)
LOS_E_ABMid = SelectByQuery("HwyLOS_E_ABMid", "more", HwyLOS_ABMid_E_70,)
LOS_E_ABMid = SelectByQuery("HwyLOS_E_ABMid", "more", HwyLOS_ABMid_E_65,)
LOS_E_ABMid = SelectByQuery("HwyLOS_E_ABMid", "more", HwyLOS_ABMid_E_60,)
LOS_E_ABMid = SelectByQuery("HwyLOS_E_ABMid", "more", HwyLOS_ABMid_E_55,)
LOS_E_ABMid = SelectByQuery("HwyLOS_E_ABMid", "more", UrbLOS_ABMid_E_50,)
LOS_E_ABMid = SelectByQuery("HwyLOS_E_ABMid", "more", UrbLOS_ABMid_E_40,)
LOS_E_ABMid = SelectByQuery("HwyLOS_E_ABMid", "more", UrbLOS_ABMid_E_30,)

if LOS_E_ABMid > 0 then do
	LOS_E_ABMid_Vector = Vector(LOS_E_ABMid,"Short",{{"Constant",5}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_E_ABMid","AB_Mid_LOS", LOS_E_ABMid_Vector,)
end

//Highway BA Mid LOS E
HwyLOS_BAMid_E_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY75D +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY75E +")"
HwyLOS_BAMid_E_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY70D +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY70E +")"
HwyLOS_BAMid_E_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY65D +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY65E +")"
HwyLOS_BAMid_E_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY60D +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY60E +")"
HwyLOS_BAMid_E_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY55D +" and ([BA Flow MD] /  [BA LANES] / 7.5) <=  " + HWY55E +")"
UrbLOS_BAMid_E_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed MD] >  " + Urb50E +" and [BA Speed MD] <=  " + Urb50D +")"
UrbLOS_BAMid_E_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed MD] >  " + Urb40E+" and [BA Speed MD] <=  " + Urb40D +")"
UrbLOS_BAMid_E_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed MD] > " + Urb30E + " and [BA Speed MD] <=  " + Urb30D + ")"

LOS_E_BAMid = SelectByQuery("HwyLOS_E_BAMid", "several", HwyLOS_BAMid_E_75,)
LOS_E_BAMid = SelectByQuery("HwyLOS_E_BAMid", "more", HwyLOS_BAMid_E_70,)
LOS_E_BAMid = SelectByQuery("HwyLOS_E_BAMid", "more", HwyLOS_BAMid_E_65,)
LOS_E_BAMid = SelectByQuery("HwyLOS_E_BAMid", "more", HwyLOS_BAMid_E_60,)
LOS_E_BAMid = SelectByQuery("HwyLOS_E_BAMid", "more", HwyLOS_BAMid_E_55,)
LOS_E_BAMid = SelectByQuery("HwyLOS_E_BAMid", "more", UrbLOS_BAMid_E_50,)
LOS_E_BAMid = SelectByQuery("HwyLOS_E_BAMid", "more", UrbLOS_BAMid_E_40,)
LOS_E_BAMid = SelectByQuery("HwyLOS_E_BAMid", "more", UrbLOS_BAMid_E_30,)

if LOS_E_BAMid > 0 then do
	LOS_E_BAMid_Vector = Vector(LOS_E_BAMid,"Short",{{"Constant",5}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_E_BAMid","BA_Mid_LOS", LOS_E_BAMid_Vector,)
end

//==================================================================================================
//Highway AB Mid LOS F
HwyLOS_ABMid_F_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY75E +")"
HwyLOS_ABMid_F_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY70E +")"
HwyLOS_ABMid_F_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY65E +")"
HwyLOS_ABMid_F_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY60E +")"
HwyLOS_ABMid_F_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow MD] /  [AB LANES] / 7.5) >  " + HWY55E +")"
UrbLOS_ABMid_F_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed MD] <=  " + Urb50E +")"
UrbLOS_ABMid_F_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed MD] <=  " + Urb40E+")"
UrbLOS_ABMid_F_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed MD] <= " + Urb30E + ")"

LOS_F_ABMid = SelectByQuery("HwyLOS_F_ABMid", "several", HwyLOS_ABMid_F_75,)
LOS_F_ABMid = SelectByQuery("HwyLOS_F_ABMid", "more", HwyLOS_ABMid_F_70,)
LOS_F_ABMid = SelectByQuery("HwyLOS_F_ABMid", "more", HwyLOS_ABMid_F_65,)
LOS_F_ABMid = SelectByQuery("HwyLOS_F_ABMid", "more", HwyLOS_ABMid_F_60,)
LOS_F_ABMid = SelectByQuery("HwyLOS_F_ABMid", "more", HwyLOS_ABMid_F_55,)
LOS_F_ABMid = SelectByQuery("HwyLOS_F_ABMid", "more", UrbLOS_ABMid_F_50,)
LOS_F_ABMid = SelectByQuery("HwyLOS_F_ABMid", "more", UrbLOS_ABMid_F_40,)
LOS_F_ABMid = SelectByQuery("HwyLOS_F_ABMid", "more", UrbLOS_ABMid_F_30,)

if LOS_F_ABMid > 0 then do
	LOS_F_ABMid_Vector = Vector(LOS_F_ABMid,"Short",{{"Constant",6}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_F_ABMid","AB_Mid_LOS", LOS_F_ABMid_Vector,)
end

//Highway BA Mid LOS F
HwyLOS_BAMid_F_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY75E +")"
HwyLOS_BAMid_F_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY70E +")"
HwyLOS_BAMid_F_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY65E +")"
HwyLOS_BAMid_F_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY60E +")"
HwyLOS_BAMid_F_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow MD] /  [BA LANES] / 7.5) >  " + HWY55E +")"
UrbLOS_BAMid_F_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed MD] <=  " + Urb50E +")"
UrbLOS_BAMid_F_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed MD] <=  " + Urb40E+")"
UrbLOS_BAMid_F_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed MD] <= " + Urb30E + ")"

LOS_F_BAMid = SelectByQuery("HwyLOS_F_BAMid", "several", HwyLOS_BAMid_F_75,)
LOS_F_BAMid = SelectByQuery("HwyLOS_F_BAMid", "more", HwyLOS_BAMid_F_70,)
LOS_F_BAMid = SelectByQuery("HwyLOS_F_BAMid", "more", HwyLOS_BAMid_F_65,)
LOS_F_BAMid = SelectByQuery("HwyLOS_F_BAMid", "more", HwyLOS_BAMid_F_60,)
LOS_F_BAMid = SelectByQuery("HwyLOS_F_BAMid", "more", HwyLOS_BAMid_F_55,)
LOS_F_BAMid = SelectByQuery("HwyLOS_F_BAMid", "more", UrbLOS_BAMid_F_50,)
LOS_F_BAMid = SelectByQuery("HwyLOS_F_BAMid", "more", UrbLOS_BAMid_F_40,)
LOS_F_BAMid = SelectByQuery("HwyLOS_F_BAMid", "more", UrbLOS_BAMid_F_30,)

if LOS_F_BAMid > 0 then do
	LOS_F_BAMid_Vector = Vector(LOS_F_BAMid,"Short",{{"Constant",6}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_F_BAMid","BA_Mid_LOS", LOS_F_BAMid_Vector,)
end

//==================================================================================================
//AB PM LOSA

HwyLOS_ABPM_A_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and ((AB_PM_PH_Q / [AB LANES]) <=  " + HWY75A +")"
HwyLOS_ABPM_A_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and ((AB_PM_PH_Q / [AB LANES]) <=  " + HWY70A +")"
HwyLOS_ABPM_A_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and ((AB_PM_PH_Q / [AB LANES]) <=  " + HWY65A +")"
HwyLOS_ABPM_A_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and ((AB_PM_PH_Q / [AB LANES]) <=  " + HWY60A +")"
HwyLOS_ABPM_A_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and ((AB_PM_PH_Q / [AB LANES]) <=  " + HWY55A +")"
UrbLOS_ABPM_A_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and (AB_PM_PH_V > " + Urb50A + ")"
UrbLOS_ABPM_A_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and (AB_PM_PH_V > " + Urb40A + ")"
UrbLOS_ABPM_A_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and (AB_PM_PH_V > " + Urb30A + ")"


LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "several", HwyLOS_ABPM_A_75,)
LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "more", HwyLOS_ABPM_A_70,)
LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "more", HwyLOS_ABPM_A_65,)
LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "more", HwyLOS_ABPM_A_60,)
LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "more", HwyLOS_ABPM_A_55,)
LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "more", UrbLOS_ABPM_A_50,)
LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "more", UrbLOS_ABPM_A_40,)
LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "more", UrbLOS_ABPM_A_30,)

if LOS_A_ABPM > 0 then do
	LOS_A_ABPM_Vector = Vector(LOS_A_ABPM,"Short",{{"Constant",1}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|"+ "HwyLOS_A_ABPM","AB_PM_PH_LOS", LOS_A_ABPM_Vector,)
end

//BA PM LOSA
HwyLOS_BAPM_A_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and ((BA_PM_PH_Q / [BA LANES]) <=  " + HWY75A +")"
HwyLOS_BAPM_A_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and ((BA_PM_PH_Q / [BA LANES]) <=  " + HWY70A +")"
HwyLOS_BAPM_A_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and ((BA_PM_PH_Q / [BA LANES]) <=  " + HWY65A +")"
HwyLOS_BAPM_A_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and ((BA_PM_PH_Q / [BA LANES]) <=  " + HWY60A +")"
HwyLOS_BAPM_A_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and ((BA_PM_PH_Q / [BA LANES]) <=  " + HWY55A +")"
UrbLOS_BAPM_A_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and (BA_PM_PH_V > " + Urb50A + ")"
UrbLOS_BAPM_A_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and (BA_PM_PH_V > " + Urb40A + ")"
UrbLOS_BAPM_A_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and (BA_PM_PH_V > " + Urb30A + ")"

LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "several", HwyLOS_BAPM_A_75,)
LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "more", HwyLOS_BAPM_A_70,)
LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "more", HwyLOS_BAPM_A_65,)
LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "more", HwyLOS_BAPM_A_60,)
LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "more", HwyLOS_BAPM_A_55,)
LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "more", UrbLOS_BAPM_A_50,)
LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "more", UrbLOS_BAPM_A_40,)
LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "more", UrbLOS_BAPM_A_30,)

if LOS_A_BAPM > 0 then do
	LOS_A_BAPM_Vector = Vector(LOS_A_BAPM,"Short",{{"Constant",1}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_A_BAPM","BA_PM_PH_LOS", LOS_A_BAPM_Vector,)
end

//==================================================================================================
//Highway AB PM LOSB
HwyLOS_ABPM_B_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY75A +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY75B +")"
HwyLOS_ABPM_B_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY70A +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY70B +")"
HwyLOS_ABPM_B_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY65A +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY65B +")"
HwyLOS_ABPM_B_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY60A +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY60B +")"
HwyLOS_ABPM_B_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY55A +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY55B +")"
UrbLOS_ABPM_B_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and (AB_PM_PH_V >  " + Urb50B+" and AB_PM_PH_V <= " + Urb50A + ")"
UrbLOS_ABPM_B_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and (AB_PM_PH_V >  " + Urb40B +" and AB_PM_PH_V <= " + Urb40A + ")"
UrbLOS_ABPM_B_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and (AB_PM_PH_V >  " + Urb30B+" and AB_PM_PH_V <= " + Urb30A + ")"

LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "several", HwyLOS_ABPM_B_75,)
LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "more", HwyLOS_ABPM_B_70,)
LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "more", HwyLOS_ABPM_B_65,)
LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "more", HwyLOS_ABPM_B_60,)
LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "more", HwyLOS_ABPM_B_55,)
LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "more", UrbLOS_ABPM_B_50,)
LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "more", UrbLOS_ABPM_B_40,)
LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "more", UrbLOS_ABPM_B_30,)

if LOS_B_ABPM > 0 then do
	LOS_B_ABPM_Vector = Vector(LOS_B_ABPM,"Short",{{"Constant",2}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_B_ABPM","AB_PM_PH_LOS", LOS_B_ABPM_Vector,)
end

//Highway BA PM LOSB
HwyLOS_BAPM_B_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY75A +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY75B +")"
HwyLOS_BAPM_B_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY70A +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY70B +")"
HwyLOS_BAPM_B_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY65A +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY65B +")"
HwyLOS_BAPM_B_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY60A +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY60B +")"
HwyLOS_BAPM_B_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY55A +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY55B +")"
UrbLOS_BAPM_B_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and (BA_PM_PH_V >  " + Urb50B+" and BA_PM_PH_V <= " + Urb50A + ")"
UrbLOS_BAPM_B_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and (BA_PM_PH_V >  " + Urb40B +" and BA_PM_PH_V <= " + Urb40A + ")"
UrbLOS_BAPM_B_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and (BA_PM_PH_V >  " + Urb30B+" and BA_PM_PH_V <= " + Urb30A + ")"

LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "several", HwyLOS_BAPM_B_75,)
LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "more", HwyLOS_BAPM_B_70,)
LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "more", HwyLOS_BAPM_B_65,)
LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "more", HwyLOS_BAPM_B_60,)
LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "more", HwyLOS_BAPM_B_55,)
LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "more", UrbLOS_BAPM_B_50,)
LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "more", UrbLOS_BAPM_B_40,)
LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "more", UrbLOS_BAPM_B_30,)


if LOS_B_BAPM > 0 then do
	LOS_B_BAPM_Vector = Vector(LOS_B_BAPM,"Short",{{"Constant",2}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_B_BAPM","BA_PM_PH_LOS", LOS_B_BAPM_Vector,)
end

//==================================================================================================
//Highway AB PM LOS C
HwyLOS_ABPM_C_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY75B +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY75C +")"
HwyLOS_ABPM_C_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY70B +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY70C +")"
HwyLOS_ABPM_C_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY65B +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY65C +")"
HwyLOS_ABPM_C_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY60B +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY60C +")"
HwyLOS_ABPM_C_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY55B +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY55C +")"
UrbLOS_ABPM_C_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and (AB_PM_PH_V >  " + Urb50C+" and AB_PM_PH_V <=  " + Urb50B+")"
UrbLOS_ABPM_C_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and (AB_PM_PH_V >  " + Urb40C +" and AB_PM_PH_V <=  " + Urb40B +")"
UrbLOS_ABPM_C_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and (AB_PM_PH_V >  " + Urb30C+" and AB_PM_PH_V <=  " + Urb30B+")"

LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "several", HwyLOS_ABPM_C_75,)
LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "more", HwyLOS_ABPM_C_70,)
LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "more", HwyLOS_ABPM_C_65,)
LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "more", HwyLOS_ABPM_C_60,)
LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "more", HwyLOS_ABPM_C_55,)
LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "more", UrbLOS_ABPM_C_50,)
LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "more", UrbLOS_ABPM_C_40,)
LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "more", UrbLOS_ABPM_C_30,)

if LOS_C_ABPM > 0 then do
	LOS_C_ABPM_Vector = Vector(LOS_C_ABPM,"Short",{{"Constant",3}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_C_ABPM","AB_PM_PH_LOS", LOS_C_ABPM_Vector,)
end

//Highway BA PM LOS C
HwyLOS_BAPM_C_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY75B +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY75C +")"
HwyLOS_BAPM_C_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY70B +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY70C +")"
HwyLOS_BAPM_C_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY65B +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY65C +")"
HwyLOS_BAPM_C_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY60B +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY60C +")"
HwyLOS_BAPM_C_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY55B +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY55C +")"
UrbLOS_BAPM_C_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and (BA_PM_PH_V >  " + Urb50C+" and BA_PM_PH_V <=  " + Urb50B+")"
UrbLOS_BAPM_C_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and (BA_PM_PH_V >  " + Urb40C +" and BA_PM_PH_V <=  " + Urb40B +")"
UrbLOS_BAPM_C_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and (BA_PM_PH_V >  " + Urb30C+" and BA_PM_PH_V <=  " + Urb30B+")"


LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "several", HwyLOS_BAPM_C_75,)
LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "more", HwyLOS_BAPM_C_70,)
LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "more", HwyLOS_BAPM_C_65,)
LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "more", HwyLOS_BAPM_C_60,)
LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "more", HwyLOS_BAPM_C_55,)
LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "more", UrbLOS_BAPM_C_50,)
LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "more", UrbLOS_BAPM_C_40,)
LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "more", UrbLOS_BAPM_C_30,)

if LOS_C_BAPM > 0 then do
	LOS_C_BAPM_Vector = Vector(LOS_C_BAPM,"Short",{{"Constant",3}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_C_BAPM","BA_PM_PH_LOS", LOS_C_BAPM_Vector,)
end

//==================================================================================================
//Highway AB PM LOS D
HwyLOS_ABPM_D_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY75C +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY75D +")"
HwyLOS_ABPM_D_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY70C +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY70D +")"
HwyLOS_ABPM_D_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY65C +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY65D +")"
HwyLOS_ABPM_D_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY60C +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY60D +")"
HwyLOS_ABPM_D_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY55C +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY55D +")"
UrbLOS_ABPM_D_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and (AB_PM_PH_V >  " + Urb50D +" and AB_PM_PH_V <=  " + Urb50C+")"
UrbLOS_ABPM_D_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and (AB_PM_PH_V >  " + Urb40D +" and AB_PM_PH_V <=  " + Urb40C +")"
UrbLOS_ABPM_D_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and (AB_PM_PH_V >  " + Urb30D +" and AB_PM_PH_V <=  " + Urb30C+")"

LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "several", HwyLOS_ABPM_D_75,)
LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "more", HwyLOS_ABPM_D_70,)
LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "more", HwyLOS_ABPM_D_65,)
LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "more", HwyLOS_ABPM_D_60,)
LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "more", HwyLOS_ABPM_D_55,)
LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "more", UrbLOS_ABPM_D_50,)
LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "more", UrbLOS_ABPM_D_40,)
LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "more", UrbLOS_ABPM_D_30,)

if LOS_D_ABPM > 0 then do
	LOS_D_ABPM_Vector = Vector(LOS_D_ABPM,"Short",{{"Constant",4}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_D_ABPM","AB_PM_PH_LOS", LOS_D_ABPM_Vector,)
end

//Highway BA PM LOS D
HwyLOS_BAPM_D_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY75C +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY75D +")"
HwyLOS_BAPM_D_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY70C +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY70D +")"
HwyLOS_BAPM_D_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY65C +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY65D +")"
HwyLOS_BAPM_D_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY60C +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY60D +")"
HwyLOS_BAPM_D_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY55C +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY55D +")"
UrbLOS_BAPM_D_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and (BA_PM_PH_V >  " + Urb50D +" and BA_PM_PH_V <=  " + Urb50C+")"
UrbLOS_BAPM_D_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and (BA_PM_PH_V >  " + Urb40D +" and BA_PM_PH_V <=  " + Urb40C +")"
UrbLOS_BAPM_D_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and (BA_PM_PH_V >  " + Urb30D +" and BA_PM_PH_V <=  " + Urb30C+")"

LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "several", HwyLOS_BAPM_D_75,)
LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "more", HwyLOS_BAPM_D_70,)
LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "more", HwyLOS_BAPM_D_65,)
LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "more", HwyLOS_BAPM_D_60,)
LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "more", HwyLOS_BAPM_D_55,)
LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "more", UrbLOS_BAPM_D_50,)
LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "more", UrbLOS_BAPM_D_40,)
LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "more", UrbLOS_BAPM_D_30,)

if LOS_D_BAPM > 0 then do
	LOS_D_BAPM_Vector = Vector(LOS_D_BAPM,"Short",{{"Constant",4}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_D_BAPM","BA_PM_PH_LOS", LOS_D_BAPM_Vector,)
end

//==================================================================================================
//Highway AB PM LOS E
HwyLOS_ABPM_E_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY75D +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY75E +")"
HwyLOS_ABPM_E_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY70D +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY70E +")"
HwyLOS_ABPM_E_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY65D +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY65E +")"
HwyLOS_ABPM_E_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY60D +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY60E +")"
HwyLOS_ABPM_E_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY55D +" and (AB_PM_PH_Q / [AB LANES]) <=  " + HWY55E +")"
UrbLOS_ABPM_E_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and (AB_PM_PH_V >  " + Urb50E +" and AB_PM_PH_V <=  " + Urb50D +")"
UrbLOS_ABPM_E_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and (AB_PM_PH_V >  " + Urb40E+" and AB_PM_PH_V <=  " + Urb40D +")"
UrbLOS_ABPM_E_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and (AB_PM_PH_V > " + Urb30E + " and AB_PM_PH_V <=  " + Urb30D + ")"

LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "several", HwyLOS_ABPM_E_75,)
LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "more", HwyLOS_ABPM_E_70,)
LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "more", HwyLOS_ABPM_E_65,)
LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "more", HwyLOS_ABPM_E_60,)
LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "more", HwyLOS_ABPM_E_55,)
LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "more", UrbLOS_ABPM_E_50,)
LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "more", UrbLOS_ABPM_E_40,)
LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "more", UrbLOS_ABPM_E_30,)

if LOS_E_ABPM > 0 then do
	LOS_E_ABPM_Vector = Vector(LOS_E_ABPM,"Short",{{"Constant",5}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_E_ABPM","AB_PM_PH_LOS", LOS_E_ABPM_Vector,)
end

//Highway BA PM LOS E
HwyLOS_BAPM_E_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY75D +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY75E +")"
HwyLOS_BAPM_E_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY70D +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY70E +")"
HwyLOS_BAPM_E_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY65D +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY65E +")"
HwyLOS_BAPM_E_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY60D +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY60E +")"
HwyLOS_BAPM_E_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY55D +" and (BA_PM_PH_Q / [BA LANES]) <=  " + HWY55E +")"
UrbLOS_BAPM_E_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and (BA_PM_PH_V >  " + Urb50E +" and BA_PM_PH_V <=  " + Urb50D +")"
UrbLOS_BAPM_E_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and (BA_PM_PH_V >  " + Urb40E+" and BA_PM_PH_V <=  " + Urb40D +")"
UrbLOS_BAPM_E_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and (BA_PM_PH_V > " + Urb30E + " and BA_PM_PH_V <=  " + Urb30D + ")"

LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "several", HwyLOS_BAPM_E_75,)
LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "more", HwyLOS_BAPM_E_70,)
LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "more", HwyLOS_BAPM_E_65,)
LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "more", HwyLOS_BAPM_E_60,)
LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "more", HwyLOS_BAPM_E_55,)
LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "more", UrbLOS_BAPM_E_50,)
LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "more", UrbLOS_BAPM_E_40,)
LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "more", UrbLOS_BAPM_E_30,)

if LOS_E_BAPM > 0 then do
	LOS_E_BAPM_Vector = Vector(LOS_E_BAPM,"Short",{{"Constant",5}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_E_BAPM","BA_PM_PH_LOS", LOS_E_BAPM_Vector,)
end

//==================================================================================================
//Highway AB PM LOS F
HwyLOS_ABPM_F_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY75E +")"
HwyLOS_ABPM_F_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY70E +")"
HwyLOS_ABPM_F_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY65E +")"
HwyLOS_ABPM_F_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY60E +")"
HwyLOS_ABPM_F_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and ((AB_PM_PH_Q / [AB LANES]) >  " + HWY55E +")"
UrbLOS_ABPM_F_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and (AB_PM_PH_V <=  " + Urb50E +")"
UrbLOS_ABPM_F_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and (AB_PM_PH_V <=  " + Urb40E+")"
UrbLOS_ABPM_F_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and (AB_PM_PH_V <= " + Urb30E + ")"

LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "several", HwyLOS_ABPM_F_75,)
LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "more", HwyLOS_ABPM_F_70,)
LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "more", HwyLOS_ABPM_F_65,)
LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "more", HwyLOS_ABPM_F_60,)
LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "more", HwyLOS_ABPM_F_55,)
LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "more", UrbLOS_ABPM_F_50,)
LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "more", UrbLOS_ABPM_F_40,)
LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "more", UrbLOS_ABPM_F_30,)

if LOS_F_ABPM > 0 then do
	LOS_F_ABPM_Vector = Vector(LOS_F_ABPM,"Short",{{"Constant",6}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_F_ABPM","AB_PM_PH_LOS", LOS_F_ABPM_Vector,)
end

//Highway BA PM LOS F
HwyLOS_BAPM_F_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY75E +")"
HwyLOS_BAPM_F_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY70E +")"
HwyLOS_BAPM_F_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY65E +")"
HwyLOS_BAPM_F_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY60E +")"
HwyLOS_BAPM_F_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and ((BA_PM_PH_Q / [BA LANES]) >  " + HWY55E +")"
UrbLOS_BAPM_F_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and (BA_PM_PH_V <=  " + Urb50E +")"
UrbLOS_BAPM_F_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and (BA_PM_PH_V <=  " + Urb40E+")"
UrbLOS_BAPM_F_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and (BA_PM_PH_V <= " + Urb30E + ")"

LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "several", HwyLOS_BAPM_F_75,)
LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "more", HwyLOS_BAPM_F_70,)
LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "more", HwyLOS_BAPM_F_65,)
LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "more", HwyLOS_BAPM_F_60,)
LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "more", HwyLOS_BAPM_F_55,)
LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "more", UrbLOS_BAPM_F_50,)
LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "more", UrbLOS_BAPM_F_40,)
LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "more", UrbLOS_BAPM_F_30,)

if LOS_F_BAPM > 0 then do
	LOS_F_BAPM_Vector = Vector(LOS_F_BAPM,"Short",{{"Constant",6}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_F_BAPM","BA_PM_PH_LOS", LOS_F_BAPM_Vector,)
end

//*************Whole PM Period LOS
//AB PM LOSA

HwyLOS_ABPM_A_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow PM] /  [AB LANES]/2) <= " + HWY75A +")"
HwyLOS_ABPM_A_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow PM] /  [AB LANES]/2) <= " + HWY70A +")"
HwyLOS_ABPM_A_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow PM] /  [AB LANES]/2) <= " + HWY65A +")"
HwyLOS_ABPM_A_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow PM] /  [AB LANES]/2) <= " + HWY60A +")"
HwyLOS_ABPM_A_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow PM] /  [AB LANES]/2) <= " + HWY55A+")"
UrbLOS_ABPM_A_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed PM] > " + Urb50A + ")"
UrbLOS_ABPM_A_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed PM] > " + Urb40A + ")"
UrbLOS_ABPM_A_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed PM] > " + Urb30A + ")"


LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "several", HwyLOS_ABPM_A_75,)
LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "more", HwyLOS_ABPM_A_70,)
LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "more", HwyLOS_ABPM_A_65,)
LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "more", HwyLOS_ABPM_A_60,)
LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "more", HwyLOS_ABPM_A_55,)
LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "more", UrbLOS_ABPM_A_50,)
LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "more", UrbLOS_ABPM_A_40,)
LOS_A_ABPM = SelectByQuery("HwyLOS_A_ABPM", "more", UrbLOS_ABPM_A_30,)

if LOS_A_ABPM > 0 then do
	LOS_A_ABPM_Vector = Vector(LOS_A_ABPM,"Short",{{"Constant",1}})
	view_nPMe = "subzonelinelayer"
	SetDataVector(view_nPMe + "|"+ "HwyLOS_A_ABPM","AB_PM_LOS", LOS_A_ABPM_Vector,)
end

//BA PM LOSA
HwyLOS_BAPM_A_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow PM] /  [BA LANES]/2) <= " + HWY75A +")"
HwyLOS_BAPM_A_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow PM] /  [BA LANES]/2) <= " + HWY70A +")"
HwyLOS_BAPM_A_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow PM] /  [BA LANES]/2) <= " + HWY65A +")"
HwyLOS_BAPM_A_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow PM] /  [BA LANES]/2) <= " + HWY60A +")"
HwyLOS_BAPM_A_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow PM] /  [BA LANES]/2) <= " + HWY55A +")"
UrbLOS_BAPM_A_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed PM] > " + Urb50A + ")"
UrbLOS_BAPM_A_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed PM] > " + Urb40A + ")"
UrbLOS_BAPM_A_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed PM] > " + Urb30A + ")"

LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "several", HwyLOS_BAPM_A_75,)
LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "more", HwyLOS_BAPM_A_70,)
LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "more", HwyLOS_BAPM_A_65,)
LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "more", HwyLOS_BAPM_A_60,)
LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "more", HwyLOS_BAPM_A_55,)
LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "more", UrbLOS_BAPM_A_50,)
LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "more", UrbLOS_BAPM_A_40,)
LOS_A_BAPM = SelectByQuery("HwyLOS_A_BAPM", "more", UrbLOS_BAPM_A_30,)

if LOS_A_BAPM > 0 then do
	LOS_A_BAPM_Vector = Vector(LOS_A_BAPM,"Short",{{"Constant",1}})
	view_nPMe = "subzonelinelayer"
	SetDataVector(view_nPMe + "|" + "HwyLOS_A_BAPM","BA_PM_LOS", LOS_A_BAPM_Vector,)
end

//==================================================================================================
//Highway AB PM LOSB
HwyLOS_ABPM_B_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY75A +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY75B +")"
HwyLOS_ABPM_B_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY70A +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY70B +")"
HwyLOS_ABPM_B_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY65A +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY65B +")"
HwyLOS_ABPM_B_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY60A +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY60B +")"
HwyLOS_ABPM_B_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY55A +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY55B +")"
UrbLOS_ABPM_B_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed PM] >  " + Urb50B+" and [AB Speed PM] <= " + Urb50A + ")"
UrbLOS_ABPM_B_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed PM] >  " + Urb40B +" and [AB Speed PM] <= " + Urb40A + ")"
UrbLOS_ABPM_B_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed PM] >  " + Urb30B+" and [AB Speed PM] <= " + Urb30A + ")"

LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "several", HwyLOS_ABPM_B_75,)
LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "more", HwyLOS_ABPM_B_70,)
LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "more", HwyLOS_ABPM_B_65,)
LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "more", HwyLOS_ABPM_B_60,)
LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "more", HwyLOS_ABPM_B_55,)
LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "more", UrbLOS_ABPM_B_50,)
LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "more", UrbLOS_ABPM_B_40,)
LOS_B_ABPM = SelectByQuery("HwyLOS_B_ABPM", "more", UrbLOS_ABPM_B_30,)

if LOS_B_ABPM > 0 then do
	LOS_B_ABPM_Vector = Vector(LOS_B_ABPM,"Short",{{"Constant",2}})
	view_nPMe = "subzonelinelayer"
	SetDataVector(view_nPMe + "|" + "HwyLOS_B_ABPM","AB_PM_LOS", LOS_B_ABPM_Vector,)
end

//Highway BA PM LOSB
HwyLOS_BAPM_B_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY75A +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY75B +")"
HwyLOS_BAPM_B_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY70A +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY70B +")"
HwyLOS_BAPM_B_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY65A +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY65B +")"
HwyLOS_BAPM_B_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY60A +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY60B +")"
HwyLOS_BAPM_B_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and ([BA Flow PM] /  [BA LANES]/2 >  " + HWY55A +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY55B +")"
UrbLOS_BAPM_B_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed PM] >  " + Urb50B+" and [BA Speed PM] <= " + Urb50A + ")"
UrbLOS_BAPM_B_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed PM] >  " + Urb40B +" and [BA Speed PM] <= " + Urb40A + ")"
UrbLOS_BAPM_B_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed PM] >  " + Urb30B+" and [BA Speed PM] <= " + Urb30A + ")"

LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "several", HwyLOS_BAPM_B_75,)
LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "more", HwyLOS_BAPM_B_70,)
LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "more", HwyLOS_BAPM_B_65,)
LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "more", HwyLOS_BAPM_B_60,)
LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "more", HwyLOS_BAPM_B_55,)
LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "more", UrbLOS_BAPM_B_50,)
LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "more", UrbLOS_BAPM_B_40,)
LOS_B_BAPM = SelectByQuery("HwyLOS_B_BAPM", "more", UrbLOS_BAPM_B_30,)


if LOS_B_BAPM > 0 then do
	LOS_B_BAPM_Vector = Vector(LOS_B_BAPM,"Short",{{"Constant",2}})
	view_nPMe = "subzonelinelayer"
	SetDataVector(view_nPMe + "|" + "HwyLOS_B_BAPM","BA_PM_LOS", LOS_B_BAPM_Vector,)
end

//==================================================================================================
//Highway AB PM LOS C
HwyLOS_ABPM_C_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY75B +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY75C +")"
HwyLOS_ABPM_C_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY70B +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY70C +")"
HwyLOS_ABPM_C_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY65B +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY65C +")"
HwyLOS_ABPM_C_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY60B +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY60C +")"
HwyLOS_ABPM_C_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY55B +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY55C +")"
UrbLOS_ABPM_C_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed PM] >  " + Urb50C+" and [AB Speed PM] <=  " + Urb50B+")"
UrbLOS_ABPM_C_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed PM] >  " + Urb40C +" and [AB Speed PM] <=  " + Urb40B +")"
UrbLOS_ABPM_C_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed PM] >  " + Urb30C+" and [AB Speed PM] <=  " + Urb30B+")"

LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "several", HwyLOS_ABPM_C_75,)
LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "more", HwyLOS_ABPM_C_70,)
LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "more", HwyLOS_ABPM_C_65,)
LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "more", HwyLOS_ABPM_C_60,)
LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "more", HwyLOS_ABPM_C_55,)
LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "more", UrbLOS_ABPM_C_50,)
LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "more", UrbLOS_ABPM_C_40,)
LOS_C_ABPM = SelectByQuery("HwyLOS_C_ABPM", "more", UrbLOS_ABPM_C_30,)

if LOS_C_ABPM > 0 then do
	LOS_C_ABPM_Vector = Vector(LOS_C_ABPM,"Short",{{"Constant",3}})
	view_nPMe = "subzonelinelayer"
	SetDataVector(view_nPMe + "|" + "HwyLOS_C_ABPM","AB_PM_LOS", LOS_C_ABPM_Vector,)
end

//Highway BA PM LOS C
HwyLOS_BAPM_C_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY75B +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY75C +")"
HwyLOS_BAPM_C_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY70B +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY70C +")"
HwyLOS_BAPM_C_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY65B +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY65C +")"
HwyLOS_BAPM_C_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY60B +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY60C +")"
HwyLOS_BAPM_C_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY55B +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY55C +")"
UrbLOS_BAPM_C_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed PM] >  " + Urb50C+" and [BA Speed PM] <=  " + Urb50B+")"
UrbLOS_BAPM_C_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed PM] >  " + Urb40C +" and [BA Speed PM] <=  " + Urb40B +")"
UrbLOS_BAPM_C_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed PM] >  " + Urb30C+" and [BA Speed PM] <=  " + Urb30B+")"


LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "several", HwyLOS_BAPM_C_75,)
LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "more", HwyLOS_BAPM_C_70,)
LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "more", HwyLOS_BAPM_C_65,)
LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "more", HwyLOS_BAPM_C_60,)
LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "more", HwyLOS_BAPM_C_55,)
LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "more", UrbLOS_BAPM_C_50,)
LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "more", UrbLOS_BAPM_C_40,)
LOS_C_BAPM = SelectByQuery("HwyLOS_C_BAPM", "more", UrbLOS_BAPM_C_30,)

if LOS_C_BAPM > 0 then do
	LOS_C_BAPM_Vector = Vector(LOS_C_BAPM,"Short",{{"Constant",3}})
	view_nPMe = "subzonelinelayer"
	SetDataVector(view_nPMe + "|" + "HwyLOS_C_BAPM","BA_PM_LOS", LOS_C_BAPM_Vector,)
end

//==================================================================================================
//Highway AB PM LOS D
HwyLOS_ABPM_D_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY75C +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY75D +")"
HwyLOS_ABPM_D_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY70C +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY70D +")"
HwyLOS_ABPM_D_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY65C +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY65D +")"
HwyLOS_ABPM_D_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY60C +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY60D +")"
HwyLOS_ABPM_D_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY55C +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY55D +")"
UrbLOS_ABPM_D_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed PM] >  " + Urb50D +" and [AB Speed PM] <=  " + Urb50C+")"
UrbLOS_ABPM_D_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed PM] >  " + Urb40D +" and [AB Speed PM] <=  " + Urb40C +")"
UrbLOS_ABPM_D_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed PM] >  " + Urb30D +" and [AB Speed PM] <=  " + Urb30C+")"

LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "several", HwyLOS_ABPM_D_75,)
LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "more", HwyLOS_ABPM_D_70,)
LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "more", HwyLOS_ABPM_D_65,)
LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "more", HwyLOS_ABPM_D_60,)
LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "more", HwyLOS_ABPM_D_55,)
LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "more", UrbLOS_ABPM_D_50,)
LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "more", UrbLOS_ABPM_D_40,)
LOS_D_ABPM = SelectByQuery("HwyLOS_D_ABPM", "more", UrbLOS_ABPM_D_30,)

if LOS_D_ABPM > 0 then do
	LOS_D_ABPM_Vector = Vector(LOS_D_ABPM,"Short",{{"Constant",4}})
	view_nPMe = "subzonelinelayer"
	SetDataVector(view_nPMe + "|" + "HwyLOS_D_ABPM","AB_PM_LOS", LOS_D_ABPM_Vector,)
end

//Highway BA PM LOS D
HwyLOS_BAPM_D_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY75C +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY75D +")"
HwyLOS_BAPM_D_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY70C +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY70D +")"
HwyLOS_BAPM_D_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY65C +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY65D +")"
HwyLOS_BAPM_D_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY60C +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY60D +")"
HwyLOS_BAPM_D_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY55C +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY55D +")"
UrbLOS_BAPM_D_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed PM] >  " + Urb50D +" and [BA Speed PM] <=  " + Urb50C+")"
UrbLOS_BAPM_D_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed PM] >  " + Urb40D +" and [BA Speed PM] <=  " + Urb40C +")"
UrbLOS_BAPM_D_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed PM] >  " + Urb30D +" and [BA Speed PM] <=  " + Urb30C+")"

LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "several", HwyLOS_BAPM_D_75,)
LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "more", HwyLOS_BAPM_D_70,)
LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "more", HwyLOS_BAPM_D_65,)
LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "more", HwyLOS_BAPM_D_60,)
LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "more", HwyLOS_BAPM_D_55,)
LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "more", UrbLOS_BAPM_D_50,)
LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "more", UrbLOS_BAPM_D_40,)
LOS_D_BAPM = SelectByQuery("HwyLOS_D_BAPM", "more", UrbLOS_BAPM_D_30,)

if LOS_D_BAPM > 0 then do
	LOS_D_BAPM_Vector = Vector(LOS_D_BAPM,"Short",{{"Constant",4}})
	view_nPMe = "subzonelinelayer"
	SetDataVector(view_nPMe + "|" + "HwyLOS_D_BAPM","BA_PM_LOS", LOS_D_BAPM_Vector,)
end

//==================================================================================================
//Highway AB PM LOS E
HwyLOS_ABPM_E_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY75D +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY75E +")"
HwyLOS_ABPM_E_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY70D +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY70E +")"
HwyLOS_ABPM_E_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY65D +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY65E +")"
HwyLOS_ABPM_E_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY60D +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY60E +")"
HwyLOS_ABPM_E_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY55D +" and ([AB Flow PM] /  [AB LANES]/2) <=  " + HWY55E +")"
UrbLOS_ABPM_E_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed PM] >  " + Urb50E +" and [AB Speed PM] <=  " + Urb50D +")"
UrbLOS_ABPM_E_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed PM] > " + Urb40E + " and [AB Speed PM] <=  " + Urb40D +")"
UrbLOS_ABPM_E_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed PM] > " + Urb30E + " and [AB Speed PM] <=  " + Urb30D +" )"

LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "several", HwyLOS_ABPM_E_75,)
LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "more", HwyLOS_ABPM_E_70,)
LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "more", HwyLOS_ABPM_E_65,)
LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "more", HwyLOS_ABPM_E_60,)
LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "more", HwyLOS_ABPM_E_55,)
LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "more", UrbLOS_ABPM_E_50,)
LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "more", UrbLOS_ABPM_E_40,)
LOS_E_ABPM = SelectByQuery("HwyLOS_E_ABPM", "more", UrbLOS_ABPM_E_30,)

if LOS_E_ABPM > 0 then do
	LOS_E_ABPM_Vector = Vector(LOS_E_ABPM,"Short",{{"Constant",5}})
	view_nPMe = "subzonelinelayer"
	SetDataVector(view_nPMe + "|" + "HwyLOS_E_ABPM","AB_PM_LOS", LOS_E_ABPM_Vector,)
end

//Highway BA PM LOS E
HwyLOS_BAPM_E_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY75D +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY75E +")"
HwyLOS_BAPM_E_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY70D +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY70E +")"
HwyLOS_BAPM_E_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY65D +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY65E +")"
HwyLOS_BAPM_E_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY60D +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY60E +")"
HwyLOS_BAPM_E_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY55D +" and ([BA Flow PM] /  [BA LANES]/2) <=  " + HWY55E +")"
UrbLOS_BAPM_E_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed PM] >  " + Urb50E +" and [BA Speed PM] <=  " + Urb50D +")"
UrbLOS_BAPM_E_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed PM] > " + Urb40E + " and [BA Speed PM] <=  " + Urb40D +")"
UrbLOS_BAPM_E_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed PM] > " + Urb30E + " and [BA Speed PM] <=  " + Urb30D +" )"

LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "several", HwyLOS_BAPM_E_75,)
LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "more", HwyLOS_BAPM_E_70,)
LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "more", HwyLOS_BAPM_E_65,)
LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "more", HwyLOS_BAPM_E_60,)
LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "more", HwyLOS_BAPM_E_55,)
LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "more", UrbLOS_BAPM_E_50,)
LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "more", UrbLOS_BAPM_E_40,)
LOS_E_BAPM = SelectByQuery("HwyLOS_E_BAPM", "more", UrbLOS_BAPM_E_30,)

if LOS_E_BAPM > 0 then do
	LOS_E_BAPM_Vector = Vector(LOS_E_BAPM,"Short",{{"Constant",5}})
	view_nPMe = "subzonelinelayer"
	SetDataVector(view_nPMe + "|" + "HwyLOS_E_BAPM","BA_PM_LOS", LOS_E_BAPM_Vector,)
end

//==================================================================================================
//Highway AB PM LOS F
HwyLOS_ABPM_F_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY75E +")"
HwyLOS_ABPM_F_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY70E +")"
HwyLOS_ABPM_F_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY65E +")"
HwyLOS_ABPM_F_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY60E +")"
HwyLOS_ABPM_F_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow PM] /  [AB LANES]/2) >  " + HWY55E +")"
UrbLOS_ABPM_F_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed PM] <=  " + Urb50E +")"
UrbLOS_ABPM_F_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed PM] <=  " + Urb40E+")"
UrbLOS_ABPM_F_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed PM] <= " + Urb30E + ")"

LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "several", HwyLOS_ABPM_F_75,)
LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "more", HwyLOS_ABPM_F_70,)
LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "more", HwyLOS_ABPM_F_65,)
LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "more", HwyLOS_ABPM_F_60,)
LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "more", HwyLOS_ABPM_F_55,)
LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "more", UrbLOS_ABPM_F_50,)
LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "more", UrbLOS_ABPM_F_40,)
LOS_F_ABPM = SelectByQuery("HwyLOS_F_ABPM", "more", UrbLOS_ABPM_F_30,)

if LOS_F_ABPM > 0 then do
	LOS_F_ABPM_Vector = Vector(LOS_F_ABPM,"Short",{{"Constant",6}})
	view_nPMe = "subzonelinelayer"
	SetDataVector(view_nPMe + "|" + "HwyLOS_F_ABPM","AB_PM_LOS", LOS_F_ABPM_Vector,)
end

//Highway BA PM LOS F
HwyLOS_BAPM_F_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY75E +")"
HwyLOS_BAPM_F_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY70E +")"
HwyLOS_BAPM_F_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY65E +")"
HwyLOS_BAPM_F_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY60E +")"
HwyLOS_BAPM_F_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow PM] /  [BA LANES]/2) >  " + HWY55E +")"
UrbLOS_BAPM_F_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed PM] <=  " + Urb50E +")"
UrbLOS_BAPM_F_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed PM] <=  " + Urb40E+")"
UrbLOS_BAPM_F_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed PM] <= " + Urb30E + ")"

LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "several", HwyLOS_BAPM_F_75,)
LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "more", HwyLOS_BAPM_F_70,)
LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "more", HwyLOS_BAPM_F_65,)
LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "more", HwyLOS_BAPM_F_60,)
LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "more", HwyLOS_BAPM_F_55,)
LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "more", UrbLOS_BAPM_F_50,)
LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "more", UrbLOS_BAPM_F_40,)
LOS_F_BAPM = SelectByQuery("HwyLOS_F_BAPM", "more", UrbLOS_BAPM_F_30,)

if LOS_F_BAPM > 0 then do
	LOS_F_BAPM_Vector = Vector(LOS_F_BAPM,"Short",{{"Constant",6}})
	view_nPMe = "subzonelinelayer"
	SetDataVector(view_nPMe + "|" + "HwyLOS_F_BAPM","BA_PM_LOS", LOS_F_BAPM_Vector,)
end

//==================================================================================================
//AB Ni LOSA
HwyLOS_ABNi_A_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY75A +")"
HwyLOS_ABNi_A_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY70A +")"
HwyLOS_ABNi_A_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY65A +")"
HwyLOS_ABNi_A_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY60A +")"
HwyLOS_ABNi_A_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY55A +")"
UrbLOS_ABNi_A_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed NT] > " + Urb50A + ")"
UrbLOS_ABNi_A_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed NT] > " + Urb40A + ")"
UrbLOS_ABNi_A_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed NT] > " + Urb30A + ")"


LOS_A_ABNi = SelectByQuery("HwyLOS_A_ABNi", "several", HwyLOS_ABNi_A_75,)
LOS_A_ABNi = SelectByQuery("HwyLOS_A_ABNi", "more", HwyLOS_ABNi_A_70,)
LOS_A_ABNi = SelectByQuery("HwyLOS_A_ABNi", "more", HwyLOS_ABNi_A_65,)
LOS_A_ABNi = SelectByQuery("HwyLOS_A_ABNi", "more", HwyLOS_ABNi_A_60,)
LOS_A_ABNi = SelectByQuery("HwyLOS_A_ABNi", "more", HwyLOS_ABNi_A_55,)
LOS_A_ABNi = SelectByQuery("HwyLOS_A_ABNi", "more", UrbLOS_ABNi_A_50,)
LOS_A_ABNi = SelectByQuery("HwyLOS_A_ABNi", "more", UrbLOS_ABNi_A_40,)
LOS_A_ABNi = SelectByQuery("HwyLOS_A_ABNi", "more", UrbLOS_ABNi_A_30,)

if LOS_A_ABNi > 0 then do
	LOS_A_ABNi_Vector = Vector(LOS_A_ABNi,"Short",{{"Constant",1}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|"+ "HwyLOS_A_ABNi","AB_Ni_LOS", LOS_A_ABNi_Vector,)
end

//BA Ni LOSA
HwyLOS_BANi_A_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY75A +")"
HwyLOS_BANi_A_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY70A +")"
HwyLOS_BANi_A_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY65A +")"
HwyLOS_BANi_A_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY60A +")"
HwyLOS_BANi_A_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY55A +")"
UrbLOS_BANi_A_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed NT] > " + Urb50A + ")"
UrbLOS_BANi_A_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed NT] > " + Urb40A + ")"
UrbLOS_BANi_A_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed NT] > " + Urb30A + ")"

LOS_A_BANi = SelectByQuery("HwyLOS_A_BANi", "several", HwyLOS_BANi_A_75,)
LOS_A_BANi = SelectByQuery("HwyLOS_A_BANi", "more", HwyLOS_BANi_A_70,)
LOS_A_BANi = SelectByQuery("HwyLOS_A_BANi", "more", HwyLOS_BANi_A_65,)
LOS_A_BANi = SelectByQuery("HwyLOS_A_BANi", "more", HwyLOS_BANi_A_60,)
LOS_A_BANi = SelectByQuery("HwyLOS_A_BANi", "more", HwyLOS_BANi_A_55,)
LOS_A_BANi = SelectByQuery("HwyLOS_A_BANi", "more", UrbLOS_BANi_A_50,)
LOS_A_BANi = SelectByQuery("HwyLOS_A_BANi", "more", UrbLOS_BANi_A_40,)
LOS_A_BANi = SelectByQuery("HwyLOS_A_BANi", "more", UrbLOS_BANi_A_30,)

if LOS_A_BANi > 0 then do
	LOS_A_BANi_Vector = Vector(LOS_A_BANi,"Short",{{"Constant",1}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_A_BANi","BA_Ni_LOS", LOS_A_BANi_Vector,)
end

//==================================================================================================
//Highway AB Ni LOSB
HwyLOS_ABNi_B_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY75A +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY75B +")"
HwyLOS_ABNi_B_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY70A +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY70B +")"
HwyLOS_ABNi_B_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY65A +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY65B +")"
HwyLOS_ABNi_B_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY60A +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY60B +")"
HwyLOS_ABNi_B_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY55A +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY55B +")"
UrbLOS_ABNi_B_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed NT] >  " + Urb50B+" and [AB Speed NT] <= " + Urb50A + ")"
UrbLOS_ABNi_B_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed NT] >  " + Urb40B +" and [AB Speed NT] <= " + Urb40A + ")"
UrbLOS_ABNi_B_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed NT] >  " + Urb30B+" and [AB Speed NT] <= " + Urb30A + ")"

LOS_B_ABNi = SelectByQuery("HwyLOS_B_ABNi", "several", HwyLOS_ABNi_B_75,)
LOS_B_ABNi = SelectByQuery("HwyLOS_B_ABNi", "more", HwyLOS_ABNi_B_70,)
LOS_B_ABNi = SelectByQuery("HwyLOS_B_ABNi", "more", HwyLOS_ABNi_B_65,)
LOS_B_ABNi = SelectByQuery("HwyLOS_B_ABNi", "more", HwyLOS_ABNi_B_60,)
LOS_B_ABNi = SelectByQuery("HwyLOS_B_ABNi", "more", HwyLOS_ABNi_B_55,)
LOS_B_ABNi = SelectByQuery("HwyLOS_B_ABNi", "more", UrbLOS_ABNi_B_50,)
LOS_B_ABNi = SelectByQuery("HwyLOS_B_ABNi", "more", UrbLOS_ABNi_B_40,)
LOS_B_ABNi = SelectByQuery("HwyLOS_B_ABNi", "more", UrbLOS_ABNi_B_30,)

if LOS_B_ABNi > 0 then do
	LOS_B_ABNi_Vector = Vector(LOS_B_ABNi,"Short",{{"Constant",2}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_B_ABNi","AB_Ni_LOS", LOS_B_ABNi_Vector,)
end

//Highway BA Ni LOSB
HwyLOS_BANi_B_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY75A +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY75B +")"
HwyLOS_BANi_B_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY70A +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY70B +")"
HwyLOS_BANi_B_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY65A +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY65B +")"
HwyLOS_BANi_B_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY60A +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY60B +")"
HwyLOS_BANi_B_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY55A +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY55B +")"
UrbLOS_BANi_B_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed NT] >  " + Urb50B + " and [BA Speed NT] <= " + Urb50A + ")"
UrbLOS_BANi_B_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed NT] >  " + Urb40B +" and [BA Speed NT] <= " + Urb40A + ")"
UrbLOS_BANi_B_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed NT] >  " + Urb30B+" and [BA Speed NT] <= " + Urb30A + ")"

LOS_B_BANi = SelectByQuery("HwyLOS_B_BANi", "several", HwyLOS_BANi_B_75,)
LOS_B_BANi = SelectByQuery("HwyLOS_B_BANi", "more", HwyLOS_BANi_B_70,)
LOS_B_BANi = SelectByQuery("HwyLOS_B_BANi", "more", HwyLOS_BANi_B_65,)
LOS_B_BANi = SelectByQuery("HwyLOS_B_BANi", "more", HwyLOS_BANi_B_60,)
LOS_B_BANi = SelectByQuery("HwyLOS_B_BANi", "more", HwyLOS_BANi_B_55,)
LOS_B_BANi = SelectByQuery("HwyLOS_B_BANi", "more", UrbLOS_BANi_B_50,)
LOS_B_BANi = SelectByQuery("HwyLOS_B_BANi", "more", UrbLOS_BANi_B_40,)
LOS_B_BANi = SelectByQuery("HwyLOS_B_BANi", "more", UrbLOS_BANi_B_30,)


if LOS_B_BANi > 0 then do
	LOS_B_BANi_Vector = Vector(LOS_B_BANi,"Short",{{"Constant",2}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_B_BANi","BA_Ni_LOS", LOS_B_BANi_Vector,)
end

//==================================================================================================
//Highway AB Ni LOS C
HwyLOS_ABNi_C_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY75B +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY75C +")"
HwyLOS_ABNi_C_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY70B +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY70C +")"
HwyLOS_ABNi_C_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY65B +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY65C +")"
HwyLOS_ABNi_C_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY60B +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY60C +")"
HwyLOS_ABNi_C_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY55B +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY55C +")"
UrbLOS_ABNi_C_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed NT] >  " + Urb50C+" and [AB Speed NT] <=  " + Urb50B+")"
UrbLOS_ABNi_C_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed NT] >  " + Urb40C +" and [AB Speed NT] <=  " + Urb40B +")"
UrbLOS_ABNi_C_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed NT] >  " + Urb30C+" and [AB Speed NT] <=  " + Urb30B+")"

LOS_C_ABNi = SelectByQuery("HwyLOS_C_ABNi", "several", HwyLOS_ABNi_C_75,)
LOS_C_ABNi = SelectByQuery("HwyLOS_C_ABNi", "more", HwyLOS_ABNi_C_70,)
LOS_C_ABNi = SelectByQuery("HwyLOS_C_ABNi", "more", HwyLOS_ABNi_C_65,)
LOS_C_ABNi = SelectByQuery("HwyLOS_C_ABNi", "more", HwyLOS_ABNi_C_60,)
LOS_C_ABNi = SelectByQuery("HwyLOS_C_ABNi", "more", HwyLOS_ABNi_C_55,)
LOS_C_ABNi = SelectByQuery("HwyLOS_C_ABNi", "more", UrbLOS_ABNi_C_50,)
LOS_C_ABNi = SelectByQuery("HwyLOS_C_ABNi", "more", UrbLOS_ABNi_C_40,)
LOS_C_ABNi = SelectByQuery("HwyLOS_C_ABNi", "more", UrbLOS_ABNi_C_30,)

if LOS_C_ABNi > 0 then do
	LOS_C_ABNi_Vector = Vector(LOS_C_ABNi,"Short",{{"Constant",3}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_C_ABNi","AB_Ni_LOS", LOS_C_ABNi_Vector,)
end

//Highway BA Ni LOS C
HwyLOS_BANi_C_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY75B +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY75C +")"
HwyLOS_BANi_C_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY70B +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY70C +")"
HwyLOS_BANi_C_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY65B +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY65C +")"
HwyLOS_BANi_C_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY60B +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY60C +")"
HwyLOS_BANi_C_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY55B +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY55C +")"
UrbLOS_BANi_C_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed NT] >  " + Urb50C+" and [BA Speed NT] <=  " + Urb50B+")"
UrbLOS_BANi_C_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed NT] >  " + Urb40C +" and [BA Speed NT] <=  " + Urb40B +")"
UrbLOS_BANi_C_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed NT] >  " + Urb30C+" and [BA Speed NT] <=  " + Urb30B+")"


LOS_C_BANi = SelectByQuery("HwyLOS_C_BANi", "several", HwyLOS_BANi_C_75,)
LOS_C_BANi = SelectByQuery("HwyLOS_C_BANi", "more", HwyLOS_BANi_C_70,)
LOS_C_BANi = SelectByQuery("HwyLOS_C_BANi", "more", HwyLOS_BANi_C_65,)
LOS_C_BANi = SelectByQuery("HwyLOS_C_BANi", "more", HwyLOS_BANi_C_60,)
LOS_C_BANi = SelectByQuery("HwyLOS_C_BANi", "more", HwyLOS_BANi_C_55,)
LOS_C_BANi = SelectByQuery("HwyLOS_C_BANi", "more", UrbLOS_BANi_C_50,)
LOS_C_BANi = SelectByQuery("HwyLOS_C_BANi", "more", UrbLOS_BANi_C_40,)
LOS_C_BANi = SelectByQuery("HwyLOS_C_BANi", "more", UrbLOS_BANi_C_30,)

if LOS_C_BANi > 0 then do
	LOS_C_BANi_Vector = Vector(LOS_C_BANi,"Short",{{"Constant",3}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_C_BANi","BA_Ni_LOS", LOS_C_BANi_Vector,)
end

//==================================================================================================
//Highway AB Ni LOS D
HwyLOS_ABNi_D_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY75C +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY75D +")"
HwyLOS_ABNi_D_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY70C +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY70D +")"
HwyLOS_ABNi_D_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY65C +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY65D +")"
HwyLOS_ABNi_D_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY60C +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY60D +")"
HwyLOS_ABNi_D_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY55C +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY55D +")"
UrbLOS_ABNi_D_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed NT] >  " + Urb50D +" and [AB Speed NT] <=  " + Urb50C+")"
UrbLOS_ABNi_D_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed NT] >  " + Urb40D +" and [AB Speed NT] <=  " + Urb40C +")"
UrbLOS_ABNi_D_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed NT] >  " + Urb30D +" and [AB Speed NT] <=  " + Urb30C+")"

LOS_D_ABNi = SelectByQuery("HwyLOS_D_ABNi", "several", HwyLOS_ABNi_D_75,)
LOS_D_ABNi = SelectByQuery("HwyLOS_D_ABNi", "more", HwyLOS_ABNi_D_70,)
LOS_D_ABNi = SelectByQuery("HwyLOS_D_ABNi", "more", HwyLOS_ABNi_D_65,)
LOS_D_ABNi = SelectByQuery("HwyLOS_D_ABNi", "more", HwyLOS_ABNi_D_60,)
LOS_D_ABNi = SelectByQuery("HwyLOS_D_ABNi", "more", HwyLOS_ABNi_D_55,)
LOS_D_ABNi = SelectByQuery("HwyLOS_D_ABNi", "more", UrbLOS_ABNi_D_50,)
LOS_D_ABNi = SelectByQuery("HwyLOS_D_ABNi", "more", UrbLOS_ABNi_D_40,)
LOS_D_ABNi = SelectByQuery("HwyLOS_D_ABNi", "more", UrbLOS_ABNi_D_30,)

if LOS_D_ABNi > 0 then do
	LOS_D_ABNi_Vector = Vector(LOS_D_ABNi,"Short",{{"Constant",4}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_D_ABNi","AB_Ni_LOS", LOS_D_ABNi_Vector,)
end

//Highway BA Ni LOS D
HwyLOS_BANi_D_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY75C +" and [BA Flow NT] /  [BA LANES] / 12.5 <=  " + HWY75D +")"
HwyLOS_BANi_D_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY70C +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY70D +")"
HwyLOS_BANi_D_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY65C +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY65D +")"
HwyLOS_BANi_D_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY60C +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY60D +")"
HwyLOS_BANi_D_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY55C +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY55D +")"
UrbLOS_BANi_D_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed NT] >  " + Urb50D +" and [BA Speed NT] <=  " + Urb50C+")"
UrbLOS_BANi_D_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed NT] >  " + Urb40D +" and [BA Speed NT] <=  " + Urb40C +")"
UrbLOS_BANi_D_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed NT] >  " + Urb30D +" and [BA Speed NT] <=  " + Urb30C+")"

LOS_D_BANi = SelectByQuery("HwyLOS_D_BANi", "several", HwyLOS_BANi_D_75,)
LOS_D_BANi = SelectByQuery("HwyLOS_D_BANi", "more", HwyLOS_BANi_D_70,)
LOS_D_BANi = SelectByQuery("HwyLOS_D_BANi", "more", HwyLOS_BANi_D_65,)
LOS_D_BANi = SelectByQuery("HwyLOS_D_BANi", "more", HwyLOS_BANi_D_60,)
LOS_D_BANi = SelectByQuery("HwyLOS_D_BANi", "more", HwyLOS_BANi_D_55,)
LOS_D_BANi = SelectByQuery("HwyLOS_D_BANi", "more", UrbLOS_BANi_D_50,)
LOS_D_BANi = SelectByQuery("HwyLOS_D_BANi", "more", UrbLOS_BANi_D_40,)
LOS_D_BANi = SelectByQuery("HwyLOS_D_BANi", "more", UrbLOS_BANi_D_30,)

if LOS_D_BANi > 0 then do
	LOS_D_BANi_Vector = Vector(LOS_D_BANi,"Short",{{"Constant",4}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_D_BANi","BA_Ni_LOS", LOS_D_BANi_Vector,)
end

//==================================================================================================
//Highway AB Ni LOS E
HwyLOS_ABNi_E_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY75D +" and [AB Flow NT] /  [AB LANES] / 12.5 <=  " + HWY75E +")"
HwyLOS_ABNi_E_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY70D +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY70E +")"
HwyLOS_ABNi_E_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY65D +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY65E +")"
HwyLOS_ABNi_E_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY60D +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY60E +")"
HwyLOS_ABNi_E_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY55D +" and ([AB Flow NT] /  [AB LANES] / 12.5) <=  " + HWY55E +")"
UrbLOS_ABNi_E_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed NT] >  " + Urb50E +" and [AB Speed NT] <=  " + Urb50D +")"
UrbLOS_ABNi_E_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed NT] >  " + Urb40E+" and [AB Speed NT] <=  " + Urb40D +")"
UrbLOS_ABNi_E_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed NT] > " + Urb30E + " and [AB Speed NT] <=  " + Urb30D + ")"
LOS_E_ABNi = SelectByQuery("HwyLOS_E_ABNi", "several", HwyLOS_ABNi_E_75,)
LOS_E_ABNi = SelectByQuery("HwyLOS_E_ABNi", "more", HwyLOS_ABNi_E_70,)
LOS_E_ABNi = SelectByQuery("HwyLOS_E_ABNi", "more", HwyLOS_ABNi_E_65,)
LOS_E_ABNi = SelectByQuery("HwyLOS_E_ABNi", "more", HwyLOS_ABNi_E_60,)
LOS_E_ABNi = SelectByQuery("HwyLOS_E_ABNi", "more", HwyLOS_ABNi_E_55,)
LOS_E_ABNi = SelectByQuery("HwyLOS_E_ABNi", "more", UrbLOS_ABNi_E_50,)
LOS_E_ABNi = SelectByQuery("HwyLOS_E_ABNi", "more", UrbLOS_ABNi_E_40,)
LOS_E_ABNi = SelectByQuery("HwyLOS_E_ABNi", "more", UrbLOS_ABNi_E_30,)

if LOS_E_ABNi > 0 then do
	LOS_E_ABNi_Vector = Vector(LOS_E_ABNi,"Short",{{"Constant",5}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_E_ABNi","AB_Ni_LOS", LOS_E_ABNi_Vector,)
end

//Highway BA Ni LOS E
HwyLOS_BANi_E_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and ([BA Flow NT] /  [BA LANES] / 12.5 >  " + HWY75D +" and [BA Flow NT] /  [BA LANES] / 12.5 <=  " + HWY75E +")"
HwyLOS_BANi_E_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and ([BA Flow NT] /  [BA LANES] / 12.5 >  " + HWY70D +" and ([BA Flow NT] /  [BA LANES] / 2) <=  " + HWY70E +")"
HwyLOS_BANi_E_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and ([BA Flow NT] /  [BA LANES] / 12.5 >  " + HWY65D +" and ([BA Flow NT] /  [BA LANES] / 2) <=  " + HWY65E +")"
HwyLOS_BANi_E_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and ([BA Flow NT] /  [BA LANES] / 12.5 >  " + HWY60D +" and ([BA Flow NT] /  [BA LANES] / 2) <=  " + HWY60E +")"
HwyLOS_BANi_E_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and ([BA Flow NT] /  [BA LANES] / 12.5 >  " + HWY55D +" and ([BA Flow NT] /  [BA LANES] / 12.5) <=  " + HWY55E +")"
UrbLOS_BANi_E_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed NT] >  " + Urb50E +" and [BA Speed NT] <=  " + Urb50D +")"
UrbLOS_BANi_E_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed NT] >  " + Urb40E+" and [BA Speed NT] <=  " + Urb40D +")"
UrbLOS_BANi_E_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed NT] > " + Urb30E + " and [BA Speed NT] <=  " + Urb30D + ")"

LOS_E_BANi = SelectByQuery("HwyLOS_E_BANi", "several", HwyLOS_BANi_E_75,)
LOS_E_BANi = SelectByQuery("HwyLOS_E_BANi", "more", HwyLOS_BANi_E_70,)
LOS_E_BANi = SelectByQuery("HwyLOS_E_BANi", "more", HwyLOS_BANi_E_65,)
LOS_E_BANi = SelectByQuery("HwyLOS_E_BANi", "more", HwyLOS_BANi_E_60,)
LOS_E_BANi = SelectByQuery("HwyLOS_E_BANi", "more", HwyLOS_BANi_E_55,)
LOS_E_BANi = SelectByQuery("HwyLOS_E_BANi", "more", UrbLOS_BANi_E_50,)
LOS_E_BANi = SelectByQuery("HwyLOS_E_BANi", "more", UrbLOS_BANi_E_40,)
LOS_E_BANi = SelectByQuery("HwyLOS_E_BANi", "more", UrbLOS_BANi_E_30,)

if LOS_E_BANi > 0 then do
	LOS_E_BANi_Vector = Vector(LOS_E_BANi,"Short",{{"Constant",5}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_E_BANi","BA_Ni_LOS", LOS_E_BANi_Vector,)
end

//==================================================================================================
//Highway AB Ni LOS F
HwyLOS_ABNi_F_75 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] >= 75) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY75E +")"
HwyLOS_ABNi_F_70 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 75 and [AB Revised FF Speed] >= 70) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY70E +")"
HwyLOS_ABNi_F_65 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 70 and [AB Revised FF Speed] >= 65) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY65E +")"
HwyLOS_ABNi_F_60 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 65 and [AB Revised FF Speed] >= 60) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY60E +")"
HwyLOS_ABNi_F_55 = "Select * where ([AB LINKCLASS] =1 or [AB LINKCLASS] =2) and ([AB Revised FF Speed] < 60) and (([AB Flow NT] /  [AB LANES] / 12.5) >  " + HWY55E +")"
UrbLOS_ABNi_F_50 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] > 45) and ([AB Speed NT] <= " + Urb50E + ")"
UrbLOS_ABNi_F_40 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 45 and [AB Revised FF Speed] > 35) and ([AB Speed NT] <= " + Urb40E + ")"
UrbLOS_ABNi_F_30 = "Select * where ([AB LINKCLASS] =3 or [AB LINKCLASS] =4 or [AB LINKCLASS] =5 or [AB LINKCLASS] = 7) and ([AB Revised FF Speed] <= 35 and [AB Revised FF Speed] > 25) and ([AB Speed NT] <= " + Urb30E +  ")"

LOS_F_ABNi = SelectByQuery("HwyLOS_F_ABNi", "several", HwyLOS_ABNi_F_75,)
LOS_F_ABNi = SelectByQuery("HwyLOS_F_ABNi", "more", HwyLOS_ABNi_F_70,)
LOS_F_ABNi = SelectByQuery("HwyLOS_F_ABNi", "more", HwyLOS_ABNi_F_65,)
LOS_F_ABNi = SelectByQuery("HwyLOS_F_ABNi", "more", HwyLOS_ABNi_F_60,)
LOS_F_ABNi = SelectByQuery("HwyLOS_F_ABNi", "more", HwyLOS_ABNi_F_55,)
LOS_F_ABNi = SelectByQuery("HwyLOS_F_ABNi", "more", UrbLOS_ABNi_F_50,)
LOS_F_ABNi = SelectByQuery("HwyLOS_F_ABNi", "more", UrbLOS_ABNi_F_40,)
LOS_F_ABNi = SelectByQuery("HwyLOS_F_ABNi", "more", UrbLOS_ABNi_F_30,)

if LOS_F_ABNi > 0 then do
	LOS_F_ABNi_Vector = Vector(LOS_F_ABNi,"Short",{{"Constant",6}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_F_ABNi","AB_Ni_LOS", LOS_F_ABNi_Vector,)
end

//Highway BA Ni LOS F
HwyLOS_BANi_F_75 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] >= 75) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY75E +")"
HwyLOS_BANi_F_70 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 75 and [BA Revised FF Speed] >= 70) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY70E +")"
HwyLOS_BANi_F_65 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 70 and [BA Revised FF Speed] >= 65) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY65E +")"
HwyLOS_BANi_F_60 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 65 and [BA Revised FF Speed] >= 60) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY60E +")"
HwyLOS_BANi_F_55 = "Select * where ([BA LINKCLASS] =1 or [BA LINKCLASS] =2) and ([BA Revised FF Speed] < 60) and (([BA Flow NT] /  [BA LANES] / 12.5) >  " + HWY55E +")"
UrbLOS_BANi_F_50 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] > 45) and ([BA Speed NT] <=  " + Urb50E +")"
UrbLOS_BANi_F_40 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 45 and [BA Revised FF Speed] > 35) and ([BA Speed NT] <=  " + Urb40E+")"
UrbLOS_BANi_F_30 = "Select * where ([BA LINKCLASS] =3 or [BA LINKCLASS] =4 or [BA LINKCLASS] =5 or [BA LINKCLASS] = 7) and ([BA Revised FF Speed] <= 35 and [BA Revised FF Speed] > 25) and ([BA Speed NT] <= " + Urb30E + ")"

LOS_F_BANi = SelectByQuery("HwyLOS_F_BANi", "several", HwyLOS_BANi_F_75,)
LOS_F_BANi = SelectByQuery("HwyLOS_F_BANi", "more", HwyLOS_BANi_F_70,)
LOS_F_BANi = SelectByQuery("HwyLOS_F_BANi", "more", HwyLOS_BANi_F_65,)
LOS_F_BANi = SelectByQuery("HwyLOS_F_BANi", "more", HwyLOS_BANi_F_60,)
LOS_F_BANi = SelectByQuery("HwyLOS_F_BANi", "more", HwyLOS_BANi_F_55,)
LOS_F_BANi = SelectByQuery("HwyLOS_F_BANi", "more", UrbLOS_BANi_F_50,)
LOS_F_BANi = SelectByQuery("HwyLOS_F_BANi", "more", UrbLOS_BANi_F_40,)
LOS_F_BANi = SelectByQuery("HwyLOS_F_BANi", "more", UrbLOS_BANi_F_30,)

if LOS_F_BANi > 0 then do
	LOS_F_BANi_Vector = Vector(LOS_F_BANi,"Short",{{"Constant",6}})
	view_name = "subzonelinelayer"
	SetDataVector(view_name + "|" + "HwyLOS_F_BANi","BA_Ni_LOS", LOS_F_BANi_Vector,)
end


NewFlds = {{"AB_AM_ConVMT",   "real"},
   {"BA_AM_ConVMT",   "real"},
   {"AB_MD_ConVMT",   "real"},
   {"BA_MD_ConVMT",   "real"},
   {"AB_PM_ConVMT",   "real"},
   {"BA_PM_ConVMT",   "real"},
   {"AB_NT_ConVMT",   "real"},
   {"BA_NT_ConVMT",   "real"}
   }
ok = RunMacro("TCB Add View Fields", {"subzonelinelayer", NewFlds})
Opts = null
Opts.Input.[Dataview Set] = {highway_db+"|subzonelinelayer", "subzonelinelayer"}
Opts.Global.Fields = {"AB_AM_ConVMT", "BA_AM_ConVMT", "AB_MD_ConVMT", "BA_MD_ConVMT","AB_PM_ConVMT", "BA_PM_ConVMT","AB_NT_ConVMT", "BA_NT_ConVMT"}
Opts.Global.Method = "Formula"
Opts.Global.Parameter = {"(if AB_AM_LOS >=5   then [AB Flow AM]* Length   else 0)",
	"(if BA_AM_LOS >=5   then [BA Flow AM]* Length   else 0)",
	"(if AB_Mid_LOS >=5   then [AB Flow MD]* Length   else 0)",
	"(if BA_Mid_LOS >=5   then [BA Flow MD]* Length   else 0)",
	"(if AB_PM_LOS >=5   then [AB Flow PM]* Length   else 0)",
	"(if BA_PM_LOS >=5   then [BA Flow PM]* Length   else 0)",
	"(if AB_Ni_LOS >=5   then [AB Flow NT]* Length   else 0)",
	"(if BA_Ni_LOS >=5   then [BA Flow NT]* Length   else 0)",}
ok = RunMacro("TCB Run Operation", "Fill Dataview", Opts) 
if !ok then goto quit

outputFile1 = projectFolder + "output_CongestedVMT.csv"

flow_vw = OpenTable("subzonelinelayer", "FFB", {sceFolder+"out\\ASN_subzone.bin",})

ExportView(flow_vw + "|", "CSV",outputFile1,,{{"CSV Header", "True"}})

CloseView(flow_vw)
		
quit:
	return(ok)

endMacro