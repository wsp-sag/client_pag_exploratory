import openpyxl
import csv
import os
import pandas as pd
from pandas import ExcelWriter
import sys

if __name__ == "__main__":

    args = sys.argv

    moves_spreadsheet_file_name = args[1]  
    data_directory = args[2]
    YEAR = args[3]

    # read csv output files and process them to the right format for excel spredsheets
    vmt_df = pd.read_csv(os.path.join(data_directory, "output_annualVMTbySrcType.csv"))
    roadtype_df = pd.read_csv(os.path.join(data_directory, "output_roadTypeDistribution.csv"))
    vht_df = pd.read_csv(os.path.join(data_directory, "output_VHTbySpeedBin.csv"))

    vmt_df['yearID'] = YEAR
    vmt_df = vmt_df.rename(columns={'VehType': 'HPMSVtypeID', 'AnnualVMT': 'HPMSBaseYearVMT'})
    vmt_df = vmt_df[['HPMSVtypeID', 'yearID', 'HPMSBaseYearVMT']]

    csv_sheets_mapping = [
        (vmt_df, 'HPMSannualVMT'),
        (roadtype_df, 'roadTypeDistribution'),
        (vht_df, 'speedDistribution')
    ]

    #delete the spredsheet contents first and then copy the data from processed dataframes to corresponding excel files
    book = openpyxl.load_workbook(os.path.join(data_directory, moves_spreadsheet_file_name))
    writer = pd.ExcelWriter(os.path.join(data_directory, moves_spreadsheet_file_name), engine='openpyxl')

    for worksheets in csv_sheets_mapping:
        ws_name = worksheets[1]
        ws = book[ws_name]
        ws.delete_rows(1, ws.max_row)
        
    for dataframe, sheets in csv_sheets_mapping:
        writer.book = book
        writer.sheets = {ws.title: ws for ws in book.worksheets}
        dataframe.to_excel(writer, sheets, index = False, header= True)

    writer.save()