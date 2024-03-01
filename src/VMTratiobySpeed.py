'''
VHT ratio by speed category
Created on Feb 27, 2015
@author: hyunsoo Noh
'''

import time, csv
import numpy as np

# global
rdTypeVec=[]
spdBinVec=[]
TOD=["AM","MD","PM","NT"]
DIR=["AB","BA"]
DayID=[2,5] # 5: weekdays, 2:weekends
HourID=[]
RdSrctypeRatioDict={}
srcUseTypeDict={}
HrPropByTripVec={}
RoadLinkVec=[]
#HPMStypeDict={10:0, 20:0, 30:0, 40:0, 50:0, 60:0} #initialization with zero, see the input_sourceUseType.csv
sourceTypeVec=[]
srcHPMSVec=[]
HPMSsrcDict={}

vht_RdType_TOD_SpdBinVec=[] # input format
vht_SrcRdType_Hour_SpdBinVec=[] # output format

def readInputs():
    print("##### read inputs")
    
    strInputTDMvht="input_TDM_VHT.csv"
    strInputSpdBins="input_speedBins.csv"
    strInputSrcUseType="input_sourceUseType.csv"
    strInputRdType="input_roadTypes.csv"
    strInputRDTypeDist="input_roadTypeDistribution.csv"
    strInputHrDay="input_hourDay.csv"
    strInputTripsByHr="input_tripsByHour.csv"
    
    
    #input_tripsByHour.csv: HR,TOD,Trips_All,Proportion,ProportionTOD
    input_fileout=open(strInputTripsByHr)
    dicReaderFile=csv.DictReader(input_fileout)
    for row in dicReaderFile:
        hourID_i=int(row["HR"])
        #trips_i=float(row["Trips_All"])
        #todFlag_i=row["TOD"]
        propByTOD_i=float(row["ProportionTOD"])
        HrPropByTripVec[hourID_i]=propByTOD_i
    
    #input_hourDay.csv: hourDayID,dayID,dayName,hourID,hourname
    input_fileout=open(strInputHrDay)
    dicReaderFile=csv.DictReader(input_fileout)
    for row in dicReaderFile:
        hourID_i=row["hourID"]
        HourID.append(hourID_i)
        
    #input_roadTypes.csv: roadTypeID,roadDesc,PAG description
    input_fileout=open(strInputRdType)
    dicReaderFile=csv.DictReader(input_fileout)
    for row in dicReaderFile:
        rdTypeID_i=int(row["roadTypeID"])
        rdTypeVec.append(rdTypeID_i)
    
    #input_speedBins.csv: avgSpeedBinID,avgBinSpeed,avgSpeedBinDesc,opModeIDTirewear,opModeIDRunning
    input_fileout=open(strInputSpdBins)
    dicReaderFile=csv.DictReader(input_fileout)
    for row in dicReaderFile:
        spdBinID_i=int(row["avgSpeedBinID"])
        avgBinSpd_i=float(row["avgBinSpeed"])
        spdDesc_i=row["avgSpeedBinDesc"]
        spdBin_i=(spdBinID_i,avgBinSpd_i,spdDesc_i)
        spdBinVec.append(spdBin_i)
        
    #input_sourceUseType.csv: sourceTypeID,sourceTypeName,HPMSVtypeID,HPMSVtypeName
    input_fileout=open(strInputSrcUseType)
    dicReaderFile=csv.DictReader(input_fileout)
    for row in dicReaderFile:
        srcTypeID_i=int(row["sourceTypeID"])
        #HPMStypeID_i=int(row["HPMSVtypeID"])
        
        srcHPMSVec.append(srcTypeID_i)
        #HPMSsrcDict[HPMStypeID_i]={}
        
    #input_roadTypeDistribution.csv: roadTypeID    sourceTypeID    trafficCountsProportion\
    input_fileout=open(strInputRDTypeDist)
    dicReaderFile=csv.DictReader(input_fileout)
    for row in dicReaderFile:
        rdTypeID=row["roadTypeID"]
        srcTypeID=row["sourceTypeID"]
        #trafficCounts=float(row["trafficCounts"])
        fraction=float(row["roadTypeVMTFraction"])
        rdSrcTypeID=rdTypeID+srcTypeID
        RdSrctypeRatioDict[rdSrcTypeID]=fraction
        
    # size allocation
    vht_RdType_TOD_SpdBinVec=np.zeros((len(rdTypeVec),len(TOD),len(spdBinVec))) # [Road type (1 to 5)] X [TOD (AM,MD,PM,NT)] X [Speed Bin (1 to 16)]
    
    #input_TDMvht.csv: ID,ATYPE,AB LINKCLASS,BA LINKCLASS,AM_AB_VHT,AM_BA_VHT,MD_AB_VHT,MD_BA_VHT,PM_AB_VHT,PM_BA_VHT,NT_AB_VHT,NT_BA_VHT
    #                                                 ,AM_AB_Spd,AM_BA_Spd,MD_AB_Spd,MD_BA_Spd,PM_AB_Spd,PM_BA_Spd,NT_AB_Spd,NT_BA_Spd
    vhtSum=0
    vhtSum1=0
    vhtCentroidCon=0
    input_fileout=open(strInputTDMvht)
    dicReaderFile=csv.DictReader(input_fileout)
    for row in dicReaderFile:
        areaType_i=int(row["ATYPE"])
        
        for j in range(len(DIR)):

            """ road type """
            linkClass_name = DIR[j]+" LINKCLASS"
            if row[linkClass_name] != '':
                linkClass=int(row[linkClass_name])
            else:
                linkClass=0
            
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
            
            """Search spd bin"""
            for i in range(len(TOD)):    
                """ speed bin """
                TODname=TOD[i]
                todFlag=-1
                if TODname =='AM':
                    todFlag=0
                elif TODname == 'MD':
                    todFlag=1
                elif TODname == 'PM':
                    todFlag=2
                elif TODname == 'NT':
                    todFlag=3
                else:
                    print(">>>> ERROR: TOD flag should be in (1 to 4)")
                    time.sleep(10)
                
                spdType_name = TOD[i] + "_" + DIR[j] + "_Spd"
                
                if row[spdType_name] != '':
                    speed = float(row[spdType_name])
                else:
                    speed = 0
                
                speedBin = 0
                for k in range(len(spdBinVec)):
                    binID=spdBinVec[k][0]
                    avgBinSpd = spdBinVec[k][1]
                    
                    if binID != 1 and binID != int(len(spdBinVec)):
                        minSpd = avgBinSpd - 2.5
                        maxSpd = avgBinSpd + 2.5
                    else:
                        if binID == 1:
                            minSpd = 0
                            maxSpd = avgBinSpd
                        else:
                            minSpd = avgBinSpd
                            maxSpd = 9999
                    
                    if speed >= minSpd and speed < maxSpd:
                        if speed != 0:
                            speedBin = binID
                        else: # no directional link exist in traffic network
                            speedBin = 0
                
                """ VHT by Spd bin """
                vhtType_name = TOD[i] + "_" + DIR[j] + "_VHT" 
                
                if row[vhtType_name] != '':
                    vht = float(row[vhtType_name])
                else:
                    vht = 0
                vhtSum1+=vht
                
                # update [Road type (2 to 5)] X [TOD (AM,MD,PM,NT)] X [Speed Bin (1 to 16)]
                if roadType > 0:
                    vht_RdType_TOD_SpdBinVec[roadType-1,todFlag,speedBin-1]+=vht
                    vhtSum+=vht
                    #print('rdType:',roadType,' tod:',todFlag, ' speedBin:',speedBin, ' vht:', vht_RdType_TOD_SpdBinVec[roadType-1,todFlag-1,speedBin-1])
                else:
                    vhtCentroidCon+=vht
                    
    print("total VHT (except linktype 9): ",vhtSum1)
    print(" linktype 1 to 8:",vhtSum,", linktype 9:",vhtCentroidCon)
    print("")
    return vht_RdType_TOD_SpdBinVec
            

def calcVHTratioBySpeed(vht_RdType_TOD_SpdBinVec):
    print("##### calculate VHT ratio by speed category"    )
    
    """vht matrix [road type,hour,speed bin]"""
    tmp_vht_RdType_HR_SpdBinVec=np.zeros((len(rdTypeVec),len(HourID),len(spdBinVec))) # [Road type (1 to 5)] X [HR (0 to 23)] X [Speed Bin (1 to 16)]
    
    vhtSum1=0
    vhtSumAM=0
    vhtSumMD=0
    vhtSumPM=0
    vhtSumNT=0
    for i in range(len(rdTypeVec)):
        rdtype=rdTypeVec[i]
        
        for j in range(len(spdBinVec)):
            spdBin= spdBinVec[j][0]
            
            for tod in range(len(TOD)):
                vht_rd_spdbin_tod=vht_RdType_TOD_SpdBinVec[rdtype-1,tod,spdBin-1]
                vhtSum1 += vht_rd_spdbin_tod
                todName=TOD[tod]
            
                for hr in range(len(HourID)):
                    tripProbByHr = HrPropByTripVec[hr]
                    vhtByHR = vht_rd_spdbin_tod*tripProbByHr
                     
                    if todName == "AM":
                        if hr >= 7 and hr < 9:
                            tmp_vht_RdType_HR_SpdBinVec[rdtype-1,hr,spdBin-1]=vhtByHR
                            vhtSumAM+=vhtByHR
                    elif todName == "MD":
                        if hr >= 9 and hr <16:
                            tmp_vht_RdType_HR_SpdBinVec[rdtype-1,hr,spdBin-1]=vhtByHR
                            vhtSumMD+=vhtByHR
                    elif todName == "PM":
                        if hr >= 16 and hr <18:
                            tmp_vht_RdType_HR_SpdBinVec[rdtype-1,hr,spdBin-1]=vhtByHR
                            vhtSumPM+=vhtByHR
                    elif todName == "NT":   
                        if hr < 7 or hr >= 18:
                            tmp_vht_RdType_HR_SpdBinVec[rdtype-1,hr,spdBin-1]=vhtByHR
                            vhtSumNT+=vhtByHR
                    else:
                        print(">>>> ERROR: TOD flag should be in (0 to 3)")
                        time.sleep(10)
    
    vhtSum2=vhtSumAM+vhtSumMD+vhtSumPM+vhtSumNT
    print("vhtSum_TOD: ",vhtSum2)
    print(" AM:",vhtSumAM,", MD:",vhtSumMD,", PM:",vhtSumPM,", NT:",vhtSumNT )
    if abs(vhtSum1-vhtSum2) > 0.5:
        print(">>>> ERROR: VHT sums by TOD and Hr are different")
        time.sleep(10)
    print("")
     
    
    """vht matrix [source use type,road type,hour,speed bin]"""  
    vht_SrcRdType_Hour_SpdBinVec=np.zeros((len(srcHPMSVec),len(rdTypeVec),len(HourID),len(spdBinVec))) # [Source type (11 to 62)][Road type (1 to 5)] X [HR (0 to 23)] X [Speed Bin (1 to 16)]
           
    vhtSum=0
    vhtSrcSumDict={11:0,21:0,31:0,32:0,41:0,42:0,43:0,54:0,51:0,52:0,53:0,61:0,62:0}
    for i in range(len(rdTypeVec)):
        rdtype=rdTypeVec[i]
        
        for j in range(len(spdBinVec)):
            spdBin= spdBinVec[j][0]
            
            for hr in range(len(HourID)):
                vht_rd_spdbin_hr=tmp_vht_RdType_HR_SpdBinVec[rdtype-1,hr,spdBin-1]
                
                for k in range(len(srcHPMSVec)):
                    srcTypeID=srcHPMSVec[k]
                    strRdSrcType=str(rdtype)+str(srcTypeID)
                    prob_rd_srcType=RdSrctypeRatioDict[strRdSrcType]
                    
                    vhtBySrcType=vht_rd_spdbin_hr*prob_rd_srcType
                   
                    prevSum=vhtSrcSumDict[srcTypeID]
                    newSum=prevSum+vhtBySrcType
                    vhtSrcSumDict.update({srcTypeID:newSum})
                    
                    vht_SrcRdType_Hour_SpdBinVec[k,rdtype-1,hr,spdBin-1]=vhtBySrcType
                    vhtSum+=vhtBySrcType
    
    print("vhtSum_final:", vhtSum)
    for i in range(len(srcHPMSVec)):
        srcTypeID=srcHPMSVec[i]
        print(" Srctype:",srcTypeID,", vht:",vhtSrcSumDict[srcTypeID])
 
    """vht proportion by speed bin [source use type,road type,hour,speed bin]"""
    tmpSumBySpeedBin=[] #sum from 1 to 16 by every Speed Bin block
    for i in range(len(srcHPMSVec)):
        for j in range(len(rdTypeVec)):
            for hr in range(len(HourID)):
                sumSpeedBin=0
                for s in range(len(spdBinVec)):
                    sumSpeedBin+=vht_SrcRdType_Hour_SpdBinVec[i,j,hr,s]
                    
                tmpSumBySpeedBin.append(sumSpeedBin)
                #print(sumSpeedBin)
    tmpSumBySpeedBin.reverse()
    
    """ output """
    fileout = open('output_VHTbySpeedBin.csv','w')
    fileout.write("sourceTypeID,roadTypeID,hourDayID,avgSpeedBinID,avgSpeedFraction")
    fileout.write("\n")
    
    for i in range(len(srcHPMSVec)):
        sourcetype=srcHPMSVec[i]
        
        for j in range(len(rdTypeVec)):
            rdtype=rdTypeVec[j]
            
            for hr in range(len(HourID)):
                sumSpeedBin=tmpSumBySpeedBin.pop()    
                
                for d in range(len(DayID)):
                    daytype=DayID[d]
                    hrDay=str(hr+1)+str(daytype)
                    
                    for s in range(len(spdBinVec)):
                        spdbin=spdBinVec[s][0]
            
                        if sumSpeedBin != 0:
                            probSpeedBin = vht_SrcRdType_Hour_SpdBinVec[i,j,hr,s]/sumSpeedBin
                        else:
                            probSpeedBin = 0
                               
                        if rdtype > 1:
                            strOutput=str(sourcetype)+","+str(rdtype)+","+str(hrDay)+","+str(spdbin)+","+str(probSpeedBin)
                            #strOutput=str(sourcetype)+","+str(rdtype)+","+str(hr)+","+str(daytype)+","+str(spdbin)+","+str(vht_SrcRdType_Hour_SpdBinVec[i,j,hr,s])+","+str(sumSpeedBin)
                            fileout.write(strOutput)
                            fileout.write("\n")
                            #print(sourcetype,",",rdtype,",",hr,",",daytype,",",spdbin,",",vht_SrcRdType_Hour_SpdBinVec[i,j,hr,s])
                
                #tmpSumBySpeedBin.remove(sumSpeedBin)
    
    fileout.close()
    
"""def main():
    readInputs_1()
    
    #vhtmtx = readInputs()
    #calcVHTratioBySpeed(vhtmtx)
    print("")
    print("Speed VHT calculation has been completed!")

if __name__=="__main__":
    main()
"""