# MVPA Data

library(purrr)
library(tidyverse)
library(jsonlite)
library(ggplot2)
library(dplyr)
library(tidyquant)
library(procs)
library(gtsummary)

# Prior to analyses
#     1. Update file in Terminal
#         gsutil -m cp -r "gs://dci-wellness-study" "/Users/lauragraham/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared drives/Secure: DCI Research/Analysis_Graham/Wearables Data/Data Downloads"
#         /Users/laurag/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared Drives/Secure: DCI Research/Analysis_Graham/Wearables Data/Data Downloads
#         - May also require: % gcloud auth login

# list.dirs function
list.dirs <- function(path=".", pattern=NULL, all.dirs=FALSE,
                      full.names=FALSE, ignore.case=FALSE) {
  # use full.names=TRUE to pass to file.info
  all <- list.files(path, pattern, all.dirs,
                    full.names=TRUE, recursive=FALSE, ignore.case)
  dirs <- all[file.info(all)$isdir]
  # determine whether to return full names or just dir names
  if(isTRUE(full.names))
    return(dirs)
  else
    return(basename(dirs))
}

# DCI IDs
  DCI_Wellness <- read_csv("~/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared drives/Secure: DCI Research/Analysis_Graham/Wearables Data/DCI_Wellness.txt")
  DCI_Wellness$ID <- DCI_Wellness$`MyPHD-ID-on-study-bucket`

# Demographics
  library(readxl)
  Demo <- read_excel("~/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared drives/Secure: DCI Research/Analysis_Graham/Wearables Data/2024 Master List.xlsx", 
                                  sheet = "Master")

# Identify IDs in Metrics data
  data.path <- "~/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared drives/Secure: DCI Research/Analysis_Graham/Wearables Data/Data Downloads/dci-wellness-study/"
  ids <- list.dirs(data.path)
  length(ids)
    # 11/18/2024: n=34 participants
    # 5/1/2025:   n=35 participants

  # Use this code to determine the types of metrics for each id
      ids <- ids[!str_detect(ids,pattern="transformed")]
         for (id in ids){
             dir <- paste(data.path,id,"/", sep="")
             print(id)
             print(dir(dir))
           }
    
      ids <- ids[!str_detect(ids,pattern="transformed")]
      M <- NULL
      for (id in ids){
          dir <- paste(data.path,id,"/", sep="")
          M <- c(M, as.vector(dir(dir)))
      }
      sort(table(M),decreasing=T)

    
  # Confirmed all IDS have "st" for steps
  # Nearly all of "hr" and "sl"
  # Heart Rate Variability: heartvar (hrv is the coverage for heartvar)

################################## Heart Rate Analysis ##############################################
  
# Pull Current Data for All Participants
  ids <- list.dirs(data.path)
  ids <- ids[!str_detect(ids,pattern="transformed")]
  # heartvar
    ds <- data.frame()
    Metric <- "hr"
    for (id in ids){
      path <- paste(data.path,id,paste("/",Metric,"/", sep=""), sep="")
      print(id)
      skip_to_next <- FALSE
      # Skip if metric is not available for that ID
        tryCatch(setwd(path), error = function(e) { skip_to_next <<- TRUE})
        if(skip_to_next) { next }   
      # Get list of files in patient-metric folder
        files <- dir(path, pattern = "*.csv")
      # Merge all files in patient-metric folder to create a patient-metric file
        data <- files %>% lapply(read_csv, show_col_types = FALSE) %>% plyr::rbind.fill()
        if(nrow(data) == 0){
          print(".... No Data Available")
        }else{
          data$ID <- id
          data$Metric <- Metric
          ds <- plyr::rbind.fill(ds, data)
        }
    }
  
  # Remove duplicate records
    ds <- distinct(ds)
    
  # Drop variables with everything missing
    summary(ds)
    drops <- c("MyPHD-Login-Key-ID","MyPHD-ID-on-study-bucket", "End_Date", "End_Time", "Tag", "Type")
    ds <- ds[ , !(names(ds) %in% drops)]
    
  # Number of Unique Observations
      nrow(ds)
      
  # Data Structure
      head(ds, 1000)
      hist(ds$Value)
      
  # Device Types
      table(ds$Device)
    
# Calculate Daily Activity Levels    
  # Merge in ID Crosswalk
    ds <- merge(DCI_Wellness, ds, by="ID")
    ds <- ds %>% mutate(date = floor_date(Start_Date-Shift)) 
    ds$datetime <- as.POSIXct(paste(ds$date, ds$Start_Time), format="%Y-%m-%d %H:%M:%S")
    
  # Merge in age from survey data
    ds2 <- merge(ds, Demo[,c("ID","Age")], by = "ID")
  # Calculate MVPA
    ds2$MHR <- 207-(ds2$Age*0.7)
    ds2$MVPA <- ifelse(ds2$Value >= ds2$MHR*0.5 & ds2$Value < ds2$MHR*0.7, "Moderate",
                       ifelse(ds2$Value >= ds2$MHR*0.7 & ds2$Value < ds2$MHR*0.85, "Vigorous", ""))
      prop.table(table(ds2$MVPA))
    ds2 <- ds2[order(ds2$ID, ds2$datetime),]
  
  # Summarize to the Day 
    # Calculate Time Since and Time to
    daily <-  ds2 %>%
          arrange(ID, datetime) %>%
          group_by(ID) %>%
          mutate(time_next = as.numeric(abs(datetime - lead(datetime)), units = 'mins'),
                 time_since = as.numeric(abs(datetime - lag(datetime)), units = 'mins'))
      summary(daily$time_next)
      
      rm(ds2) # Clearing space for analyses
      
        # Nearly all measures are 10-15 seconds apart
        # Exclude intervals longer than 1 minute
        daily <- subset(daily, time_next <= 1)
          hist(daily$time_next)
          summary(daily$time_next)
    # Summarize to the day
    daily <- daily %>%
        group_by(ID, date, MVPA) %>%
        dplyr::summarize(mvpa_time = round(sum(time_next),2))
        # Clean out values that summed to greater than a day (1440 minutes)
        daily$mvpa_time <- ifelse(daily$mvpa_time > 24*60, 24*60, daily$mvpa_time)
           hist(daily$mvpa_time)
    # Transpose by Activity Level
           daily <- subset(daily, daily$MVPA !="") %>% 
        pivot_wider(id_cols = c("ID", "date"), names_from = MVPA, values_from = mvpa_time)
      # Data Cleaning (Allows for 16 hours max of moderate activity in a day or 4 hours max of vigorous activity)
      # Data rules were based off of visual inspection
           daily$Moderate <- ifelse(daily$Moderate > 16*60, 16*60, daily$Moderate)
           daily$Vigorous <- ifelse(daily$Vigorous > 4*60, 4*60, daily$Vigorous)
        hist(daily$Moderate)
        hist(daily$Vigorous)
    # Calculate Total MVPA
        daily$Total_MVPA <- rowSums(daily[,c("Moderate", "Vigorous")], na.rm=TRUE)
        hist(daily$Total_MVPA)
        ggplot(daily, aes(x=date)) + 
          geom_smooth(aes(y=Vigorous), color="red")+ 
          geom_smooth(aes(y=Moderate), color="blue")
        
    # Include 0's for dates with no activity recorded?
        # Participants
        participant <- daily |>
          group_by(ID) |>
          summarize(Avg_MVPAmin = mean(Total_MVPA, na.rm=T), start_date = min(date), last_date = max(date)) 
        participant <- merge(participant, Demo[,c("ID","First","Last")], by="ID", all.x=TRUE)
        participant <- participant[order(participant$last_date),]
       
        # Participant-Day
        participant.day <- participant |>
          group_by(ID) |> 
          summarize(date=seq(start_date, last_date, by="1 day"))
        # daily <- merge(participant.day, daily, by=c("ID", "date"), all.x=TRUE)
        # Decided not to because 0's appear to be true missing, instead add baseline HR to identify days with any assessment
      
    # Add Baseline HR
        daily.hr <- ds %>%
          dplyr::group_by(ID, date) %>%
          dplyr::summarize(HR_Avg = round(mean(Value, na.rm=T),2),
                           HR_Max = round(max(Value, na.rm=T),2),
                           HR_n = length(Value)) 
        daily <- merge(daily.hr, daily, by=c("ID", "date"), all.x=TRUE)
          daily$Moderate <- ifelse(is.na(daily$Moderate), 0, daily$Moderate)
          daily$Vigorous <- ifelse(is.na(daily$Vigorous), 0, daily$Vigorous)
  
    # Add device type
      device <- ds[,c("ID", "Start_Date", "Device")]
        device <- distinct(device)
        device$Value <- 1
        device <- proc_transpose(device, by=c("ID", "Start_Date"), var="Value", id="Device")
        device[is.na(device)] <- 0
        device <- device[,c(-3)]
        device <- merge(DCI_Wellness, device, by="ID")
        device <- device %>% mutate(date = floor_date(Start_Date-Shift)) 
        device <- device[,-c(2:5)]
        daily <- merge(daily, device, by=c("ID", "date"))
          head(daily)
      
    # Outliers?
      summary(daily$Total_MVPA)
      quantile(daily$Total_MVPA, c(.95, .99), na.rm=T)
      
    # Save data
      daily_mvpa <- daily
      save(daily_mvpa, file = "~/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared drives/Secure: DCI Research/Analysis_Graham/Wearables Data/Daily_MVPA.RData")
      
      max(daily_mvpa$date)
      
          
 
    

