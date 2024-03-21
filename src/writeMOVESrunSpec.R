library(readr)
parameters <- read_lines('config/parameters.txt', skip_empty_rows = T)
YEAR <- as.integer(parameters[2])
descriptionText <- parameters[4]
SENARIO_NAME <- parameters[6]
inputDatabaseName <- paste0(parameters[2], "_moves4_in_", SENARIO_NAME)
outputDatabaseName <- paste0(parameters[2], "_moves4_out_", SENARIO_NAME)
outputMRSfilepath <- paste0(parameters[2], "_moves4_", SENARIO_NAME, ".mrs")

# ---- !!! USER ACTION NEEDED HERE !!! ----
# Change the year, the description, the database names, and the output MRS file path as needed.
# YEAR <- 2055
# descriptionText <- 'Test run for MOVES 4 automation development for all criteria pollutants (CO, CO2e, NOx, PM2.5, PM10, VOC) for Pima County, AZ, for 2055 with output emissions by source type, month, and day type'
# inputDatabaseName <- '2055_moves4_test02c_in_20231122'
# outputDatabaseName <- '2055_moves4_test02c_out_20231122'
# outputMRSfilepath <- 'C:/Users/RyanH/Desktop/airQualityUpdate_fall2023/MOVES_automation/MOVES4_automationTesting/2055_moves4_test02c_20231122.mrs'

# Comment/uncomment lines (by adding/deleting #) for onroad/nonroad, inventory/rates, and domain as appropriate.
modelsText <- '<models>\n    <model value="ONROAD"/>\n</models>'    # uncomment to run for onroad
#modelsText <- '<models>\n    <model value="NONROAD"/>\n</models>'  # uncomment to run for nonroad

modelscaleText <- '<modelscale value="Inv"/>'                       # uncomment to run in inventory mode
#modelscaleText <- '<modelscale value="Rates"/>'                    # uncomment to run in rates mode

#modeldomainText <- '<modeldomain value="DEFAULT"/>'                # uncomment to run at the default level
modeldomainText <- '<modeldomain value="SINGLE"/>'                  # uncomment to run at the county level
#modeldomainText <- '<modeldomain value="PROJECT"/>'                # uncomment to run at the project level

# For the following options of how the output is reported, generally only the option to report emissions by source use type is set to 'true'.
# Some or all of the other options can be set to 'true', but note then that the number of output records will increase and that manual post processing may be needed.
# There are also other output options that are not listed in this section but are listed below in the section 'output' that can be changed directly in that section if needed.
outputByModelYear <- 'false'
outputByFuelType <- 'false'
outputByFuelSubtype <- 'false'
outputByEmissionProcess <- 'false'
outputByRoadType <- 'false'
outputBySourceUseType <- 'true'

# ---- basic information for MOVES 4 run for Pima County ----
headerText <- '<runspec version="MOVES4.0.0">'

descriptionText <- paste0('<description><![CDATA[', descriptionText, ']]></description>')

MRS <- paste(headerText, descriptionText, modelsText, modelscaleText, modeldomainText, sep = '\n')


# ---- geography ----
geographicselectionsText <-
'<geographicselections>
    <geographicselection type="COUNTY" key="4019" description="Arizona - Pima County"/>
</geographicselections>'

MRS <- paste(MRS, geographicselectionsText, sep = '\n')


# ---- time span ----
timespanText <-
paste0('<timespan>
    <year key="', YEAR, '"/>
    <month id="1"/>
    <month id="2"/>
    <month id="3"/>
    <month id="4"/>
    <month id="5"/>
    <month id="6"/>
    <month id="7"/>
    <month id="8"/>
    <month id="9"/>
    <month id="10"/>
    <month id="11"/>
    <month id="12"/>
    <day id="2"/>
    <day id="5"/>
    <beginhour id="1"/>
    <endhour id="24"/>
    <aggregateBy key="Hour"/>
</timespan>')

MRS <- paste(MRS, timespanText, sep = '\n')


# ---- on road vehicles ----
onroadVehiclesText <-
'<onroadvehicleselections>
    <onroadvehicleselection fueltypeid="3" fueltypedesc="Compressed Natural Gas (CNG)" sourcetypeid="62" sourcetypename="Combination Long-haul Truck"/>
    <onroadvehicleselection fueltypeid="2" fueltypedesc="Diesel Fuel" sourcetypeid="62" sourcetypename="Combination Long-haul Truck"/>
    <onroadvehicleselection fueltypeid="9" fueltypedesc="Electricity" sourcetypeid="62" sourcetypename="Combination Long-haul Truck"/>
    <onroadvehicleselection fueltypeid="3" fueltypedesc="Compressed Natural Gas (CNG)" sourcetypeid="61" sourcetypename="Combination Short-haul Truck"/>
    <onroadvehicleselection fueltypeid="2" fueltypedesc="Diesel Fuel" sourcetypeid="61" sourcetypename="Combination Short-haul Truck"/>
    <onroadvehicleselection fueltypeid="9" fueltypedesc="Electricity" sourcetypeid="61" sourcetypename="Combination Short-haul Truck"/>
    <onroadvehicleselection fueltypeid="1" fueltypedesc="Gasoline" sourcetypeid="61" sourcetypename="Combination Short-haul Truck"/>
    <onroadvehicleselection fueltypeid="2" fueltypedesc="Diesel Fuel" sourcetypeid="32" sourcetypename="Light Commercial Truck"/>
    <onroadvehicleselection fueltypeid="9" fueltypedesc="Electricity" sourcetypeid="32" sourcetypename="Light Commercial Truck"/>
    <onroadvehicleselection fueltypeid="5" fueltypedesc="Ethanol (E-85)" sourcetypeid="32" sourcetypename="Light Commercial Truck"/>
    <onroadvehicleselection fueltypeid="1" fueltypedesc="Gasoline" sourcetypeid="32" sourcetypename="Light Commercial Truck"/>
    <onroadvehicleselection fueltypeid="3" fueltypedesc="Compressed Natural Gas (CNG)" sourcetypeid="54" sourcetypename="Motor Home"/>
    <onroadvehicleselection fueltypeid="2" fueltypedesc="Diesel Fuel" sourcetypeid="54" sourcetypename="Motor Home"/>
    <onroadvehicleselection fueltypeid="9" fueltypedesc="Electricity" sourcetypeid="54" sourcetypename="Motor Home"/>
    <onroadvehicleselection fueltypeid="1" fueltypedesc="Gasoline" sourcetypeid="54" sourcetypename="Motor Home"/>
    <onroadvehicleselection fueltypeid="1" fueltypedesc="Gasoline" sourcetypeid="11" sourcetypename="Motorcycle"/>
    <onroadvehicleselection fueltypeid="3" fueltypedesc="Compressed Natural Gas (CNG)" sourcetypeid="41" sourcetypename="Other Buses"/>
    <onroadvehicleselection fueltypeid="2" fueltypedesc="Diesel Fuel" sourcetypeid="41" sourcetypename="Other Buses"/>
    <onroadvehicleselection fueltypeid="9" fueltypedesc="Electricity" sourcetypeid="41" sourcetypename="Other Buses"/>
    <onroadvehicleselection fueltypeid="1" fueltypedesc="Gasoline" sourcetypeid="41" sourcetypename="Other Buses"/>
    <onroadvehicleselection fueltypeid="2" fueltypedesc="Diesel Fuel" sourcetypeid="21" sourcetypename="Passenger Car"/>
    <onroadvehicleselection fueltypeid="9" fueltypedesc="Electricity" sourcetypeid="21" sourcetypename="Passenger Car"/>
    <onroadvehicleselection fueltypeid="5" fueltypedesc="Ethanol (E-85)" sourcetypeid="21" sourcetypename="Passenger Car"/>
    <onroadvehicleselection fueltypeid="1" fueltypedesc="Gasoline" sourcetypeid="21" sourcetypename="Passenger Car"/>
    <onroadvehicleselection fueltypeid="2" fueltypedesc="Diesel Fuel" sourcetypeid="31" sourcetypename="Passenger Truck"/>
    <onroadvehicleselection fueltypeid="9" fueltypedesc="Electricity" sourcetypeid="31" sourcetypename="Passenger Truck"/>
    <onroadvehicleselection fueltypeid="5" fueltypedesc="Ethanol (E-85)" sourcetypeid="31" sourcetypename="Passenger Truck"/>
    <onroadvehicleselection fueltypeid="1" fueltypedesc="Gasoline" sourcetypeid="31" sourcetypename="Passenger Truck"/>
    <onroadvehicleselection fueltypeid="3" fueltypedesc="Compressed Natural Gas (CNG)" sourcetypeid="51" sourcetypename="Refuse Truck"/>
    <onroadvehicleselection fueltypeid="2" fueltypedesc="Diesel Fuel" sourcetypeid="51" sourcetypename="Refuse Truck"/>
    <onroadvehicleselection fueltypeid="9" fueltypedesc="Electricity" sourcetypeid="51" sourcetypename="Refuse Truck"/>
    <onroadvehicleselection fueltypeid="1" fueltypedesc="Gasoline" sourcetypeid="51" sourcetypename="Refuse Truck"/>
    <onroadvehicleselection fueltypeid="3" fueltypedesc="Compressed Natural Gas (CNG)" sourcetypeid="43" sourcetypename="School Bus"/>
    <onroadvehicleselection fueltypeid="2" fueltypedesc="Diesel Fuel" sourcetypeid="43" sourcetypename="School Bus"/>
    <onroadvehicleselection fueltypeid="9" fueltypedesc="Electricity" sourcetypeid="43" sourcetypename="School Bus"/>
    <onroadvehicleselection fueltypeid="1" fueltypedesc="Gasoline" sourcetypeid="43" sourcetypename="School Bus"/>
    <onroadvehicleselection fueltypeid="3" fueltypedesc="Compressed Natural Gas (CNG)" sourcetypeid="53" sourcetypename="Single Unit Long-haul Truck"/>
    <onroadvehicleselection fueltypeid="2" fueltypedesc="Diesel Fuel" sourcetypeid="53" sourcetypename="Single Unit Long-haul Truck"/>
    <onroadvehicleselection fueltypeid="9" fueltypedesc="Electricity" sourcetypeid="53" sourcetypename="Single Unit Long-haul Truck"/>
    <onroadvehicleselection fueltypeid="1" fueltypedesc="Gasoline" sourcetypeid="53" sourcetypename="Single Unit Long-haul Truck"/>
    <onroadvehicleselection fueltypeid="3" fueltypedesc="Compressed Natural Gas (CNG)" sourcetypeid="52" sourcetypename="Single Unit Short-haul Truck"/>
    <onroadvehicleselection fueltypeid="2" fueltypedesc="Diesel Fuel" sourcetypeid="52" sourcetypename="Single Unit Short-haul Truck"/>
    <onroadvehicleselection fueltypeid="9" fueltypedesc="Electricity" sourcetypeid="52" sourcetypename="Single Unit Short-haul Truck"/>
    <onroadvehicleselection fueltypeid="1" fueltypedesc="Gasoline" sourcetypeid="52" sourcetypename="Single Unit Short-haul Truck"/>
    <onroadvehicleselection fueltypeid="3" fueltypedesc="Compressed Natural Gas (CNG)" sourcetypeid="42" sourcetypename="Transit Bus"/>
    <onroadvehicleselection fueltypeid="2" fueltypedesc="Diesel Fuel" sourcetypeid="42" sourcetypename="Transit Bus"/>
    <onroadvehicleselection fueltypeid="9" fueltypedesc="Electricity" sourcetypeid="42" sourcetypename="Transit Bus"/>
    <onroadvehicleselection fueltypeid="1" fueltypedesc="Gasoline" sourcetypeid="42" sourcetypename="Transit Bus"/>
</onroadvehicleselections>'

MRS <- paste(MRS, onroadVehiclesText, sep = '\n')


# ---- road types ----
roadTypesText <-
'<roadtypes>
    <roadtype roadtypeid="1" roadtypename="Off-Network" modelCombination="M1"/>
    <roadtype roadtypeid="2" roadtypename="Rural Restricted Access" modelCombination="M1"/>
    <roadtype roadtypeid="3" roadtypename="Rural Unrestricted Access" modelCombination="M1"/>
    <roadtype roadtypeid="4" roadtypename="Urban Restricted Access" modelCombination="M1"/>
    <roadtype roadtypeid="5" roadtypename="Urban Unrestricted Access" modelCombination="M1"/>
</roadtypes>'

MRS <- paste(MRS, roadTypesText, sep = '\n')


# ---- pollutants and associated processes ----
pollutantsText <-
'<pollutantprocessassociations>
    <pollutantprocessassociation pollutantkey="58" pollutantname="Aluminum" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="58" pollutantname="Aluminum" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="58" pollutantname="Aluminum" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="58" pollutantname="Aluminum" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="58" pollutantname="Aluminum" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="58" pollutantname="Aluminum" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="58" pollutantname="Aluminum" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="36" pollutantname="Ammonium (NH4)" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="36" pollutantname="Ammonium (NH4)" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="36" pollutantname="Ammonium (NH4)" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="36" pollutantname="Ammonium (NH4)" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="36" pollutantname="Ammonium (NH4)" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="36" pollutantname="Ammonium (NH4)" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="36" pollutantname="Ammonium (NH4)" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="90" pollutantname="Atmospheric CO2" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="90" pollutantname="Atmospheric CO2" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="90" pollutantname="Atmospheric CO2" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="90" pollutantname="Atmospheric CO2" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="121" pollutantname="CMAQ5.0 Unspeciated (PMOTHR)" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="121" pollutantname="CMAQ5.0 Unspeciated (PMOTHR)" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="121" pollutantname="CMAQ5.0 Unspeciated (PMOTHR)" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="121" pollutantname="CMAQ5.0 Unspeciated (PMOTHR)" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="121" pollutantname="CMAQ5.0 Unspeciated (PMOTHR)" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="121" pollutantname="CMAQ5.0 Unspeciated (PMOTHR)" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="121" pollutantname="CMAQ5.0 Unspeciated (PMOTHR)" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="98" pollutantname="CO2 Equivalent" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="98" pollutantname="CO2 Equivalent" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="98" pollutantname="CO2 Equivalent" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="98" pollutantname="CO2 Equivalent" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="55" pollutantname="Calcium" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="55" pollutantname="Calcium" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="55" pollutantname="Calcium" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="55" pollutantname="Calcium" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="55" pollutantname="Calcium" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="55" pollutantname="Calcium" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="55" pollutantname="Calcium" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="2" pollutantname="Carbon Monoxide (CO)" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="2" pollutantname="Carbon Monoxide (CO)" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="2" pollutantname="Carbon Monoxide (CO)" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="2" pollutantname="Carbon Monoxide (CO)" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="2" pollutantname="Carbon Monoxide (CO)" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="2" pollutantname="Carbon Monoxide (CO)" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="2" pollutantname="Carbon Monoxide (CO)" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="51" pollutantname="Chloride" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="51" pollutantname="Chloride" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="51" pollutantname="Chloride" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="51" pollutantname="Chloride" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="51" pollutantname="Chloride" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="51" pollutantname="Chloride" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="51" pollutantname="Chloride" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="118" pollutantname="Composite - NonECPM" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="118" pollutantname="Composite - NonECPM" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="118" pollutantname="Composite - NonECPM" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="118" pollutantname="Composite - NonECPM" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="118" pollutantname="Composite - NonECPM" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="118" pollutantname="Composite - NonECPM" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="118" pollutantname="Composite - NonECPM" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="112" pollutantname="Elemental Carbon" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="112" pollutantname="Elemental Carbon" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="112" pollutantname="Elemental Carbon" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="112" pollutantname="Elemental Carbon" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="112" pollutantname="Elemental Carbon" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="112" pollutantname="Elemental Carbon" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="112" pollutantname="Elemental Carbon" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="119" pollutantname="H2O (aerosol)" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="119" pollutantname="H2O (aerosol)" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="119" pollutantname="H2O (aerosol)" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="119" pollutantname="H2O (aerosol)" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="119" pollutantname="H2O (aerosol)" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="119" pollutantname="H2O (aerosol)" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="119" pollutantname="H2O (aerosol)" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="59" pollutantname="Iron" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="59" pollutantname="Iron" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="59" pollutantname="Iron" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="59" pollutantname="Iron" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="59" pollutantname="Iron" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="59" pollutantname="Iron" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="59" pollutantname="Iron" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="54" pollutantname="Magnesium" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="54" pollutantname="Magnesium" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="54" pollutantname="Magnesium" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="54" pollutantname="Magnesium" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="54" pollutantname="Magnesium" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="54" pollutantname="Magnesium" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="54" pollutantname="Magnesium" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="66" pollutantname="Manganese Compounds" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="5" pollutantname="Methane (CH4)" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="5" pollutantname="Methane (CH4)" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="5" pollutantname="Methane (CH4)" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="5" pollutantname="Methane (CH4)" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="5" pollutantname="Methane (CH4)" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="5" pollutantname="Methane (CH4)" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="5" pollutantname="Methane (CH4)" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="35" pollutantname="Nitrate (NO3)" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="35" pollutantname="Nitrate (NO3)" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="35" pollutantname="Nitrate (NO3)" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="35" pollutantname="Nitrate (NO3)" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="35" pollutantname="Nitrate (NO3)" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="35" pollutantname="Nitrate (NO3)" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="35" pollutantname="Nitrate (NO3)" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="6" pollutantname="Nitrous Oxide (N2O)" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="6" pollutantname="Nitrous Oxide (N2O)" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="6" pollutantname="Nitrous Oxide (N2O)" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="6" pollutantname="Nitrous Oxide (N2O)" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="79" pollutantname="Non-Methane Hydrocarbons" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="79" pollutantname="Non-Methane Hydrocarbons" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="79" pollutantname="Non-Methane Hydrocarbons" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="79" pollutantname="Non-Methane Hydrocarbons" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="79" pollutantname="Non-Methane Hydrocarbons" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="79" pollutantname="Non-Methane Hydrocarbons" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="79" pollutantname="Non-Methane Hydrocarbons" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="79" pollutantname="Non-Methane Hydrocarbons" processkey="11" processname="Evap Permeation"/>
    <pollutantprocessassociation pollutantkey="79" pollutantname="Non-Methane Hydrocarbons" processkey="12" processname="Evap Fuel Vapor Venting"/>
    <pollutantprocessassociation pollutantkey="79" pollutantname="Non-Methane Hydrocarbons" processkey="13" processname="Evap Fuel Leaks"/>
    <pollutantprocessassociation pollutantkey="79" pollutantname="Non-Methane Hydrocarbons" processkey="18" processname="Refueling Displacement Vapor Loss"/>
    <pollutantprocessassociation pollutantkey="79" pollutantname="Non-Methane Hydrocarbons" processkey="19" processname="Refueling Spillage Loss"/>
    <pollutantprocessassociation pollutantkey="122" pollutantname="Non-carbon Organic Matter (NCOM)" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="122" pollutantname="Non-carbon Organic Matter (NCOM)" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="122" pollutantname="Non-carbon Organic Matter (NCOM)" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="122" pollutantname="Non-carbon Organic Matter (NCOM)" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="122" pollutantname="Non-carbon Organic Matter (NCOM)" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="122" pollutantname="Non-carbon Organic Matter (NCOM)" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="122" pollutantname="Non-carbon Organic Matter (NCOM)" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="111" pollutantname="Organic Carbon" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="111" pollutantname="Organic Carbon" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="111" pollutantname="Organic Carbon" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="111" pollutantname="Organic Carbon" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="111" pollutantname="Organic Carbon" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="111" pollutantname="Organic Carbon" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="111" pollutantname="Organic Carbon" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="3" pollutantname="Oxides of Nitrogen (NOx)" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="3" pollutantname="Oxides of Nitrogen (NOx)" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="3" pollutantname="Oxides of Nitrogen (NOx)" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="3" pollutantname="Oxides of Nitrogen (NOx)" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="3" pollutantname="Oxides of Nitrogen (NOx)" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="3" pollutantname="Oxides of Nitrogen (NOx)" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="3" pollutantname="Oxides of Nitrogen (NOx)" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="53" pollutantname="Potassium" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="53" pollutantname="Potassium" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="53" pollutantname="Potassium" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="53" pollutantname="Potassium" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="53" pollutantname="Potassium" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="53" pollutantname="Potassium" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="53" pollutantname="Potassium" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="100" pollutantname="Primary Exhaust PM10  - Total" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="100" pollutantname="Primary Exhaust PM10  - Total" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="100" pollutantname="Primary Exhaust PM10  - Total" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="100" pollutantname="Primary Exhaust PM10  - Total" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="100" pollutantname="Primary Exhaust PM10  - Total" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="100" pollutantname="Primary Exhaust PM10  - Total" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="100" pollutantname="Primary Exhaust PM10  - Total" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="110" pollutantname="Primary Exhaust PM2.5 - Total" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="110" pollutantname="Primary Exhaust PM2.5 - Total" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="110" pollutantname="Primary Exhaust PM2.5 - Total" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="110" pollutantname="Primary Exhaust PM2.5 - Total" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="110" pollutantname="Primary Exhaust PM2.5 - Total" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="110" pollutantname="Primary Exhaust PM2.5 - Total" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="110" pollutantname="Primary Exhaust PM2.5 - Total" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="106" pollutantname="Primary PM10 - Brakewear Particulate" processkey="9" processname="Brakewear"/>
    <pollutantprocessassociation pollutantkey="107" pollutantname="Primary PM10 - Tirewear Particulate" processkey="10" processname="Tirewear"/>
    <pollutantprocessassociation pollutantkey="116" pollutantname="Primary PM2.5 - Brakewear Particulate" processkey="9" processname="Brakewear"/>
    <pollutantprocessassociation pollutantkey="117" pollutantname="Primary PM2.5 - Tirewear Particulate" processkey="10" processname="Tirewear"/>
    <pollutantprocessassociation pollutantkey="124" pollutantname="Residual PM (NonECNonSO4NonOM)" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="124" pollutantname="Residual PM (NonECNonSO4NonOM)" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="124" pollutantname="Residual PM (NonECNonSO4NonOM)" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="124" pollutantname="Residual PM (NonECNonSO4NonOM)" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="124" pollutantname="Residual PM (NonECNonSO4NonOM)" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="124" pollutantname="Residual PM (NonECNonSO4NonOM)" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="124" pollutantname="Residual PM (NonECNonSO4NonOM)" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="57" pollutantname="Silicon" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="57" pollutantname="Silicon" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="57" pollutantname="Silicon" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="57" pollutantname="Silicon" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="57" pollutantname="Silicon" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="57" pollutantname="Silicon" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="57" pollutantname="Silicon" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="52" pollutantname="Sodium" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="52" pollutantname="Sodium" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="52" pollutantname="Sodium" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="52" pollutantname="Sodium" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="52" pollutantname="Sodium" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="52" pollutantname="Sodium" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="52" pollutantname="Sodium" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="115" pollutantname="Sulfate Particulate" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="115" pollutantname="Sulfate Particulate" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="115" pollutantname="Sulfate Particulate" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="115" pollutantname="Sulfate Particulate" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="115" pollutantname="Sulfate Particulate" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="115" pollutantname="Sulfate Particulate" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="115" pollutantname="Sulfate Particulate" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="56" pollutantname="Titanium" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="56" pollutantname="Titanium" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="56" pollutantname="Titanium" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="56" pollutantname="Titanium" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="56" pollutantname="Titanium" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="56" pollutantname="Titanium" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="56" pollutantname="Titanium" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="91" pollutantname="Total Energy Consumption" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="91" pollutantname="Total Energy Consumption" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="91" pollutantname="Total Energy Consumption" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="91" pollutantname="Total Energy Consumption" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="1" pollutantname="Total Gaseous Hydrocarbons" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="1" pollutantname="Total Gaseous Hydrocarbons" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="1" pollutantname="Total Gaseous Hydrocarbons" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="1" pollutantname="Total Gaseous Hydrocarbons" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="1" pollutantname="Total Gaseous Hydrocarbons" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="1" pollutantname="Total Gaseous Hydrocarbons" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="1" pollutantname="Total Gaseous Hydrocarbons" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="1" pollutantname="Total Gaseous Hydrocarbons" processkey="11" processname="Evap Permeation"/>
    <pollutantprocessassociation pollutantkey="1" pollutantname="Total Gaseous Hydrocarbons" processkey="12" processname="Evap Fuel Vapor Venting"/>
    <pollutantprocessassociation pollutantkey="1" pollutantname="Total Gaseous Hydrocarbons" processkey="13" processname="Evap Fuel Leaks"/>
    <pollutantprocessassociation pollutantkey="1" pollutantname="Total Gaseous Hydrocarbons" processkey="18" processname="Refueling Displacement Vapor Loss"/>
    <pollutantprocessassociation pollutantkey="1" pollutantname="Total Gaseous Hydrocarbons" processkey="19" processname="Refueling Spillage Loss"/>
    <pollutantprocessassociation pollutantkey="123" pollutantname="Total Organic Matter (TOM)" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="123" pollutantname="Total Organic Matter (TOM)" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="123" pollutantname="Total Organic Matter (TOM)" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="123" pollutantname="Total Organic Matter (TOM)" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="123" pollutantname="Total Organic Matter (TOM)" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="123" pollutantname="Total Organic Matter (TOM)" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="123" pollutantname="Total Organic Matter (TOM)" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="87" pollutantname="Volatile Organic Compounds" processkey="1" processname="Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="87" pollutantname="Volatile Organic Compounds" processkey="15" processname="Crankcase Running Exhaust"/>
    <pollutantprocessassociation pollutantkey="87" pollutantname="Volatile Organic Compounds" processkey="2" processname="Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="87" pollutantname="Volatile Organic Compounds" processkey="16" processname="Crankcase Start Exhaust"/>
    <pollutantprocessassociation pollutantkey="87" pollutantname="Volatile Organic Compounds" processkey="90" processname="Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="87" pollutantname="Volatile Organic Compounds" processkey="17" processname="Crankcase Extended Idle Exhaust"/>
    <pollutantprocessassociation pollutantkey="87" pollutantname="Volatile Organic Compounds" processkey="91" processname="Auxiliary Power Exhaust"/>
    <pollutantprocessassociation pollutantkey="87" pollutantname="Volatile Organic Compounds" processkey="11" processname="Evap Permeation"/>
    <pollutantprocessassociation pollutantkey="87" pollutantname="Volatile Organic Compounds" processkey="12" processname="Evap Fuel Vapor Venting"/>
    <pollutantprocessassociation pollutantkey="87" pollutantname="Volatile Organic Compounds" processkey="13" processname="Evap Fuel Leaks"/>
    <pollutantprocessassociation pollutantkey="87" pollutantname="Volatile Organic Compounds" processkey="18" processname="Refueling Displacement Vapor Loss"/>
    <pollutantprocessassociation pollutantkey="87" pollutantname="Volatile Organic Compounds" processkey="19" processname="Refueling Spillage Loss"/>
</pollutantprocessassociations>'

MRS <- paste(MRS, pollutantsText, sep = '\n')

# ---- output ----
outputDetailsText <- paste0(
'<geographicoutputdetail description="COUNTY"/>
<outputemissionsbreakdownselection>
    <modelyear selected="', outputByModelYear, '"/>
    <fueltype selected="', outputByFuelType, '"/>
    <fuelsubtype selected="', outputByFuelSubtype, '"/>
    <emissionprocess selected="', outputByEmissionProcess, '"/>
    <onroadoffroad selected="false"/>
    <roadtype selected="', outputByRoadType, '"/>
    <sourceusetype selected="', outputBySourceUseType, '"/>
    <movesvehicletype selected="false"/>
    <onroadscc selected="false"/>
    <estimateuncertainty selected="false" numberOfIterations="2" keepSampledData="false" keepIterations="false"/>
    <sector selected="false"/>
    <engtechid selected="false"/>
    <hpclass selected="false"/>
    <regclassid selected="false"/>
</outputemissionsbreakdownselection>
<outputdatabase servername="" databasename="', outputDatabaseName, '" description=""/>
<outputtimestep value="24-Hour Day"/>
<outputvmtdata value="true"/>
<outputsho value="true"/>
<outputsh value="true"/>
<outputshp value="true"/>
<outputshidling value="true"/>
<outputstarts value="true"/>
<outputpopulation value="true"/>
<scaleinputdatabase servername="localhost" databasename="', inputDatabaseName, '" description=""/>
<pmsize value="0"/>
<outputfactors>
    <timefactors selected="true" units="Days"/>
    <distancefactors selected="true" units="Miles"/>
    <massfactors selected="true" units="Kilograms" energyunits="Joules"/>
</outputfactors>
<savedata>

</savedata>

<donotexecute>

</donotexecute>

<generatordatabase shouldsave="false" servername="" databasename="" description=""/>
<donotperformfinalaggregation selected="false"/>
<lookuptableflags scenarioid="" truncateoutput="true" truncateactivity="true" truncatebaserates="true"/>
<skipdomaindatabasevalidation selected="false"/>'
)

MRS <- paste(MRS, outputDetailsText, '</runspec>\n', sep = '\n')

writeLines(MRS, con = outputMRSfilepath)