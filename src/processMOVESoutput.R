# Load required libraries
library(tidyverse)
library(DBI)
library(RMySQL)

parameters <- read_lines('C:/Users/ryanh/Desktop/MOVES4_control/parameters.txt', skip_empty_rows = T)
outputDatabaseName <- parameters[10]
emissionsOutputCSVfilepath <- parameters[16]

# Database connection parameters
db_host <- "127.0.0.1"
db_port <- 3306  # Change if your MariaDB server uses a different port
db_user <- "root"
db_password <- "MOVES"
db_name <- outputDatabaseName

# Establish a connection to the MariaDB database
con <- dbConnect(RMySQL::MySQL(), 
                 host = db_host, 
                 port = db_port,
                 user = db_user, 
                 password = db_password, 
                 dbname = db_name)

# Check if the connection is successful
if (dbIsValid(con)) {
  cat("Connected to the database.\n")
  
  # Your SQL query
  # sql_query <- "SELECT * FROM `2030_moves4_test03_out_20231206`.`movesoutput`;"
  sql_query <- paste0('SELECT * FROM ', db_name, '.movesoutput where pollutantID in (2, 3, 87, 98, 100, 106, 107, 110, 116, 117);')
  
  # Execute the query and fetch the results into a dataframe
  result_df <- dbGetQuery(con, sql_query)
  
  # select important columns
  result_df <- result_df %>% select(yearID, monthID, dayID, pollutantID, sourceTypeID, emissionQuant)
  
  # write output to CSV or whichever format is best to then import into Power BI
  write.table(result_df, emissionsOutputCSVfilepath, sep = ',', row.names = FALSE)
  
  # Print the dataframe
  # print(result_df)
  
  # Close the database connection
  dbDisconnect(con)
  cat("Connection closed.\n")
} else {
  cat("Unable to connect to the database.\n")
}
