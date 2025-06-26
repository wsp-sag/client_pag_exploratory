import os
import sys
import openpyxl
import pandas as pd

def main(excel_file, moves_input_dir, out_dir, scen_year):

    # read csv output files and process them to the right format for excel spredsheets
    vmt_df = pd.read_csv(os.path.join(out_dir, "output_annualVMTbySrcType.csv"))
    roadtype_df = pd.read_csv(os.path.join(out_dir, "output_roadTypeDistribution.csv"))
    vht_df = pd.read_csv(os.path.join(out_dir, "output_VHTbySpeedBin.csv"))
    
    vmt_df['yearID'] = scen_year
    vmt_df = vmt_df.rename(columns={'VehType': 'HPMSVtypeID', 'AnnualVMT': 'HPMSBaseYearVMT'})
    vmt_df = vmt_df[['HPMSVtypeID', 'yearID', 'HPMSBaseYearVMT']]

    # read yearly MOVES inputs
    age_distribution_df = pd.read_csv(os.path.join(moves_input_dir,  "ageDistribution_" + str(scen_year) + ".csv"))
    avft_df = pd.read_csv(os.path.join(moves_input_dir,  "avft_" + str(scen_year) + ".csv"))
    sourceTypePopulation_df = pd.read_csv(os.path.join(moves_input_dir,  "sourceTypePopulation_" + str(scen_year) + ".csv"))
    fuel_supply_df = pd.read_csv(os.path.join(moves_input_dir,  "fuel_MOVES4defaultPimaCounty" + str(scen_year) + ".csv"))
    fuel_formation_df = pd.read_csv(os.path.join(moves_input_dir,  "fuel_MOVES4defaultPimaCounty" + str(scen_year) + "_FuelFormulation.csv"))
    fuel_usage_df = pd.read_csv(os.path.join(moves_input_dir,  "fuel_MOVES4defaultPimaCounty" + str(scen_year) + "_FuelUsageFraction.csv"))
    inspection_maintenance_df = pd.read_csv(os.path.join(moves_input_dir,  "inspectionMaintenance_MOVES4defaultPimaCounty" + str(scen_year) + ".csv"))

    excel_sheets_mapping = [
        (vmt_df, 'HPMSannualVMT'),
        (roadtype_df, 'roadTypeDistribution'),
        (vht_df, 'speedDistribution'),
        (age_distribution_df, 'ageDistribution'),
        (avft_df, 'avft'),
        (sourceTypePopulation_df, 'sourceTypePopulation'),
        (fuel_supply_df, 'fuelSupply'),
        (fuel_formation_df, 'fuelFormulation'),
        (fuel_usage_df, 'fuelUsageFraction'),
        (inspection_maintenance_df, 'inspectionMaintenance')        
    ]

    workbook = openpyxl.load_workbook(excel_file)
    
    for data_df, sheet_name in excel_sheets_mapping:
        worksheet = workbook[sheet_name]
        
        # delete existing data
        worksheet.delete_rows(worksheet.min_row, worksheet.max_row)

        data = [data_df.columns.tolist()] + data_df.values.tolist()

        # write new data
        for row in data:
            worksheet.append(row)
        
    workbook.save(excel_file)

if __name__ == "__main__":

    args = sys.argv
    print(args)
    
    moves_excel_spreadsheet = args[1]  
    moves_input_path = args[2]
    output_directory = args[3]
    scenario_year = int(args[4])
    
    main(moves_excel_spreadsheet, moves_input_path, output_directory, scenario_year)
