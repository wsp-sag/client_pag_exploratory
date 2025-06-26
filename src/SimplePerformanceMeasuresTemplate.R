list.of.packages <- c("ggplot2", "tidyverse")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos = "http://cran.us.r-project.org", dependencies = TRUE)
library(ggplot2)
library(tidyverse)
modelfolder = "MODELFOLDERREPLACE" 
#modelfolder = "C:\\TransCAD\\TelecommuteTest\\ET_Base"
#population = 1086390
Sname = "SCENARIONAMEREPLACE"

#ForFormattingPurpose. Can be any performance measures
tripbased <- read.csv("TripBased\\tripbased.csv")


#ReadDisadvantage
disadvantageFolder = "DisadvantageArea"
#disadvantageFolder = "C:\\TransCAD\\TelecommuteTest\\PerformanceMeasures\\DisadvantageArea"
mazdis <-  read.csv(paste(disadvantageFolder,"\\MAZDISADVANTAGE.csv", sep=""))
mazdisadv <-  mazdis %>% select(MAZ_ADJ, DISADV)
tazdis <-  read.csv(paste(disadvantageFolder,"\\TAZDISADVANTAGE.csv", sep=""))
tazdisadv <-  tazdis %>% select(TAZ, DISADV)
###taz or maz
###Preprocessing SE Data
se <- read.csv(paste(modelfolder,"/inputs/socec_maz.csv", sep="")) 
se$HH <- se$RESHH
se$POP <- se$RESPOP
sejoin <- se %>% select(MAZ, HH, POP)
tazse <- se %>%  
  group_by(TAZ) %>%
  summarise(HH = sum(RESHH) + sum(GQHH), POP = sum(RESPOP) + sum(GQPOP))
population = sum(se$POP)
employmentdf = read.csv(paste(modelfolder,"/inputs/naics_maz.csv", sep="")) 
employment = sum(employmentdf$Total)
######Income Quartile Assigned
household <- read.csv(paste(modelfolder,"/out/output_disaggHouseholdList.csv", sep="")) 
household$incomequartile <- cut(
  household$hhIncomeDollars, 
  breaks = quantile(household$hhIncomeDollars, probs = seq(0, 1, by = 0.25), na.rm = TRUE), 
  include.lowest = TRUE, 
  labels = c("Q1", "Q2", "Q3", "Q4")
)




trip <-  read.csv(paste(modelfolder,"/out/adjusted_disaggTripList.csv", sep="")) 
tripwithmode <- trip %>% mutate(finalmode = if_else(mode %in% c(1:4), "Auto",
                                                   if_else(mode %in% c(5:10), "Transit",
                                                           if_else(mode == 11, "Walk",
                                                                   if_else(mode == 12, "Bike",
                                                                           if_else(mode == 13, "Taxi",
                                                                                   if_else(mode == 14, "SchoolBus", "Auto")))))))

commutetrips <- tripwithmode[((tripwithmode$origPurp == 0)&(tripwithmode$destPurp == 1))|((tripwithmode$origPurp == 1)&(tripwithmode$destPurp == 0)),]
transittrips <- tripwithmode[tripwithmode$finalmode == "Transit",]

#####Filter commute trips
HTWtrips <- tripwithmode[((tripwithmode$origPurp == 0)&(tripwithmode$destPurp == 1)),]
WTHtrips <- tripwithmode[((tripwithmode$origPurp == 1)&(tripwithmode$destPurp == 0)),]


modetrips <- tripwithmode %>%  
  group_by(finalmode) %>%
  summarise(trips = n())
modetrips$source <- "ABM"
modetrips$measures <- "Mode Share"
modetrips$dim1 <- "Mode"
modetrips$dim1_value <- modetrips$finalmode
modetrips$dim2 <- ""
modetrips$dim2_value <- ""
modetrips$Scenario <- Sname
modetrips$measure_name <- "Trips"
modetrips$measure_value <- modetrips$trips
modetrips <- subset(modetrips, select = names(tripbased))

modeshare <- modetrips
modeshare$measure_name <- "Share"
modeshare$measure_value <- modeshare$measure_value/sum(modeshare$measure_value)

modePMT <- tripwithmode %>%  
  group_by(finalmode) %>%
  summarise(PMT = sum(tripDistance))

modePMT$source <- "ABM"
modePMT$measures <- "PMT"
modePMT$dim1 <- "Mode"
modePMT$dim1_value <- modePMT$finalmode
modePMT$dim2 <- ""
modePMT$dim2_value <- ""
modePMT$Scenario <- Sname
modePMT$measure_name <- "TotalPMT"
modePMT$measure_value <- modePMT$PMT
modePMT <- subset(modePMT, select = names(tripbased))

modePMTratio <- modePMT
modePMTratio$measure_name <- "PMTRatio"
modePMTratio$measure_value <- modePMTratio$measure_value/sum(modePMTratio$measure_value)

road_am <- read.csv(paste(modelfolder,"/out/hwyload_AM3.csv", sep=""))
road_md <- read.csv(paste(modelfolder,"/out/hwyload_MD3.csv", sep=""))
road_pm <- read.csv(paste(modelfolder,"/out/hwyload_PM3.csv", sep=""))
road_nt <- read.csv(paste(modelfolder,"/out/hwyload_NT3.csv", sep=""))

highway_am <- road_am[(road_am$Facility.Type!=9),]
highway_md <- road_md[(road_am$Facility.Type!=9),]
highway_pm <- road_pm[(road_am$Facility.Type!=9),]
highway_nt <- road_nt[(road_am$Facility.Type!=9),]

VMT <- sum(highway_am$Tot_VMT) + sum(highway_md$Tot_VMT) + sum(highway_pm$Tot_VMT) + sum(highway_nt$Tot_VMT)
VHT <- sum(highway_am$Tot_VHT) + sum(highway_md$Tot_VHT) + sum(highway_pm$Tot_VHT) + sum(highway_nt$Tot_VHT)
Speed <- VMT/VHT 

VMTPerCapita <- VMT/population
VHTPerCapita <- VHT/population

congestedVMTdfread <- read.csv(paste(modelfolder,"/out/output_CongestedVMT.csv", sep=""))
congestedVMTdf <- congestedVMTdfread
congestedVMT <- sum(congestedVMTdf$AB_AM_ConVMT) + sum(congestedVMTdf$BA_AM_ConVMT) + sum(congestedVMTdf$AB_MD_ConVMT) + sum(congestedVMTdf$BA_MD_ConVMT) + sum(congestedVMTdf$AB_PM_ConVMT) + sum(congestedVMTdf$BA_PM_ConVMT) + sum(congestedVMTdf$AB_NT_ConVMT) + sum(congestedVMTdf$BA_NT_ConVMT)
congestedVMTPCT <- congestedVMT/VMT

VMTresult <- data.frame("source"="ABM","measures"="VMT","dim1"="","dim1_value"="","dim2"="","dim2_value" = "", "Scenario"=Sname,"measure_name"="VMT","measure_value"=VMT)
VMTPerCapitaresult <- data.frame("source"="ABM","measures"="VMT","dim1"="","dim1_value"="","dim2"="","dim2_value" = "", "Scenario"=Sname,"measure_name"="VMTPerCapita","measure_value"=VMTPerCapita)
VHTresult <- data.frame("source"="ABM","measures"="VHT","dim1"="","dim1_value"="","dim2"="","dim2_value" = "", "Scenario"=Sname,"measure_name"="VHT","measure_value"=VHT)
VHTPerCapitaresult <- data.frame("source"="ABM","measures"="VHT","dim1"="","dim1_value"="","dim2"="","dim2_value" = "", "Scenario"=Sname,"measure_name"="VHTPerCapita","measure_value"=VHTPerCapita)
Speedresult <- data.frame("source"="ABM","measures"="Speed","dim1"="","dim1_value"="","dim2"="","dim2_value" = "", "Scenario"=Sname,"measure_name"="Speed","measure_value"=Speed)
CongestedVMTresult <- data.frame("source"="ABM","measures"="CongestedVMT","dim1"="","dim1_value"="","dim2"="","dim2_value" = "", "Scenario"=Sname,"measure_name"="CongestedVMT","measure_value"=congestedVMT)
CongestedVMTPCTresult <- data.frame("source"="ABM","measures"="CongestedVMTPCT","dim1"="","dim1_value"="","dim2"="","dim2_value" = "", "Scenario"=Sname,"measure_name"="CongestedVMTPCT","measure_value"=congestedVMTPCT)

modeCommuteTime <- commutetrips %>%  
  group_by(finalmode) %>%
  summarise(CommuteTime = mean(finalTravelMinutes),Number = n())
modeCommuteTime$source <- "ABM"
modeCommuteTime$measures <- "CommuteTime"
modeCommuteTime$dim1 <- "Mode"
modeCommuteTime$dim1_value <- modeCommuteTime$finalmode
modeCommuteTime$dim2 <- ""
modeCommuteTime$dim2_value <- ""
modeCommuteTime$Scenario <- Sname
modeCommuteTime$measure_name <- "CommuteTime"
modeCommuteTime$measure_value <- modeCommuteTime$CommuteTime
modeCommuteTime <- modeCommuteTime[modeCommuteTime$Number > 1,]
modeCommuteTime <- subset(modeCommuteTime, select = names(tripbased))

AverageTransitTravelTime <- mean(transittrips$finalTravelMinutes)
TransitTimeResult <- data.frame("source"="ABM","measures"="AverageTransitTravelTime","dim1"="","dim1_value"="","dim2"="","dim2_value" = "", "Scenario"=Sname,"measure_name"="AverageTransitTravelTime","measure_value"=AverageTransitTravelTime)

###Home to work MAZ
modeHTWMAZ <- HTWtrips %>%  
  group_by(finalmode,origMaz) %>%
  summarise(CommuteTime = mean(finalTravelMinutes))
DISHTWtripsMAZ <- merge(HTWtrips,mazdisadv,by.x="origMaz",by.y="MAZ_ADJ",all.x = TRUE)
DISmodeHTWMAZ <- DISHTWtripsMAZ %>%  
  group_by(finalmode,DISADV) %>%
  summarise(CommuteTime = mean(finalTravelMinutes),Number = n())
DISmodeHTWMAZ$source <- "ABM"
DISmodeHTWMAZ$measures <- "Disadvantage Zone Home to Work Commute Time"
DISmodeHTWMAZ$dim1 <- "Mode"
DISmodeHTWMAZ$dim1_value <- DISmodeHTWMAZ$finalmode
DISmodeHTWMAZ$dim2 <- "Disadvantage Zone"
DISmodeHTWMAZ$dim2_value <- DISmodeHTWMAZ$DISADV
DISmodeHTWMAZ$Scenario <- Sname
DISmodeHTWMAZ$measure_name <- "CommuteTime"
DISmodeHTWMAZ$measure_value <- DISmodeHTWMAZ$CommuteTime
DISmodeHTWMAZ <- DISmodeHTWMAZ[DISmodeHTWMAZ$Number > 1,]
DISmodeHTWMAZ <- subset(DISmodeHTWMAZ, select = names(tripbased))

#Work to home MAZ
modeWTHMAZ <- WTHtrips %>%  
  group_by(finalmode,destMaz) %>%
  summarise(CommuteTime = mean(finalTravelMinutes))
DISWTHtripsMAZ <- merge(WTHtrips,mazdisadv,by.x="destMaz",by.y="MAZ_ADJ",all.x = TRUE)
DISmodeWTHMAZ <- DISWTHtripsMAZ %>%  
  group_by(finalmode,DISADV) %>%
  summarise(CommuteTime = mean(finalTravelMinutes),Number = n())
DISmodeWTHMAZ$source <- "ABM"
DISmodeWTHMAZ$measures <- "Disadvantage Zone Work to Home Commute Time"
DISmodeWTHMAZ$dim1 <- "Mode"
DISmodeWTHMAZ$dim1_value <- DISmodeWTHMAZ$finalmode
DISmodeWTHMAZ$dim2 <- "Disadvantage Zone"
DISmodeWTHMAZ$dim2_value <- DISmodeWTHMAZ$DISADV
DISmodeWTHMAZ$Scenario <- Sname
DISmodeWTHMAZ$measure_name <- "CommuteTime"
DISmodeWTHMAZ$measure_value <- DISmodeWTHMAZ$CommuteTime
DISmodeWTHMAZ <- DISmodeWTHMAZ[DISmodeWTHMAZ$Number > 1,]
DISmodeWTHMAZ <- subset(DISmodeWTHMAZ, select = names(tripbased))

##### averagemodetripTimeDistance MAZ
tripwithmodehh <- merge(tripwithmode, household, by = "hhid", all.x = TRUE) 
modetripTimeDistanceMAZ <- tripwithmodehh %>%  
  group_by(finalmode,homeMaz) %>%
  summarise(SumTravelTime = sum(finalTravelMinutes),SumTravelDistance = sum(tripDistance))
sewithdis <- merge(sejoin,mazdisadv,by.x="MAZ",by.y="MAZ_ADJ",all.x = TRUE)
seDISSummary <- sewithdis %>%
  group_by(DISADV) %>%
  summarise(SUMHH = sum(HH), SUMPOP = sum(POP))
averagemodetripTimeDistanceMAZDISADV <- merge(modetripTimeDistanceMAZ,mazdisadv,by.x="homeMaz",by.y="MAZ_ADJ",all.x = TRUE)
averagemodetripTimeDistanceMAZ_DISADV_summary_bymode <- averagemodetripTimeDistanceMAZDISADV %>%  
  group_by(DISADV,finalmode) %>%
  summarise(SumTravelTime = sum(SumTravelTime),SumTravelDistance = sum(SumTravelDistance))
averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE <- merge(averagemodetripTimeDistanceMAZ_DISADV_summary_bymode,seDISSummary,by.x="DISADV",by.y="DISADV",all.x = TRUE)
averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$averageTravelTimePerHH <- averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$SumTravelTime/averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$SUMHH
averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$averageTravelTimePerPOP <- averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$SumTravelTime/averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$SUMPOP
averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$averageTravelDistancePerHH <- averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$SumTravelDistance/averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$SUMHH
averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$averageTravelDistancePerPOP <- averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$SumTravelDistance/averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$SUMPOP

averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$source <- "ABM"
averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$dim1 <- "Mode"
averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$dim1_value <- averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$finalmode
averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$dim2 <- "Disadvantage Zone"
averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$dim2_value <- averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$DISADV
averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE$Scenario <- Sname

averageTravelTimePerHHDIS <- averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE
averageTravelTimePerHHDIS$measures <- "Disadvantage Zone Average Travel Time per Household"
averageTravelTimePerHHDIS$measure_name <- "Average Travel Time per Household"
averageTravelTimePerHHDIS$measure_value <- averageTravelTimePerHHDIS$averageTravelTimePerHH
averageTravelTimePerHHDIS <- subset(averageTravelTimePerHHDIS, select = names(tripbased))

averageTravelTimePerPOPDIS <- averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE
averageTravelTimePerPOPDIS$measures <- "Disadvantage Zone Average Travel Time per Person"
averageTravelTimePerPOPDIS$measure_name <- "Average Travel Time per Person"
averageTravelTimePerPOPDIS$measure_value <- averageTravelTimePerPOPDIS$averageTravelTimePerPOP
averageTravelTimePerPOPDIS <- subset(averageTravelTimePerPOPDIS, select = names(tripbased))

averageTravelDistancePerHHDIS <- averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE
averageTravelDistancePerHHDIS$measures <- "Disadvantage Zone Average Travel Distance per Household"
averageTravelDistancePerHHDIS$measure_name <- "Average Travel Distance per Household"
averageTravelDistancePerHHDIS$measure_value <- averageTravelDistancePerHHDIS$averageTravelDistancePerHH
averageTravelDistancePerHHDIS <- subset(averageTravelDistancePerHHDIS, select = names(tripbased))

averageTravelDistancePerPOPDIS <- averagemodetripTimeDistanceMAZ_DISADV_summary_bymodeSE
averageTravelDistancePerPOPDIS$measures <- "Disadvantage Zone Average Travel Distance per Person"
averageTravelDistancePerPOPDIS$measure_name <- "Average Travel Distance per Person"
averageTravelDistancePerPOPDIS$measure_value <- averageTravelDistancePerPOPDIS$averageTravelDistancePerPOP
averageTravelDistancePerPOPDIS <- subset(averageTravelDistancePerPOPDIS, select = names(tripbased))

#######Commute trips by income quartile
commutetrips_income <- merge(commutetrips, household, by = "hhid", all.x = TRUE) 
modeCommuteTimeIncomeQuartile <- commutetrips_income %>%  
  group_by(incomequartile,finalmode) %>%
  summarise(CommuteTime = mean(finalTravelMinutes), CommuteDistance = mean(tripDistance),Number = n())
modeCommuteTimeIncomeQuartile$source <- "ABM"
modeCommuteTimeIncomeQuartile$measures <- "Average Commute Time by Mode by Income Quartile"
modeCommuteTimeIncomeQuartile$dim1 <- "Mode"
modeCommuteTimeIncomeQuartile$dim1_value <- modeCommuteTimeIncomeQuartile$finalmode
modeCommuteTimeIncomeQuartile$dim2 <- "Income Quartile"
modeCommuteTimeIncomeQuartile$dim2_value <- modeCommuteTimeIncomeQuartile$incomequartile
modeCommuteTimeIncomeQuartile$Scenario <- Sname
modeCommuteTimeIncomeQuartile$measure_name <- "Commute Time"
modeCommuteTimeIncomeQuartile$measure_value <- modeCommuteTimeIncomeQuartile$CommuteTime
modeCommuteTimeIncomeQuartile <- modeCommuteTimeIncomeQuartile[modeCommuteTimeIncomeQuartile$Number > 1,]
modeCommuteDistanceIncomeQuartile <- modeCommuteTimeIncomeQuartile
modeCommuteDistanceIncomeQuartile$measures <- "Average Commute Distance by Mode by Income Quartile"
modeCommuteDistanceIncomeQuartile$measure_name <- "Commute Distance"
modeCommuteDistanceIncomeQuartile$measure_value <- modeCommuteDistanceIncomeQuartile$CommuteDistance

modeCommuteTimeIncomeQuartile <- subset(modeCommuteTimeIncomeQuartile, select = names(tripbased))
modeCommuteDistanceIncomeQuartile <- subset(modeCommuteDistanceIncomeQuartile, select = names(tripbased))


result <- rbind(modetrips,modeshare,modePMT,modePMTratio,VMTresult,CongestedVMTresult,CongestedVMTPCTresult,VMTPerCapitaresult,VHTresult,VHTPerCapitaresult,modeCommuteTime,TransitTimeResult)
equityresult <- rbind(DISmodeHTWMAZ,DISmodeWTHMAZ,averageTravelTimePerHHDIS,averageTravelTimePerPOPDIS,averageTravelDistancePerHHDIS,averageTravelDistancePerPOPDIS,modeCommuteTimeIncomeQuartile,modeCommuteDistanceIncomeQuartile)


highwaylanemile_result <-  read.csv(paste(modelfolder,"/out/output_HighwayLaneMiles.csv", sep="")) 
transitperfreq_result <-  read.csv(paste(modelfolder,"/out/output_TransitPerFreq.csv", sep="")) 
transitquarterm_result <-  read.csv(paste(modelfolder,"/out/output_TransitQuarterMilePopEmp.csv", sep="")) 
transitspeed_result <-  read.csv(paste(modelfolder,"/out/output_TransitSpeed.csv", sep="")) 
traveltimeindex_result <-  read.csv(paste(modelfolder,"/out/output_TravelTimeIndex.csv", sep=""))

#accessibility calculation
tazSEDIS <- merge(tazse,tazdisadv,by.x="TAZ",by.y="TAZ",all.x = TRUE)

accessibilityJobs <- read.csv(paste(modelfolder,"/out/AllAccessibility.csv", sep=""))
accessiblityJobsSEDIS <- merge(accessibilityJobs,tazSEDIS,by.x="TAZ",by.y="TAZ",all.x = TRUE)
accessiblityJobsSEDIS <- accessiblityJobsSEDIS[accessiblityJobsSEDIS$TAZ < 1111,]
AutoAccess_OP <- sum(accessiblityJobsSEDIS$auto_accessibility_OP*accessiblityJobsSEDIS$POP)/sum(accessiblityJobsSEDIS$POP)
AutoAccess_PK <- sum(accessiblityJobsSEDIS$auto_accessibility_PK*accessiblityJobsSEDIS$POP)/sum(accessiblityJobsSEDIS$POP)
AutoAccess_OP_30 <- sum(accessiblityJobsSEDIS$auto_accessibility_OP_30*accessiblityJobsSEDIS$POP)/sum(accessiblityJobsSEDIS$POP)
AutoAccess_PK_30 <- sum(accessiblityJobsSEDIS$auto_accessibility_PK_30*accessiblityJobsSEDIS$POP)/sum(accessiblityJobsSEDIS$POP)
TransitAccess_OP <- sum(accessiblityJobsSEDIS$transit_accessibility_OP*accessiblityJobsSEDIS$POP)/sum(accessiblityJobsSEDIS$POP)
TransitAccess_PK <- sum(accessiblityJobsSEDIS$transit_accessibility_PK*accessiblityJobsSEDIS$POP)/sum(accessiblityJobsSEDIS$POP)
TransitAccess_OP_45 <- sum(accessiblityJobsSEDIS$transit_accessibility_OP_45*accessiblityJobsSEDIS$POP)/sum(accessiblityJobsSEDIS$POP)
TransitAccess_OP_60 <- sum(accessiblityJobsSEDIS$transit_accessibility_OP_60*accessiblityJobsSEDIS$POP)/sum(accessiblityJobsSEDIS$POP)
TransitAccess_OP_90 <- sum(accessiblityJobsSEDIS$transit_accessibility_OP_90*accessiblityJobsSEDIS$POP)/sum(accessiblityJobsSEDIS$POP)
TransitAccess_PK_45 <- sum(accessiblityJobsSEDIS$transit_accessibility_PK_45*accessiblityJobsSEDIS$POP)/sum(accessiblityJobsSEDIS$POP)
TransitAccess_PK_60 <- sum(accessiblityJobsSEDIS$transit_accessibility_PK_60*accessiblityJobsSEDIS$POP)/sum(accessiblityJobsSEDIS$POP)
TransitAccess_PK_90 <- sum(accessiblityJobsSEDIS$transit_accessibility_PK_90*accessiblityJobsSEDIS$POP)/sum(accessiblityJobsSEDIS$POP)

measure_name = c("Auto Accessibility Off Peak",
                 "Auto Accessibility Peak",
                 "Auto Accessibility Off Peak within 30 Minutes",
                 "Auto Accessibility Peak within 30 Minutes",
                 "Auto Accessibility Percentage Off Peak within 30 Minutes",
                 "Auto Accessibility Percentage Peak within 30 Minutes",
                 "Transit Accessibility Off Peak",
                 "Transit Accessibility Peak",
                 "Transit Accessibility Off Peak within 45 Minutes",
                 "Transit Accessibility Off Peak within 60 Minutes",
                 "Transit Accessibility Off Peak within 90 Minutes",
                 "Transit Accessibility Percentage Off Peak within 45 Minutes",
                 "Transit Accessibility Percentage Off Peak within 60 Minutes",
                 "Transit Accessibility Percentage Off Peak within 90 Minutes",
                 "Transit Accessibility Peak within 45 Minutes",
                 "Transit Accessibility Peak within 60 Minutes",
                 "Transit Accessibility Peak within 90 Minutes",
                 "Transit Accessibility Percetange Peak within 45 Minutes",
                 "Transit Accessibility Percentage Peak within 60 Minutes",
                 "Transit Accessibility Percentage Peak within 90 Minutes"
                 )

measure_value = c(AutoAccess_OP,AutoAccess_PK,
                  AutoAccess_OP_30,AutoAccess_PK_30,AutoAccess_OP_30/employment,AutoAccess_PK_30/employment,
                  TransitAccess_OP,TransitAccess_PK,
                  TransitAccess_OP_45,TransitAccess_OP_60,TransitAccess_OP_90,
                  TransitAccess_OP_45/employment,TransitAccess_OP_60/employment,TransitAccess_OP_90/employment,
                  TransitAccess_PK_45,TransitAccess_PK_60,TransitAccess_PK_90,
                  TransitAccess_PK_45/employment,TransitAccess_PK_60/employment,TransitAccess_PK_90/employment
                  )
AccessibilityResult <- data.frame("source"="ABM","measures"="Accessibility","dim1"="","dim1_value"="","dim2"="","dim2_value" = "", "Scenario"=Sname,"measure_name" = measure_name,"measure_value"= measure_value)



AccessibilityEquity <- accessiblityJobsSEDIS %>%  
  group_by(DISADV) %>%
  summarise(SumAutoAccessOP = sum(auto_accessibility_OP*POP), SumAutoAccessPK = sum(auto_accessibility_PK*POP),
            SumAutoAccessOP_30 = sum(auto_accessibility_OP_30*POP), SumAutoAccessPK_30 = sum(auto_accessibility_PK_30*POP),
            SumTransitAccessOP = sum(transit_accessibility_OP*POP), SumTransitAccessPK = sum(transit_accessibility_PK*POP),
            SumTransitAccessOP_45 = sum(transit_accessibility_OP_45*POP), SumTransitAccessPK_45 = sum(transit_accessibility_PK_45*POP),
            SumTransitAccessOP_60 = sum(transit_accessibility_OP_60*POP), SumTransitAccessPK_60 = sum(transit_accessibility_PK_60*POP),
            SumTransitAccessOP_90 = sum(transit_accessibility_OP_90*POP), SumTransitAccessPK_90 = sum(transit_accessibility_PK_90*POP),
            SumPop = sum(POP)
            )
AutoAccessOP_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                  "dim2"="","dim2_value" = "",
                                  "Scenario"=Sname,"measure_name" = "Auto Accessibility Off Peak",
                                  "measure_value"= AccessibilityEquity$SumAutoAccessOP/AccessibilityEquity$SumPop)
AutoAccessPK_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                  "dim2"="","dim2_value" = "",
                                  "Scenario"=Sname,"measure_name" = "Auto Accessibility Peak",
                                  "measure_value"= AccessibilityEquity$SumAutoAccessPK/AccessibilityEquity$SumPop)
AutoAccessOP_30_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                  "dim2"="","dim2_value" = "",
                                  "Scenario"=Sname,"measure_name" = "Auto Accessibility Off Peak within 30 Minutes",
                                  "measure_value"= AccessibilityEquity$SumAutoAccessOP_30/AccessibilityEquity$SumPop)
AutoAccessPK_30_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                  "dim2"="","dim2_value" = "",
                                  "Scenario"=Sname,"measure_name" = "Auto Accessibility Peak within 30 Minutes",
                                  "measure_value"= AccessibilityEquity$SumAutoAccessPK_30/AccessibilityEquity$SumPop)
TransitAccessOP_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                  "dim2"="","dim2_value" = "",
                                  "Scenario"=Sname,"measure_name" = "Transit Accessibility Off Peak",
                                  "measure_value"= AccessibilityEquity$SumTransitAccessOP/AccessibilityEquity$SumPop)
TransitAccessPK_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                  "dim2"="","dim2_value" = "",
                                  "Scenario"=Sname,"measure_name" = "Transit Accessibility Peak",
                                  "measure_value"= AccessibilityEquity$SumTransitAccessPK/AccessibilityEquity$SumPop)
TransitAccessOP_45_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                     "dim2"="","dim2_value" = "",
                                     "Scenario"=Sname,"measure_name" = "Transit Accessibility Off Peak within 45 Minutes",
                                     "measure_value"= AccessibilityEquity$SumTransitAccessOP_45/AccessibilityEquity$SumPop)
TransitAccessPK_45_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                     "dim2"="","dim2_value" = "",
                                     "Scenario"=Sname,"measure_name" = "Transit Accessibility Peak within 45 Minutes",
                                     "measure_value"= AccessibilityEquity$SumTransitAccessPK_45/AccessibilityEquity$SumPop)
TransitAccessOP_60_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                     "dim2"="","dim2_value" = "",
                                     "Scenario"=Sname,"measure_name" = "Transit Accessibility Off Peak within 60 Minutes",
                                     "measure_value"= AccessibilityEquity$SumTransitAccessOP_60/AccessibilityEquity$SumPop)
TransitAccessPK_60_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                     "dim2"="","dim2_value" = "",
                                     "Scenario"=Sname,"measure_name" = "Transit Accessibility Peak within 60 Minutes",
                                     "measure_value"= AccessibilityEquity$SumTransitAccessPK_60/AccessibilityEquity$SumPop)
TransitAccessOP_90_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                     "dim2"="","dim2_value" = "",
                                     "Scenario"=Sname,"measure_name" = "Transit Accessibility Off Peak within 90 Minutes",
                                     "measure_value"= AccessibilityEquity$SumTransitAccessOP_90/AccessibilityEquity$SumPop)
TransitAccessPK_90_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                     "dim2"="","dim2_value" = "",
                                     "Scenario"=Sname,"measure_name" = "Transit Accessibility Peak within 90 Minutes",
                                     "measure_value"= AccessibilityEquity$SumTransitAccessPK_90/AccessibilityEquity$SumPop)
JobAccessEquity <- rbind(AutoAccessOP_Equity,AutoAccessPK_Equity,AutoAccessOP_30_Equity,AutoAccessPK_30_Equity,TransitAccessOP_Equity,TransitAccessPK_Equity,
                         TransitAccessOP_45_Equity,TransitAccessPK_45_Equity,TransitAccessOP_60_Equity,TransitAccessPK_60_Equity,TransitAccessOP_90_Equity,TransitAccessPK_90_Equity)

JobAccessEquity$measures <- "JobAccessibilityEquity"

accessibilityBasicNeed <- read.csv(paste(modelfolder,"/out/AllAccessibility_BasicNeed.csv", sep="")) 
accessiblityBasicNeedSEDIS <- merge(accessibilityBasicNeed,tazSEDIS,by.x="TAZ",by.y="TAZ",all.x = TRUE)
accessiblityBasicNeedSEDIS <- accessiblityBasicNeedSEDIS[accessiblityBasicNeedSEDIS$TAZ < 1111,]
AccessibilityEquity <- accessiblityBasicNeedSEDIS %>%  
  group_by(DISADV) %>%
  summarise(SumAutoAccessOP = sum(auto_accessibility_OP*POP), SumAutoAccessPK = sum(auto_accessibility_PK*POP),
            SumAutoAccessOP_30 = sum(auto_accessibility_OP_30*POP), SumAutoAccessPK_30 = sum(auto_accessibility_PK_30*POP),
            SumTransitAccessOP = sum(transit_accessibility_OP*POP), SumTransitAccessPK = sum(transit_accessibility_PK*POP),
            SumTransitAccessOP_45 = sum(transit_accessibility_OP_45*POP), SumTransitAccessPK_45 = sum(transit_accessibility_PK_45*POP),
            SumTransitAccessOP_60 = sum(transit_accessibility_OP_60*POP), SumTransitAccessPK_60 = sum(transit_accessibility_PK_60*POP),
            SumTransitAccessOP_90 = sum(transit_accessibility_OP_90*POP), SumTransitAccessPK_90 = sum(transit_accessibility_PK_90*POP),
            SumPop = sum(POP)
  )
AutoAccessOP_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                  "dim2"="","dim2_value" = "",
                                  "Scenario"=Sname,"measure_name" = "Auto Accessibility Off Peak",
                                  "measure_value"= AccessibilityEquity$SumAutoAccessOP/AccessibilityEquity$SumPop)
AutoAccessPK_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                  "dim2"="","dim2_value" = "",
                                  "Scenario"=Sname,"measure_name" = "Auto Accessibility Peak",
                                  "measure_value"= AccessibilityEquity$SumAutoAccessPK/AccessibilityEquity$SumPop)
AutoAccessOP_30_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                     "dim2"="","dim2_value" = "",
                                     "Scenario"=Sname,"measure_name" = "Auto Accessibility Off Peak within 30 Minutes",
                                     "measure_value"= AccessibilityEquity$SumAutoAccessOP_30/AccessibilityEquity$SumPop)
AutoAccessPK_30_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                     "dim2"="","dim2_value" = "",
                                     "Scenario"=Sname,"measure_name" = "Auto Accessibility Peak within 30 Minutes",
                                     "measure_value"= AccessibilityEquity$SumAutoAccessPK_30/AccessibilityEquity$SumPop)
TransitAccessOP_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                     "dim2"="","dim2_value" = "",
                                     "Scenario"=Sname,"measure_name" = "Transit Accessibility Off Peak",
                                     "measure_value"= AccessibilityEquity$SumTransitAccessOP/AccessibilityEquity$SumPop)
TransitAccessPK_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                     "dim2"="","dim2_value" = "",
                                     "Scenario"=Sname,"measure_name" = "Transit Accessibility Peak",
                                     "measure_value"= AccessibilityEquity$SumTransitAccessPK/AccessibilityEquity$SumPop)
TransitAccessOP_45_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                        "dim2"="","dim2_value" = "",
                                        "Scenario"=Sname,"measure_name" = "Transit Accessibility Off Peak within 45 Minutes",
                                        "measure_value"= AccessibilityEquity$SumTransitAccessOP_45/AccessibilityEquity$SumPop)
TransitAccessPK_45_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                        "dim2"="","dim2_value" = "",
                                        "Scenario"=Sname,"measure_name" = "Transit Accessibility Peak within 45 Minutes",
                                        "measure_value"= AccessibilityEquity$SumTransitAccessPK_45/AccessibilityEquity$SumPop)
TransitAccessOP_60_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                        "dim2"="","dim2_value" = "",
                                        "Scenario"=Sname,"measure_name" = "Transit Accessibility Off Peak within 60 Minutes",
                                        "measure_value"= AccessibilityEquity$SumTransitAccessOP_60/AccessibilityEquity$SumPop)
TransitAccessPK_60_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                        "dim2"="","dim2_value" = "",
                                        "Scenario"=Sname,"measure_name" = "Transit Accessibility Peak within 60 Minutes",
                                        "measure_value"= AccessibilityEquity$SumTransitAccessPK_60/AccessibilityEquity$SumPop)
TransitAccessOP_90_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                        "dim2"="","dim2_value" = "",
                                        "Scenario"=Sname,"measure_name" = "Transit Accessibility Off Peak within 90 Minutes",
                                        "measure_value"= AccessibilityEquity$SumTransitAccessOP_90/AccessibilityEquity$SumPop)
TransitAccessPK_90_Equity <- data.frame("source"="ABM","measures"="AccessibilityEquity","dim1"="DisAdvantageZone","dim1_value"=AccessibilityEquity$DISADV,
                                        "dim2"="","dim2_value" = "",
                                        "Scenario"=Sname,"measure_name" = "Transit Accessibility Peak within 90 Minutes",
                                        "measure_value"= AccessibilityEquity$SumTransitAccessPK_90/AccessibilityEquity$SumPop)
BasicNeedAccessEquity <- rbind(AutoAccessOP_Equity,AutoAccessPK_Equity,AutoAccessOP_30_Equity,AutoAccessPK_30_Equity,TransitAccessOP_Equity,TransitAccessPK_Equity,
                         TransitAccessOP_45_Equity,TransitAccessPK_45_Equity,TransitAccessOP_60_Equity,TransitAccessPK_60_Equity,TransitAccessOP_90_Equity,TransitAccessPK_90_Equity)

BasicNeedAccessEquity$measures <- "BasicNeedAccessibilityEquity"


finalresult <- rbind(result,highwaylanemile_result,transitperfreq_result,transitquarterm_result,transitspeed_result,traveltimeindex_result,Speedresult,AccessibilityResult,equityresult,JobAccessEquity,BasicNeedAccessEquity)

finalresult[is.na(finalresult)] <- ""

write.csv(finalresult, paste(modelfolder,"/out/AllPerformanceMeasures_",Sname,".csv", sep=""), row.names=FALSE)
