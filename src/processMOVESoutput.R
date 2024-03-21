# Load required libraries
list.of.packages <- c("broom", "tidyverse", "DBI", "RMySQL")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos = "http://cran.us.r-project.org", dependencies = TRUE)
library(tidyverse)
library(DBI)
library(RMySQL)

parameters <- read_lines('config/parameters.txt', skip_empty_rows = T)
SENARIO_NAME <- parameters[6]
outputDatabaseName <- paste0(parameters[2], "_moves4_out_", SENARIO_NAME)
emissionsOutputCSVfilepath <- paste0(dirname(getwd()), "/data/interim/", parameters[10])
database_password <- parameters[12]

# Database connection parameters
db_host <- "127.0.0.1"
db_port <- 3306  # Change if your MariaDB server uses a different port
db_user <- "root"
db_password <- database_password
db_name <- outputDatabaseName
print(db_password)
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
