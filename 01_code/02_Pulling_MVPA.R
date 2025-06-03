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
        # Nearly all measures are 10-15 seconds apart
        # Exclude intervals longer than 1 minute
        daily <- subset(daily, daily$time_next < 1)
          hist(daily$time_next)
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
    
    
    
    

