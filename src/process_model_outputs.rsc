Macro "MOVES_input" (model_folder, output_folder, iteration)
	RunMacro("TCB Init")
	
	//************* place to make changes ********************************************
	//********************************************************************************
	
	timePeriods = {"AM","MD","PM","NT"}
	directions={"AB","BA"}
	sceOutputFolder = model_folder +"\\output\\"
	outputFileVMT = output_folder  +"\\output_TDM_VMT.csv"
	outputFileVHT = output_folder  +"\\output_TDM_VHT.csv"
	
	//sub_roadway for ID, ATYPE, AB (and BA) LINKCASS
	rdFileName = model_folder +"\\highway\\roadway.dbd"
	{node_lyr, link_lyr} = RunMacro("TCB Add DB Layers", rdFileName,,)
	
	//sub_Flows for AB (and BA) VMT and Speed
	vecVMTandSpeedAll=null
	for k=1 to timePeriods.length do
		
		binFileName="hwyload_"+timePeriods[k]+iteration+".bin"
		vwTODSubFlows=OpenTable("TOD sub_flows", "FFB", {sceOutputFolder+binFileName,})
		vwJoin=JoinViews("Sub_roadway Flow", link_lyr + ".ID", vwTODSubFlows + ".ID1",)
		 
		if k=1 then do
			vecLinkClass=GetDataVectors(vwJoin+"|",{"ID1","Length","AT","[AB LINKCLASS]","[BA LINKCLASS]"},{{"Sort Order",{{"ID1", "Ascending"}}},{"Column Based","True"},{"Missing as Zero","True"}})
		end
		
		vecVMTandSpeed=GetDataVectors(vwJoin+"|",{"AB_VMT","BA_VMT",vwTODSubFlows+".AB_Speed",vwTODSubFlows+".BA_Speed"},{{"Sort Order",{{"ID1", "Ascending"}}},{"Column Based","True"},{"Missing as Zero","True"}})
		vecVMTandSpeedAll=vecVMTandSpeedAll+vecVMTandSpeed
		
		vecVHTandSpeed=GetDataVectors(vwJoin+"|",{"AB_VHT","BA_VHT",vwTODSubFlows+".AB_Speed",vwTODSubFlows+".BA_Speed"},{{"Sort Order",{{"ID1", "Ascending"}}},{"Column Based","True"},{"Missing as Zero","True"}})
		vecVHTandSpeedAll=vecVHTandSpeedAll+vecVHTandSpeed
	end
	
	vecFinalVMTandSpeed=vecLinkClass+vecVMTandSpeedAll
	vecFinalVHTandSpeed=vecLinkClass+vecVHTandSpeedAll
	
	//write output
	vmtSpd={"VMT","Spd"}
	strLine="ID,Length,ATYPE,AB LINKCLASS,BA LINKCLASS,"
	outFile=OpenFile(outputFileVMT,"w")
	for k=1 to timePeriods.length do
		strTOD=timePeriods[k]
		
		for m=1 to vmtSpd.length do 
			strVmtSpd=vmtSpd[m]
			
			for n=1 to directions.length do 
				strDir=directions[n]
				strLine=strLine+strTOD+"_"+strDir+"_"+strVmtSpd
				
				if !(k = timePeriods.length and m = vmtSpd.length and n = directions.length) then do 
					strLine=strLine+","
				end
					
			end
		end
	end
	WriteLine(outFile, strLine) //header
	
	for k=1 to vecFinalVMTandSpeed[1].length do
		strLine=""
		for m=1 to vecFinalVMTandSpeed.length do
			if vecFinalVMTandSpeed[2][k] = 0 then do
				if vecFinalVMTandSpeed[3][k] = 9 or vecFinalVMTandSpeed[4][k] = 9 then do
					vecFinalVMTandSpeed[2][k] = 9
				end
				else do
					vecFinalVMTandSpeed[2][k] = 5 //**** IMPORTANT: Just set to suburban area ****
				end
			
			end
			if vecFinalVMTandSpeed[2][k] <> 8 and vecFinalVMTandSpeed[2][k] <> 10 then do //excluding 8:transit link, 10: walk link
				strLine=strLine+String(vecFinalVMTandSpeed[m][k])
				if m <> vecFinalVMTandSpeed.length then do
					strLine=strLine+","
				end
			end
		end
		WriteLine(outFile, strLine) //data
	end
	
	//write output
	vhtSpd={"VHT","Spd"}
	strLine="ID,Length,ATYPE,AB LINKCLASS,BA LINKCLASS,"
	outFile=OpenFile(outputFileVHT,"w")
	for k=1 to timePeriods.length do
		strTOD=timePeriods[k]
		
		for m=1 to vhtSpd.length do 
			strVmtSpd=vhtSpd[m]
			
			for n=1 to directions.length do 
				strDir=directions[n]
				strLine=strLine+strTOD+"_"+strDir+"_"+strVmtSpd
				
				if !(k = timePeriods.length and m = vhtSpd.length and n = directions.length) then do 
					strLine=strLine+","
				end
					
			end
		end
	end
	WriteLine(outFile, strLine) //header
	
	for k=1 to vecFinalVHTandSpeed[1].length do
		strLine=""
		for m=1 to vecFinalVHTandSpeed.length do
			if vecFinalVHTandSpeed[2][k] = 0 then do
				if vecFinalVHTandSpeed[3][k] = 9 or vecFinalVHTandSpeed[4][k] = 9 then do
					vecFinalVHTandSpeed[2][k] = 9
				end
				else do
					vecFinalVHTandSpeed[2][k] = 5 //**** IMPORTANT: Just set to suburban area ****
				end
			
			end
			if vecFinalVHTandSpeed[2][k] <> 8 and vecFinalVHTandSpeed[2][k] <> 10 then do //excluding 8:transit link, 10: walk link
				strLine=strLine+String(vecFinalVHTandSpeed[m][k])
				if m <> vecFinalVHTandSpeed.length then do
					strLine=strLine+","
				end
			end
		end
		WriteLine(outFile, strLine) //data
	end

endMacro
	
	
	
	