# Wearables Data

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
#         gsutil -m cp -r "gs://dci-wellness-study" "/Users/lauragraham/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared drives/Secure: DCI Research/Analysis_Graham/Wearables Data"
#         /Users/laurag/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared Drives/Secure: DCI Research/Analysis_Graham/Wearables Data/Data Downloads
#         - May also require: % gcloud auth login
#     2. Data will be downloaded to active folder.  Transfer it to the following Gdrive folder.
#         "~/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared drives/Secure: DCI Research/Analysis_Graham/Wearables Data/Data Downloads/dci-wellness-study/"


# # list.dirs (alternate) function set up
# list.dirs_full <- function(parent=".")   # recursively find directories
# {
#   if (length(parent)>1)           # work on first and then rest
#     return(c(list.dirs(parent[1]), list.dirs(parent[-1])))
#   else {                          # length(parent) == 1
#     if (!is.dir(parent))
#       return(NULL)            # not a directory, don't return anything
#     child <- list.files(parent, full=TRUE)
#     if (!any(is.dir(child)))
#       return(parent)          # no directories below, return parent
#     else 
#       return(list.dirs(child))    # recurse
#   }
# }
# 
# is.dir <- function(x)    # helper function
# {
#   ret <- file.info(x)$isdir
#   ret[is.na(ret)] <- FALSE
#   ret
# }

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

################################## Sleep Data Analysis ##############################################
  
# Pull Current Data for All Participants
  ids <- list.dirs(data.path)
  ids <- ids[!str_detect(ids,pattern="transformed")]
  # Sleep data
    ds <- data.frame()
    Metric <- "sl"
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
        data <- files %>% lapply(read_csv, show_col_types = FALSE) 
        data <- keep(data, ~nrow(.) > 0) %>% plyr::rbind.fill()
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
      # 284,877 rows
      head(ds)
      tbl_summary(data=ds, include=c("Device", "Type", "Value", "Start_Date", "End_Time"))
    
  # Drop variables with everything missing
    drops <- c("MyPHD-Login-Key-ID","MyPHD-ID-on-study-bucket", "Tag")
    ds <- ds[ , !(names(ds) %in% drops)]
    
    ds <- ds[order(ds$ID, ds$Start_Date, ds$End_Date, ds$Start_Time, ds$End_Time),]
    
  # Clean device name issues?
    unique(ds$Device)[4] == "HK Apple Watch"
    unique(ds$Device)[6] == "HK Apple Watch"
    ds$Device <- ifelse(ds$Device == "HK Apple Watch","HK Apple Watch", ds$Device )
      table(ds$Device)
    
  # Number of Unique Observations
      nrow(ds)
      
  # Data Structure
      head(ds, 1000)
      hist(ds$Value)
      
  # Device Types
      ds$Type <- tolower(ds$Type)
      table(ds$Device, ds$Type)
      
  # Person-Device Level
      devices <- ds %>% select("ID", "Device") %>% distinct()
        table(devices$Device)
      
      devices2 <- reshape2::dcast(devices, ID ~ Device)
      
      table(devices2$Fitbit)
      table(devices2$`HK Apple Watch`)
      table(devices2$`HK Connect`)
      table(devices2$`HK iPhone`)
      table(devices2$`HK Oura`)
      table(devices2$`HK WHOOP`)
      
     # For data checks
     # head(subset(ds, Device == "HK Oura" & Type == "core"))
     # ck2 <- subset(ds, ID == "a52ur1539645522398245" & as.Date((Start_Date)) == "2028-11-23")
      
      
      ck <- subset(ds, Device == "Fitbit")
      
    
########################## Merge in ID Crosswalk ############################################
      
  # Crosswalk
    ds2 <- merge(DCI_Wellness, ds, by="ID")
    
  # Shifting Times
    ds2$Start_dt <- with(ds2, ymd(Start_Date-Shift) + hms(Start_Time)) 
    ds2$End_dt <- with(ds2, ymd(End_Date-Shift) + hms(End_Time))
      # Checks
        min(ds2$Start_dt, na.rm=T)
        max(ds2$Start_dt, na.rm=T)
    # Missing some start/end times
      table(is.na(ds2$Start_dt))
      table(is.na(ds2$End_dt))
    
    # Correcting dates
      # Mis-coded End Dates
        ds2$Start_dt <- as.POSIXct(ds2$Start_dt, tz="UTC")
        ds2$End_dt <- as.POSIXct(ds2$End_dt, tz="UTC")
      # End dates before Start Dates
        ck <- subset(ds2, End_dt < Start_dt)
          nrow(ck)
        # Shift end dates up 1 day
          ds2$End_dt <- ifelse(ds2$End_dt < ds2$Start_dt & !is.na(ds2$End_dt) & !is.na(ds2$Start_dt), 
                               ds2$End_dt+days(1), 
                               ds2$End_dt)
          ds2$Start_dt <- as.POSIXct(ds2$Start_dt, tz="UTC")
          ds2$End_dt <- as.POSIXct(ds2$End_dt, tz="UTC")
            ck <- subset(ds2, End_dt < Start_dt)
            nrow(ck)

      # Missing End Dates (Fitbit)
        ds2$End_dt2 <- as.POSIXct(ds2$Start_dt+ds2$Value)
        ds2$End_dt <- pmax(ds2$End_dt, ds2$End_dt2, na.rm=T)
        ck <- subset(ds2, is.na(End_dt))
          nrow(ck)
          table(ck$Device)
          hist(ck$Value)
        # All fitbit missing type - considered data errors
    
    # Sorting and Cleaning
      ds3 <- ds2[order(ds2$ID, ds2$Start_dt, ds2$End_dt),]
      ds3 <- ds3[,c("ID", "Device", "Value", "Type", "Start_dt", "End_dt")]
      
    # Subset to Sleep Intervals
    ds3 <- subset(ds3, Type %in% c("asleep", "deep", "light", "rem", "core"))
    
    # Delete intervals with missing dates
        table(is.na(ds3$Start_dt))
        table(is.na(ds3$End_dt))
        ds3 <- subset(ds3, !is.na(Start_dt) & !is.na(End_dt))
        
    # Limit to sleep times after 7pm and before 7am
        ds3 <- subset(ds3, hour(Start_dt) <= 7 | hour(Start_dt) >= 19)
        table(hour(ds3$Start_dt))
        
    # Delete Sleeping Intervals longer than 12 hours
        obs1 <- nrow(ds3)
        ds3 <- subset(ds3, (ds3$End_dt - ds3$Start_dt) < (60*60*12))
        # Obs removed
          obs1 - nrow(ds3)  # 687
   
# A number of devices tag intervals with multiple types. The following codes centers to intervals that include any potential sleep values
        
  # Identifying Overlapping intervals and summarize to the interval
    library(dplyr)
    library(ivs)
    ds4 <- ds3 %>% mutate(interval = iv(ds3$Start_dt, ds3$End_dt))
      head(ds4)
      
    # Combine Overlapping Intervals
      ds4 <- ds4 %>%
        group_by(ID) %>%
        mutate(interval_group = iv_identify_group(interval)) %>%
        select(ID, Device, interval_group) %>% distinct()
      head(ds4)
    
      ds4$sl_asleep <- as.numeric(iv_end(ds4$interval_group) - iv_start(ds4$interval_group))/60/60
      hist(ds4$sl_asleep)
       
      # Summarize to the start day
      ds5 <- ds4
       # Fitbit does not code full periods so take the min/max for the day to calculate sleep time
       ds5$date <- as.Date(iv_start(ds5$interval_group)- hour(7))
       daily <- ds5 %>%
         dplyr::group_by(ID, date) %>%
         dplyr::summarize(sleep_hr = sum(sl_asleep),
                          Start = min(iv_start(interval_group)), 
                          End = min(iv_end(interval_group)), 
                          n = length(sl_asleep)) %>%
         ungroup()
  
    # Checking calculated sleep time
       hist(daily$sleep_hr)
       ck <- subset(daily, sleep_hr < 1)
        nrow(ck)
       ck <- subset(daily, sleep_hr > 10)
        nrow(ck)
       ck2 <- subset(ds2, ID == "a52ur1779337362839295" & as.Date((Start_dt)) == "2024-06-08")[ ,c("ID", "Start_dt", "End_dt", "Device", "Type", "Value", "Metric")]
       ck2 <- subset(ds5, ID == "a52ur1779337362839295" & as.Date(iv_start(interval_group)) == "2024-05-29")
       ck2 <- subset(daily, ID == "a52ur1779337362839295" & date == "2024-05-29")
     
 # Alternative method: Identify bookends
   # Subset to Sleep Intervals
     ds5a <- ds5a[order(ds5a$ID, ds5a$Start_dt, ds5a$End_dt),]
     ds5a <- ds5a[,c("ID", "Device", "Value", "Type", "Start_dt", "End_dt")]
     ds5a <- subset(ds5a, Type %in% c("asleep", "deep", "light", "rem", "core"))
     
   # Delete intervals with missing dates
     ds5a <- subset(ds5a, !is.na(Start_dt) & !is.na(End_dt))
     
   # Identify earliest start and latest end for a sleep value
     ds5a$sl_start <- ifelse(hour(ds5a$Start_dt)>=19, 1, 0)
     ds5a$sl_end <- ifelse(hour(ds5a$Start_dt)<=7, 1, 0)
     ds5a$date <- as.Date(ds5a$Start_dt)
     sl_start <- subset(ds5a, sl_start ==1) %>% group_by(ID, date) %>% summarise(sl_start = min(Start_dt))
     sl_end <- subset(ds5a, sl_end ==1) %>% group_by(ID, date) %>% summarise(sl_end = max(End_dt))
     sl_end$date <- sl_end$date-day(1)
     
    # Update daily
     ds5b <- merge(sl_start, sl_end, by=c("ID", "date"), all.x=T, all.y=T)
     
     daily2 <- merge(daily, ds5b, by=c("ID", "date"), all.x=T, all.y=T)
     daily2$sleep_hr2 <- difftime(daily2$sl_end, daily2$sl_start, units = "hours")
     ck <- subset(daily2, sleep_hr < 1)
      hist(as.numeric(ck$sleep_hr2))
     hist(daily2$sleep_hr)
     hist(as.numeric(daily2$sleep_hr2))
     
     summary(daily2$sleep_hr)
     summary(as.numeric(daily2$sleep_hr2))
     
# Impute bookend time for calculated sleep times <4 hour or >12 hours
    daily2$sleep_hr3 <- daily2$sleep_hr
    daily2$sleep_hr3 <- ifelse(daily2$sleep_hr < 4, daily2$sleep_hr2,
                               ifelse(daily2$sleep_hr > 12, daily2$sleep_hr2, daily2$sleep_hr3))
    hist(daily2$sleep_hr3)
    summary(daily2$sleep_hr3)
     
   summary(as.numeric(daily2$sleep_hr2)-daily2$sleep_hr)
     
     
     
        
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
        daily2 <- merge(daily2, device, by=c("ID", "date"))
          head(daily)
    
    # Pre-Post Determinimation
    daily$Pre.Post <- ifelse(daily$date < as.Date('2024-09-15'), "Pre", "Post")
    daily$Pre.Post <- factor(daily$Pre.Post, levels=c("Pre", "Post"))
      table(daily$Pre.Post)
    daily$Times <- ifelse(daily$date < as.Date('2024-05-16'), "1. May 15 or earlier",
                          ifelse(daily$date <= as.Date('2024-06-28'), "2. Pre Intro to DCI (06/28/2024)",
                                 ifelse(daily$date <= as.Date('2024-08-01'), "3. Pre Virtual Orientation (08/01/2024)",
                                        ifelse(daily$date < as.Date('2024-09-15'), "4. Pre In-Person Orientation (09/15/2024)", "5. Post DCI Orientation"))))
      table(daily$Times)
  
      # Day light savings incorporate?
      
      
      
      
      
      
      
      
      
      
# Save Permanent
    save(daily, file = "~/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared drives/Secure: DCI Research/Analysis_Graham/Wearables Data/HR Data.RData")

# Load Current HR Data
  load("~/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared drives/Secure: DCI Research/Analysis_Graham/Wearables Data/HR Data.RData")
  
  # Preliminary Analyses
    # Exclude dates prior to May 16, 2024)
      daily2 <- subset(daily, date > as.Date("2024-05-16"))
        table(daily2$Pre.Post)
        
    # Merge in demographics from survey data
       daily2 <- merge(daily2, Demo, by = "ID")
      
    # Initial Table
      tbl_summary(data = daily2, include=Total_MVPA, 
                  type = all_continuous() ~ "continuous2",
                  statistic = all_continuous() ~ c(
                    "{mean} ({sd})",
                    "{median} ({p25}, {p75})",
                    "{min}, {max}"
                  ),
                  digits = all_continuous() ~ 0,
                  label = Total_MVPA ~ "Minutes of Moderate to Vigorous Activity per Day"
                  )
      
      # Distribution
      mu <- plyr::ddply(daily2, "Pre.Post", summarise, grp.mean=mean(Total_MVPA))
      ggplot(daily2, aes(x = Total_MVPA, y = ..density..)) +
        geom_histogram(fill = "cornsilk", colour = "grey60", size = .2) +
        geom_density(colour = "red") + theme_bw() +  
        geom_vline(data=mu, aes(xintercept=grp.mean, color=Pre.Post),
                   linetype="dashed", color = "grey60") +
        ggtitle("Average Daily Step Counts Across All Time for Participants")+
        labs(title="MVPA Minutes (Overall)", x = "MVPA Minutes", y = "Density")
     
      # Plotting Change in MVPA Minutes Over Time
      ggplot(daily2, aes(x = date, y = Total_MVPA)) + 
        geom_point(colour = "grey60", size = .5) +
        geom_smooth(colour = "red") + 
        labs(title="MVPA Minutes (By Time Period)", x = "MVPA Minutes", y = "Density")+
        theme_bw()
      
      # Distribution of Steps by Time Period
      mu <- plyr::ddply(daily2, "Pre.Post", summarise, grp.mean=mean(Total_MVPA))
      ggplot(daily2, aes(x=Total_MVPA, color=Pre.Post, fill=Pre.Post)) +
        geom_histogram(aes(y=..density..), position="identity", alpha=0.2, size = .2)+
        geom_density(alpha=0) +
        geom_vline(data=mu, aes(xintercept=grp.mean, color=Pre.Post),
                   linetype="dashed")+
        scale_color_manual(values=c("#E69F00", "#999999"))+
        scale_fill_manual(values=c("#E69F00", "#999999"))+
        labs(title="MVPA Minutes (By Time Period)", x = "MVPA Minutes", y = "Density")+
        theme_bw()
      
      # Table
        tbl_continuous(data=daily2, variable = Total_MVPA, include = c("Pre.Post", "Times",
                                                                        "HK Apple Watch", "Fitbit", "HK Oura", "HK WHOOP", "HK Apple Watch", "HK Connect", 
                                                                        "HK omron connect", "HK Peloton")) 
        tbl_continuous(data=daily2, variable = Total_MVPA, include = c("gender", "education", "Usborn",
                                                                        "married", "children_living2", "selfemployed",
                                                                        "rate_health")) |> add_p()
        
      # ANOVA - Note need to include repeated effect
        library(lme4)
        summary(lm(data = daily2, Total_MVPA ~ Pre.Post))
        summary(lm(data = daily2, Total_MVPA ~ Pre.Post + Age + gender + rate_health + Usborn +
                     UCLA_Loneliness3 + Ryff_Purpose))
        summary(lm(data = daily2, Total_MVPA ~ Times + Age + gender + rate_health + Usborn +
                     UCLA_Loneliness3 + Ryff_Purpose))
        
        tbl_regression(lm(data = daily2, Total_MVPA ~ Pre.Post)) |> add_glance_source_note() |>
        as_gt() |> gt::tab_source_note(gt::md("*Data as of November 18, 2024*"))
        
        tbl_regression(lm(data = daily2, Total_MVPA ~ Times)) |> add_glance_source_note() |>
          as_gt() |> gt::tab_source_note(gt::md("*Data as of November 18, 2024*"))
        
        tbl_regression(lm(data = daily2, Total_MVPA ~ Times + gender + Age + rate_health)) |> add_glance_source_note() |>
          as_gt() |> gt::tab_source_note(gt::md("*Data as of November 18, 2024*"))
        
      # Difference in Effect by Gender
        summary(lm(data = subset(daily2, gender == "Male"), Total_MVPA ~ Pre.Post))
        summary(lm(data = subset(daily2, gender == "Female"), Total_MVPA ~ Pre.Post))
        summary(lm(data = daily2, Total_MVPA ~ Pre.Post*gender))
        
        tbl_continuous(subset(daily2, gender == "Female"), variable = Total_MVPA, 
                       include = "Pre.Post",
                       statistic = ~"{mean} ({sd})") |> add_p()
        tbl_continuous(subset(daily2, gender == "Male"), variable = Total_MVPA, 
                       include = "Pre.Post",
                       statistic = ~"{mean} ({sd})") |> add_p()
        
        # Diff-in-diff Plot
          plot_data <- daily2[complete.cases(daily2$rate_health), ] %>%
          # Make these categories instead of 0/1 numbers so they look nicer in the plot
          mutate(rate_health = factor(rate_health),
                 Pre.Post = factor(Pre.Post, labels = c("Before DCI", "After DCI"))) %>%
          group_by(rate_health, Pre.Post) %>%
          summarize(Avg_Steps = mean(Total_MVPA, na.rm=T),
                    se = sd(Total_MVPA, na.rm=T) / sqrt(n()),
                    upper = Avg_Steps + (1.96 * se),
                    lower = Avg_Steps + (-1.96 * se))
      
        # Plot
        ggplot(plot_data, aes(x = Pre.Post, y = Avg_Steps, color = rate_health)) +
          geom_pointrange(aes(ymin = lower, ymax = upper), size = 1) +
          geom_line(aes(group = rate_health)) +
          theme_bw() + 
          labs(title="Interaction of Health and Time", y = "MVPA Minutes", x = "")
        
        # Model
        tbl_regression(lm(data = daily2, Total_MVPA ~ gender:Pre.Post)) |> add_glance_source_note() |>
          as_gt() |> gt::tab_source_note(gt::md("*Data as of November 18, 2024*"))
        tbl_regression(lm(data = daily2, Total_MVPA ~ gender:Pre.Post + Age + rate_health)) |> add_glance_source_note() |>
          as_gt() |> gt::tab_source_note(gt::md("*Data as of November 18, 2024*"))
        
        # Nonlinear relationship with age
          ggplot(daily2, aes(x=Age, y=Total_MVPA)) + geom_smooth()
        
          hist(daily2$Age)
          
        
        
        
        
        
        
        
        
      
################# OLD CODE ##############################

folders <- dir(dir)
for (folder in folders){
  print(folder)
  path <- paste("~/Downloads/dci-wellness-study/",list.dirs("~/Downloads/dci-wellness-study/")[1],"/",folder,"/", sep="")
  setwd(path)
  # Get list of files in patient-metric folder
  files <- dir(path, pattern = "*.csv")
  # Merge all files in patient-metric folder to create a patient-metric file
  data <- files %>% lapply(read_csv) %>% plyr::rbind.fill()
  if(nrow(data) == 0){
    print(".... No Data Available")
  }else{
    data$Metric <- folder
    ds <- plyr::rbind.fill(ds, data)
  }
}





# Initial Test Data Pull for patient metric
  # Patient folder
  list.dirs("~/Downloads/dci-wellness-study/")
  dir <- paste("~/Downloads/dci-wellness-study/",list.dirs("~/Downloads/dci-wellness-study/")[1],"/", sep="")
  # Patient-metric folder
  dir(dir)
  length(dir(dir))
  path <- paste("~/Downloads/dci-wellness-study/",list.dirs("~/Downloads/dci-wellness-study/")[1],"/",dir(dir)[4],"/", sep="")
  setwd(path)
  # Get list of files in patient-metric folder
  files <- dir(path, pattern = "*.csv")
  # Merge all files in patient-metric folder to create a patient-metric file
  data <- files %>% map_dfr(read_csv)
  
  hist(data$Value)
  
  # Preliminary Analyses
  daily <- data %>%
    dplyr::group_by(Start_Date) %>%
    dplyr::summarize(Total_MVPA = sum(Value)) %>%
    mutate(date = floor_date(Start_Date-2142)) 
  
  weekly_avg <- daily %>%
    mutate(Week = week(date)) %>%
    dplyr::group_by(Week) %>%
    dplyr::summarize(Avg_Daily_Steps = mean(Total_MVPA), date = min(date)) 
  
  summary(weekly_avg)
  summary(daily)
  
  ggplot(data=weekly_avg, aes(x=date, y=Avg_Daily_Steps)) + geom_smooth()
  ggplot(data=daily, aes(x=date, y=Total_MVPA)) + geom_smooth()
  
  
# Expanded data retrieval and merge
  # Needs
    # List of patient folder names (Will loop through)
    # List of patient-metric folders per patient (should be in the patient folder loop because patient-metric folders change)
  
 
  dir <- paste("~/Downloads/dci-wellness-study/",list.dirs("~/Downloads/dci-wellness-study/")[1],"/", sep="")
  ds <- data.frame()
  folders <- dir(dir)
  for (folder in folders){
    print(folder)
    path <- paste("~/Downloads/dci-wellness-study/",list.dirs("~/Downloads/dci-wellness-study/")[1],"/",folder,"/", sep="")
    setwd(path)
    # Get list of files in patient-metric folder
    files <- dir(path, pattern = "*.csv")
    # Merge all files in patient-metric folder to create a patient-metric file
    data <- files %>% lapply(read_csv) %>% plyr::rbind.fill()
    if(nrow(data) == 0){
      print(".... No Data Available")
    }else{
      data$Metric <- folder
      ds <- plyr::rbind.fill(ds, data)
    }
  }
  
table(ds$Metric)

summary(ds$Start_Date)
  
  
  
  plyr::rb
  
  function(data,folder) {
    if(nrow(data) == 0){
      return(print("No Data Available: ",folder))
    } else { 
      data$Metric <- folder
      ds <- bind_rows(ds, data)
      return(ds)
    }
  }
  
  
  
  
  list.files(path = "C:/Users...", pattern = "*.csv", full.names = TRUE) %>% lapply(read_csv)  %>% plyr::rbind.fill
  
  
  
  
  
    files <- list.dirs("~/Downloads/dci-wellness-study/")
    # Ignore Transformed folder (Daily Data)
   files <- files[!str_detect(files,pattern="transformed")]
    length(files)
    
    
    
    
    
  # Drop Paths with no Files
    # Identify Files to Delete
   num.csv <- NULL
     for (path in files) {
        path <- gsub("/Users/laurag", "~", path)
        path <- gsub("//", "/", path)
        num.csv <- append(num.csv, length(dir(path, pattern = "*.csv")))
     }
   files2 <- cbind(as.data.frame(files), as.data.frame(num.csv))
   files2 <- subset(files2, num.csv > 0)
   # Update with Only Folders that have CSVs
   files <- files2$files
   
# Looped Data Pull
  # Code needs to loop through all folders and subfolders
        # Test Case
        path <- "~/Downloads/dci-wellness-study/a52ur1539645522398245/hrvbeattobeat"
        setwd(path)
        options(readr.show_col_types = FALSE)
          df <- list.files(path) |>
            set_names() |>
            map_dfr(read_delim, .id = "file")
          file2 <- as.data.frame(strsplit(df$file, "-"))
          file2 <- t(file2)
          df2 <- cbind(df, file2[,2:3])
          df2 <- df2[,c(1:7,10,11)]
          names(df2)[names(df2) == "1"] <- "ID"
          names(df2)[names(df2) == "2"] <- "Measure"
          row.names(df2) <- NULL
 
    
    for (path in files[2:4]) {
      path <- gsub("/Users/laurag", "~", path)
      path <- gsub("//", "/", path)
      print(path)
      
    }
    
          
# DEBUGGING
    df_total = data.frame()
    for (path in files[2:4]) {
      path <- gsub("/Users/laurag", "~", path)
      path <- gsub("//", "/", path)
      setwd(path)
      df <- list.files(path) |>
        set_names() |>
        map_dfr(read_delim, .id = "file")
      file2 <- as.data.frame(strsplit(df$file, "-"))
      file2 <- t(file2)
      df2 <- cbind(df, file2[,2:3])
      df2 <- df2[,c(1:7,10,11)]
      names(df2)[names(df2) == "1"] <- "ID"
      names(df2)[names(df2) == "2"] <- "Measure"
      row.names(df2) <- NULL
      df_total <- rbind(df_total,df2)
    }
    
    table(df_total$Device, df_total$Measure)
    
    
    
    

