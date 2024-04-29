import os
import sys
import openpyxl
import pandas as pd

def main(excel_file, out_dir, scen_year):

    # read csv output files and process them to the right format for excel spredsheets
    vmt_df = pd.read_csv(os.path.join(out_dir, "output_annualVMTbySrcType.csv"))
    roadtype_df = pd.read_csv(os.path.join(out_dir, "output_roadTypeDistribution.csv"))
    vht_df = pd.read_csv(os.path.join(out_dir, "output_VHTbySpeedBin.csv"))
    
    vmt_df['yearID'] = scen_year
    vmt_df = vmt_df.rename(columns={'VehType': 'HPMSVtypeID', 'AnnualVMT': 'HPMSBaseYearVMT'})
    vmt_df = vmt_df[['HPMSVtypeID', 'yearID', 'HPMSBaseYearVMT']]

    excel_sheets_mapping = [
        (vmt_df, 'HPMSannualVMT'),
        (roadtype_df, 'roadTypeDistribution'),
        (vht_df, 'speedDistribution')
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
    output_directory = args[2]
    scenario_year = int(args[3])
    
    main(moves_excel_spreadsheet, output_directory, scenario_year)
