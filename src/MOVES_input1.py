'''
MOVES input from TDM, MOVES' national default, ADOT veh reg.  
Created on Mar 16, 2016
@author: hyunsooN
'''
import os
import csv, sys
import numpy as np
import VMTratiobySpeed
import pandas as pd

#global
"""+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"""
""" this is based on PAG and MAG traffic count data"""
""" if you have new count data, you need to estimate this """
""" please check attached excel spread sheet """
input_daily_to_year=340.1874147
"""+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"""

stoppingCriteria=0.0001
maxiter=30
src_rd_VMT_matrix_forecast=[]
urban_vht_ramp_ratio=0
rural_vht_ramp_ratio=0
vht_ramp_ratio=0
vmt_adjustment_factor=0
tdm_rdType_fraction={2:0,3:0,4:0,5:0}
vmt_srcType_fraction={10:0, 25:0, 40:0, 50:0, 60:0}
vmt_adjFactor_by_aggSrcTypeDic={10:0, 25:0, 40:0, 50:0, 60:0}
adot_vmt_aggDic={10:0, 20:0, 30:0, 40:0, 55:0}
roadTypeOrderDic={2:0,3:1,4:2,5:3} #matrix order
sourceTypeConvToMOVESaggType={11:10,21:25,31:25,32:25,41:40,42:40,43:40,51:50,52:50,53:50,54:50,61:60,62:60} #matrix aggregation by MOVES type
sourceTypeConvToaggType={11:10,21:20,31:30,32:30,41:40,42:40,43:40,51:50,52:50,53:50,54:50,61:60,62:60} #matrix aggregation
aggSourceTypeOrderDic={10:0,25:1,40:2,50:3,60:4} #matrix order
sourceTypeOrderDic={11:0,21:1,31:2,32:3,41:4,42:5,43:6,51:7,52:8,53:9,54:10,61:11,62:12} #matrix
natDef_VMT_dic={11:0,21:0,31:0,32:0,41:0,42:0,43:0,51:0,52:0,53:0,54:0,61:0,62:0} #initialized source type
natDef_vehReg_dic={11:0,21:0,31:0,32:0,41:0,42:0,43:0,51:0,52:0,53:0,54:0,61:0,62:0} #initialized source type
DIR=["AB","BA"]
TOD=["AM","MD","PM","NT"]
TDM_vmt=0
annual_VMT_by_srcTypeDic={10:0, 25:0, 40:0, 50:0, 60:0}
outputVMTdic={"TDMvmt":0, "VMTadjFactor":0}


def readInputs_1():
    print("##### read inputs")

    strInputADOTvehReg="../data/external/MOVES/vehicle_population/input_MOVES_ADOT_vehReg.csv"
    strInputNatlDef_base="../data/external/MOVES/MOVES_PimaCounty_default/input_MOVES_natlDef_base.csv"
    strInputNatlDef_fcst="../data/external/MOVES/MOVES_PimaCounty_default/input_MOVES_natlDef_forecast.csv"
    strInputTDMvht="../data/interim/input_TDM_VHT.csv"
    strInputTDMvmt="../data/interim/input_TDM_VMT.csv"

    fileout = open('../data/interim/output_MOVES_parameters.csv','w')
    
    #input_TDM_VHT.csv: County,Year,LDV_Gas,LDV_Diesel,LDT_Gas_Tk1,LDT_Gas_Tk2,LDT_Diesel,HDV_Gas,HDV_Diesel,Bus_Gas,Bus_Diesel,Motorcycles,Alternate_Fuels
    input_fileout=open(strInputADOTvehReg)
    dicReaderFile=csv.DictReader(input_fileout)
    Motorcycle_sum=0
    LDV_sum=0
    LDT_sum=0
    bus_sum=0 
    HDV_sum=0
    
    for row in dicReaderFile:
        Motorcycle_sum += float(row["Motorcycles"])
        LDV_sum += float(row["LDV_Gas"])+float(row["LDV_Diesel"])
        LDT_sum += float(row["LDT_Gas_Tk1"])+float(row["LDT_Gas_Tk2"])+float(row["LDT_Diesel"])
        bus_sum += float(row["Bus_Gas"])+float(row["Bus_Diesel"])
        HDV_sum += float(row["HDV_Gas"])+float(row["HDV_Diesel"])
        
    adot_vmt_aggDic.update({10:Motorcycle_sum,20:LDV_sum,30:LDT_sum,40:bus_sum,55:HDV_sum})
    input_fileout.close()
    
    #input_natlDef_base.csv: MOVESRunID,iterationID,yearID,monthID,dayID,hourID,stateID,countyID,zoneID,linkID,sourceTypeID,roadTypeID,activityTypeID,activity
    input_fileout=open(strInputNatlDef_base)
    dicReaderFile=csv.DictReader(input_fileout)
    
    for row in dicReaderFile:
        activityTypeID = int(row["activityTypeID"])
        sourceTypeID = int(row["sourceTypeID"])
        activity =  float(row["activity"])
        
        if activityTypeID==1: # VMT
            natDef_VMT_dic[sourceTypeID] += activity
        elif activityTypeID==6: # Veh. registration
            natDef_vehReg_dic[sourceTypeID] += activity
    
    input_fileout.close()
    
    #strInputNatlDef_fcst.csv: MOVESRunID,iterationID,yearID,monthID,dayID,hourID,stateID,countyID,zoneID,linkID,sourceTypeID,roadTypeID,activityTypeID,activity
    input_fileout=open(strInputNatlDef_fcst)
    dicReaderFile=csv.DictReader(input_fileout)
    
    src_rd_VMT_matrix_forecast=np.zeros((len(aggSourceTypeOrderDic),len(roadTypeOrderDic)))
    
    for row in dicReaderFile:
        activityTypeID = int(row["activityTypeID"])
        roadTypeID = int(row["roadTypeID"])
        sourceTypeID = int(row["sourceTypeID"])
        activity =  float(row["activity"])
        
        if activityTypeID==1: # VMT
            j=roadTypeOrderDic[roadTypeID]
            srcAggID=sourceTypeConvToMOVESaggType[sourceTypeID]
            i=aggSourceTypeOrderDic[srcAggID]
            src_rd_VMT_matrix_forecast[i,j] += activity      
    
    input_fileout.close()
    
    #input_TDM_VHT.csv: ID,Length, ATYPE,AB LINKCLASS,BA LINKCLASS,AM_AB_VHT,AM_BA_VHT,MD_AB_VHT,MD_BA_VHT,PM_AB_VHT,PM_BA_VHT,NT_AB_VHT,NT_BA_VHT
    #                                                 ,AM_AB_Spd,AM_BA_Spd,MD_AB_Spd,MD_BA_Spd,PM_AB_Spd,PM_BA_Spd,NT_AB_Spd,NT_BA_Spd
    input_fileout=open(strInputTDMvht)
    dicReaderFile=csv.DictReader(input_fileout)
    
    rural_vht_sum=0
    urban_vht_sum=0
    rural_vht_ramp=0
    urban_vht_ramp=0
    for row in dicReaderFile:
        linkID_i=int(row["ID"])
        areaType_i=int(row["ATYPE"])
        
        for d in range(len(DIR)):
            
            """ vht ratio of ramp """
            
            linkClass_name = DIR[d]+" LINKCLASS"
            if row[linkClass_name] != '':
                linkClass=int(row[linkClass_name])
            else:
                linkClass=0
                
            if linkClass>0 and linkClass!=9 and areaType_i==0:
                print(">>>> ERROR: area type is not specified for link ID: ",linkID_i)
                print("            please specify area type in input_TDM_VHT.csv and rerun the code")
                sys.exit()
            
            for t in range(len(TOD)):
                vht_col_name=TOD[t]+"_"+DIR[d]+"_VHT"
                if row[vht_col_name] != '':
                    vht=float(row[vht_col_name])
                else:
                    vht=0
            
                if linkClass > 0 and linkClass != 9:
                    if areaType_i == 5: # rural area
                        rural_vht_sum += vht
                        if linkClass == 6:
                            rural_vht_ramp += vht
                    else: #urban area
                        urban_vht_sum += vht
                        if linkClass == 6:
                            urban_vht_ramp += vht
    
    urban_vht_ramp_ratio = urban_vht_ramp / urban_vht_sum
    rural_vht_ramp_ratio = rural_vht_ramp / rural_vht_sum
    vht_ramp_ratio=(urban_vht_ramp + rural_vht_ramp) / (urban_vht_sum + rural_vht_sum)
    
    input_fileout.close()
    
    #input_TDM_VMT.csv: ID,Length, ATYPE,AB LINKCLASS,BA LINKCLASS,AM_AB_VMT,AM_BA_VMT,MD_AB_VMT,MD_BA_VMT,PM_AB_VMT,PM_BA_VMT,NT_AB_VMT,NT_BA_VMT
    #                                                 ,AM_AB_Spd,AM_BA_Spd,MD_AB_Spd,MD_BA_Spd,PM_AB_Spd,PM_BA_Spd,NT_AB_Spd,NT_BA_Spd
    vmt_lc_9=0
    vmt_all=0
    vmt_rdType_all=0
    vmt_rdType={2:0,3:0,4:0,5:0} # road type (2,3,4,5)
    input_fileout=open(strInputTDMvmt)
    dicReaderFile=csv.DictReader(input_fileout)
    for row in dicReaderFile:
        linkID_i=int(row["ID"])
        areaType_i=int(row["ATYPE"])
        
        for d in range(len(DIR)):
            
            """ MOVES road type """
            linkClass_name = DIR[d]+" LINKCLASS"
            if row[linkClass_name] != '':
                linkClass=int(row[linkClass_name])
            else:
                linkClass=0
                
            if linkClass>0 and linkClass!=9 and areaType_i==0:
                print(">>>> ERROR: area type is not specified for link ID: ",linkID_i)
                print("            please specify area type in input_TDM_VHT.csv and rerun the code")
                sys.exit()
            
            roadType = -1
            if areaType_i == 5: # rural area
                if linkClass == 1 or linkClass == 2 or linkClass == 6: # freeway, parkway, ramp
                    roadType = 2 # rural restricted access
                elif linkClass == 3 or linkClass == 4 or linkClass == 5 or linkClass == 7: # majArt, minArt, Collector, Frontage road
                    roadType = 3 #rural unrestricted access
            else:
                if linkClass == 1 or linkClass == 2 or linkClass == 6: # freeway, parkway, ramp
                    roadType = 4 # urban restricted access
                elif linkClass == 3 or linkClass == 4 or linkClass == 5 or linkClass == 7: # majArt, minArt, Collector, Frontage road
                    roadType = 5 #urban unrestricted access
            
            """ VMT """
            for t in range(len(TOD)):
                vmt_col_name=TOD[t]+"_"+DIR[d]+"_VMT"
                if row[vmt_col_name] != '':
                    vmt=float(row[vmt_col_name])
                else:
                    vmt=0
                
                # VMT ratio
                if linkClass > 0:
                    vmt_all +=vmt
                    if roadType > 0: 
                        vmt_rdType[roadType] += vmt
                        vmt_rdType_all += vmt
                    
                    if linkClass == 9: # centroid connector
                        vmt_lc_9 += vmt
    
    vmt_adjustment_factor = (vmt_rdType_all+vmt_lc_9) / vmt_rdType_all
    
    input_fileout.close()
    
    for key in vmt_rdType:
        ratio = vmt_rdType[key]/vmt_rdType_all
        tdm_rdType_fraction[key]=ratio
    
    outputVMTdic["TDMvmt"]=vmt_rdType_all
    outputVMTdic["VMTadjFactor"]=vmt_adjustment_factor
    fileout.write("urban_vht_ramp_ratio,rural_vht_ramp_ratio,vht_ramp_ratio, VMT_adj_factor")
    fileout.write("\n")
    strOutput=str(urban_vht_ramp_ratio)+","+str(rural_vht_ramp_ratio)+","+str(vht_ramp_ratio)+","+str(vmt_adjustment_factor)
    fileout.write(strOutput)
    fileout.write("\n")
    
    return src_rd_VMT_matrix_forecast

def vmt_adjFactor_by_srcType():
    # create ratio of each source type by national default value using base year data
    # step 1. split ADOT veh. reg. by MOVES (Pima county) national default ratio
    # step 2. aggregate ADOT veh. reg. and natl. def. vehicles by MOVES source type
    # step 3. estimated adjustment factor
    
    #step 1
    natDef_AggSum={10:0,20:0,30:0,40:0,55:0}
    natDef_Ratio={11:0,21:0,31:0,32:0,41:0,42:0,43:0,51:0,52:0,53:0,54:0,61:0,62:0}
    splitted_ADOT_vehReg={11:0,21:0,31:0,32:0,41:0,42:0,43:0,51:0,52:0,53:0,54:0,61:0,62:0}
    natDef_vehReg_sum=0
    adot_vehReg_sum=0
    for key in natDef_vehReg_dic:
        intKey=int(key/10)*10
        
        if intKey==50 or intKey ==60:
            intKey = 55 
        
        natDef_AggSum[intKey] += natDef_vehReg_dic[key]
        natDef_vehReg_sum += natDef_vehReg_dic[key]
        
    for key in natDef_vehReg_dic:
        intKey=int(key/10)*10
        if intKey==50 or intKey ==60:
            intKey = 55
            
        natDef_Ratio[key] = natDef_vehReg_dic[key]/natDef_AggSum[intKey]
        
    for key in natDef_Ratio:
        intKey=int(key/10)*10
        if intKey==50 or intKey ==60:
            intKey = 55
            
        splitted_ADOT_vehReg[key]=adot_vmt_aggDic[intKey]*natDef_Ratio[key]
    
    #step 2
    adot_AggSum={10:0,25:0,40:0,50:0,60:0}
    natDef_AggSum2={10:0,25:0,40:0,50:0,60:0}
    natDef_AggVMTsum={10:0,25:0,40:0,50:0,60:0}
   
    for key in splitted_ADOT_vehReg:
        intKey=int(key/10)*10
        if intKey==20 or intKey ==30:
            intKey = 25
        
        adot_AggSum[intKey] += splitted_ADOT_vehReg[key]
        adot_vehReg_sum += splitted_ADOT_vehReg[key]
        natDef_AggSum2[intKey] += natDef_vehReg_dic[key]
        natDef_AggVMTsum[intKey] += natDef_VMT_dic[key]
            
    #step 3
    adjNatVMTDefSum=0
    for key in adot_AggSum:
        adjFactor=adot_AggSum[key] / natDef_AggSum2[key]
        vmt_adjFactor_by_aggSrcTypeDic[key] = adjFactor
        adjNatVMTDefSum += adjFactor*natDef_AggVMTsum[key]
        
    
    #for key in natDef_AggVMTsum:
    #    vmt_srcType_fraction[key] = natDef_AggVMTsum[key] * vmt_adjFactor_by_aggSrcTypeDic[key] / adjNatVMTDefSum
        
    
def roadTypeVMTfraction(src_rd_VMT_matrix_forecast):
    # using national default road-source type VMT matrix, vmt adjustment factor (by source type),and TDM VMT fration (by road type)
    # create new road-source type VMT matrix and its fraction matrix (methodology: iteration proportional fitting)
    
    #init
    rd_fraction=[0,0,0,0]
    rd_fraction_estimate=[0,0,0,0]
    rd_adj_factor=[0,0,0,0]
    
    src_fraction=[0,0,0,0,0]
    src_fraction_estimate=[0,0,0,0,0]
    src_adj_factor=[0,0,0,0,0]
    vmt_adj_factor=[0,0,0,0,0]
    
    src_rd_VMT_matrix_operation = np.zeros((len(src_fraction),len(rd_fraction)))
    
    for key in vmt_adjFactor_by_aggSrcTypeDic:
        i=aggSourceTypeOrderDic[key]
        vmt_adj_factor[i]=vmt_adjFactor_by_aggSrcTypeDic[key]
    
    for key in tdm_rdType_fraction:
        j=roadTypeOrderDic[key]
        rd_fraction[j]=tdm_rdType_fraction[key]
    
    # forecast year VMT fraction control
    marginal_vmt_srcType=[0,0,0,0,0]
    total_sum=0
    for i in range(len(aggSourceTypeOrderDic)):
        vmtAdjFactor=vmt_adj_factor[i]
        marginal_sum=0
        for j in range(len(roadTypeOrderDic)):
            src_rd_VMT_matrix_operation[i,j] = vmtAdjFactor*src_rd_VMT_matrix_forecast[i,j]
            marginal_sum += src_rd_VMT_matrix_operation[i,j]
            total_sum += src_rd_VMT_matrix_operation[i,j]
        
        marginal_vmt_srcType[i]=marginal_sum
    
    keyOrder=[10,25,40,50,60]
    for i in range(len(marginal_vmt_srcType)):
        keyValue=keyOrder[i]
        vmt_srcType_fraction[keyValue] = marginal_vmt_srcType[i] / total_sum
        src_fraction[i]=vmt_srcType_fraction[keyValue]
    
    # IPF matrix operation
    iter_num=0
    while True:
        # marginal vmt update
        totalSum=0
        marginal_rd_vmt=[0,0,0,0]
        marginal_src_vmt=[0,0,0,0,0]
        for i in range(len(aggSourceTypeOrderDic)):
            for j in range(len(roadTypeOrderDic)):
                marginal_src_vmt[i] += src_rd_VMT_matrix_operation[i,j]
                marginal_rd_vmt[j] += src_rd_VMT_matrix_operation[i,j]
                totalSum += src_rd_VMT_matrix_operation[i,j]
                
        # update new fraction by adjusted VMT and calculated IPF adjustment factor for road type
        for j in range(len(roadTypeOrderDic)):
            rd_fraction_estimate[j] = marginal_rd_vmt[j] / totalSum
            rd_adj_factor[j] = rd_fraction[j] / rd_fraction_estimate[j]
            
        # update vmt matrix by road type adjustment factor
        for i in range(len(aggSourceTypeOrderDic)):
            for j in range(len(roadTypeOrderDic)):
                src_rd_VMT_matrix_operation[i,j] = rd_adj_factor[j]*src_rd_VMT_matrix_operation[i,j]    
        
        # marginal vmt update
        totalSum=0
        marginal_rd_vmt=[0,0,0,0]
        marginal_src_vmt=[0,0,0,0,0]
        for i in range(len(aggSourceTypeOrderDic)):
            for j in range(len(roadTypeOrderDic)):
                marginal_src_vmt[i] += src_rd_VMT_matrix_operation[i,j]
                marginal_rd_vmt[j] += src_rd_VMT_matrix_operation[i,j]
                totalSum += src_rd_VMT_matrix_operation[i,j]
        
        # update new fraction for source type
        for i in range(len(aggSourceTypeOrderDic)):
            src_fraction_estimate[i] = marginal_src_vmt[i] / totalSum
            src_adj_factor[i] = src_fraction[i] / src_fraction_estimate[i]
            
        # update vmt matrix by source type
        for i in range(len(aggSourceTypeOrderDic)):
            for j in range(len(roadTypeOrderDic)):
                src_rd_VMT_matrix_operation[i,j] = src_adj_factor[i]*src_rd_VMT_matrix_operation[i,j]
        
        # evaluation of stop
        max_factor=0
        for i in range(len(aggSourceTypeOrderDic)):
            max_factor=max(max_factor,abs(1-src_adj_factor[i]))
        for j in range(len(roadTypeOrderDic)):
            max_factor=max(max_factor,abs(1-rd_adj_factor[j]))
        
        if max_factor <= stoppingCriteria or iter_num > maxiter:
            break
        
        # number of iterations
        iter_num += 1
        
    #create source-road type VMT fraction distribution table
    src_rd_VMT_fraction_matrix = np.zeros((len(src_fraction),len(rd_fraction)))
    
    # marginal vmt update
    marginal_src_vmt=[0,0,0,0,0]
    for i in range(len(aggSourceTypeOrderDic)):
        for j in range(len(roadTypeOrderDic)):
            marginal_src_vmt[i] += src_rd_VMT_matrix_operation[i,j]
    
    # write source-road type distribution table for MOVES input
    fileout = open('../data/interim/input_roadTypeDistribution.csv','w')
    fileout.write("sourceTypeID,roadTypeID,roadTypeVMTFraction")
    fileout.write("\n")
    rdTypeOrder=[2,3,4,5]
    srcTypeOrder=[10,25,40,50,60]
    srcTypeOrderDic={10:[11],25:[21,31,32],40:[41,42,43],50:[51,52,53,54],60:[61,62]}
    
    for i in range(len(aggSourceTypeOrderDic)):
        aggSrcTypeID = srcTypeOrder[i]
        subSrcTypeVec = srcTypeOrderDic[aggSrcTypeID]
        for sub_i in range(len(subSrcTypeVec)): # need to add road-type 1 as a place holder
            subSrcTypeID=subSrcTypeVec[sub_i]
            strOutput=str(subSrcTypeID)+",1,0"
            fileout.write(strOutput)
            fileout.write("\n")
    
    for j in range(len(roadTypeOrderDic)):
        rdTypeID=rdTypeOrder[j]
        for i in range(len(aggSourceTypeOrderDic)):
            src_rd_VMT_fraction_matrix[i,j]=src_rd_VMT_matrix_operation[i,j]/marginal_src_vmt[i]
            aggSrcTypeID = srcTypeOrder[i]
            subSrcTypeVec = srcTypeOrderDic[aggSrcTypeID]
            
            for sub_i in range(len(subSrcTypeVec)):
                subSrcTypeID=subSrcTypeVec[sub_i]
                strOutput=str(subSrcTypeID)+","+str(rdTypeID)+","+str(src_rd_VMT_fraction_matrix[i,j])
                fileout.write(strOutput)
                fileout.write("\n")
                
    fileout.close()
    
    fileout2 = open('../data/interim/output_roadTypeDistribution.csv','w')
    fileout2.write("sourceTypeID,roadTypeID,roadTypeVMTFraction")
    fileout2.write("\n")
    for i in range(len(aggSourceTypeOrderDic)):
        aggSrcTypeID = srcTypeOrder[i]
        subSrcTypeVec = srcTypeOrderDic[aggSrcTypeID]
        for sub_i in range(len(subSrcTypeVec)):
            subSrcTypeID=subSrcTypeVec[sub_i]
            for j in range(len(roadTypeOrderDic)):
                rdTypeID=rdTypeOrder[j]
                src_rd_VMT_fraction_matrix[i,j]=src_rd_VMT_matrix_operation[i,j]/marginal_src_vmt[i]
                strOutput=str(subSrcTypeID)+","+str(rdTypeID)+","+str(src_rd_VMT_fraction_matrix[i,j])
                fileout2.write(strOutput)
                fileout2.write("\n")  
    
    return src_rd_VMT_fraction_matrix 

def annual_VMT_by_sourceType():
    
    annual_VMT= outputVMTdic["TDMvmt"]*input_daily_to_year*outputVMTdic["VMTadjFactor"]
    fileout = open('../data/interim/output_annualVMTbySrcType.csv','w')
    
    outputVec=["","","","",""]
    for key in vmt_srcType_fraction:
        annual_VMT_by_srcTypeDic[key]=annual_VMT*vmt_srcType_fraction[key]
        strOutput=str(key)+","+str(annual_VMT_by_srcTypeDic[key])
        i=aggSourceTypeOrderDic[key]
        outputVec[i]=strOutput
        
    fileout.write("VehType,AnnualVMT")
    fileout.write("\n")
    for i in range(len(outputVec)):
        fileout.write(outputVec[i])
        fileout.write("\n")

def main():
    vmtMat=readInputs_1()
    vmt_adjFactor_by_srcType()
    roadTypeVMTfraction(vmtMat)
    annual_VMT_by_sourceType()
    print("")
    print("MOVES input 1 generated!")
    
    vhtmtx = VMTratiobySpeed.readInputs()
    VMTratiobySpeed.calcVHTratioBySpeed(vhtmtx)
    print("")
    print("Speed VHT calculation has been completed!")

if __name__=="__main__":
    main()
    