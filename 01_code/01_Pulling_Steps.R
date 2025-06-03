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

  # Use this code to determine the types of metrics for each id
    ids <- ids[!str_detect(ids,pattern="transformed")]
      for (id in ids){
        dir <- paste(data.path,id,"/", sep="")
        print(id)
        print(dir(dir))
      }
    
  # Confirmed all IDS have "st" for steps
  # Nearly all of "hr" and "sl"
  # Heart Rate Variability: hrv heartvar

################################## Step Counts Analysis ##############################################
  
# Pull Current Data for All Participants
  ids <- list.dirs(data.path)
  ids <- ids[!str_detect(ids,pattern="transformed")]
  ds <- data.frame()
  for (id in ids){
    print(id)
    path <- paste(data.path,id,"/st/", sep="")
    setwd(path)
    # Get list of files in patient-metric folder
    files <- dir(path, pattern = "*.csv")
    # Merge all files in patient-metric folder to create a patient-metric file
    data <- files %>% lapply(read_csv, show_col_types = FALSE) %>% plyr::rbind.fill()
    if(nrow(data) == 0){
      print(".... No Data Available")
    }else{
      data$ID <- id
      data$Metric <- "Steps"
      ds <- plyr::rbind.fill(ds, data)
    }
  }
  summary(ds)
  
  # Remove duplicate records
    ds <- distinct(ds)
      nrow(ds)
      
  # Device Types
    table(ds$Device)
 
  # Summarize to the day level
    daily <- ds %>%
      dplyr::group_by(ID, Start_Date) %>%
      dplyr::summarize(Total_Steps = sum(Value)) 
    # Merge in ID Crosswalk
      daily <- merge(DCI_Wellness, daily, by="ID")
      daily <- daily %>% mutate(date = floor_date(Start_Date-Shift)) 
      # Participants
        participant.list <- daily %>%
          dplyr::group_by(ID, `MyPHD-Login-Key-ID`) %>%
          dplyr::summarize(Avg_Daily_Steps = mean(Total_Steps), start_date = min(date), last_date = max(date)) %>%
          arrange(last_date)
        
        # subset(participant.list, ID == "a52ur6675354398284676")
        
    # Limit to daily steps by day
      daily <- daily[,c(1,7,6)]
      
    # Add device type
      device <- ds[,c(9,1,2)]
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
    
  # Summarize to the week level
    weekly_avg <- daily %>%
      mutate(Week = week(date)) %>%
      dplyr::group_by(ID, Week) %>%
      dplyr::summarize(Avg_Daily_Steps = mean(Total_Steps), date = min(date)) 
    
  # Outliers?
      nrow(subset(daily, Total_Steps > 50000))
      ck <- subset(daily, Total_Steps > 50000)

  # Participant level with day daily
    participant <- daily %>%
      dplyr::group_by(ID) %>%
      dplyr::summarize(Avg_Daily_Steps = mean(Total_Steps), start_date = min(date), last_date = max(date)) 
  
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
      
      
# Save data
    daily_steps <- daily
    save(daily_steps, file = "~/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared drives/Secure: DCI Research/Analysis_Graham/Wearables Data/Daily_Steps.RData")

    
    
    
    
    
    
    
    
# Load Current Step Data
    load("~/Library/CloudStorage/GoogleDrive-lagraham@stanford.edu/Shared drives/Secure: DCI Research/Analysis_Graham/Wearables Data/Step Data.RData")
    names(daily)
    
    
  # Preliminary Analyses
    # Exclude dates prior to May 16, 2024)
      daily2 <- subset(daily, date > as.Date("2024-05-16"))
        table(daily2$Pre.Post)
        
    # Merge in demographics from survey data
       daily2 <- merge(daily2, Demo, by = "ID")
      
    # Initial Table
      tbl_summary(data = daily2, include=Total_Steps, 
                  type = all_continuous() ~ "continuous2",
                  statistic = all_continuous() ~ c(
                    "{mean} ({sd})",
                    "{median} ({p25}, {p75})",
                    "{min}, {max}"
                  ),
                  digits = all_continuous() ~ 0,
                  label = Total_Steps ~ "Daily Steps"
                  )
      
      # Distribution of Steps
      mu <- plyr::ddply(daily2, "Pre.Post", summarise, grp.mean=mean(Total_Steps))
      ggplot(daily2, aes(x = Total_Steps, y = ..density..)) +
        geom_histogram(fill = "cornsilk", colour = "grey60", size = .2) +
        geom_density(colour = "red") + theme_bw() +  
        geom_vline(data=mu, aes(xintercept=grp.mean, color=Pre.Post),
                   linetype="dashed", color = "grey60") +
        ggtitle("Average Daily Step Counts Across All Time for Participants")+
        labs(title="Daily Steps (Overall)", x = "Average Daily Steps", y = "Density")
     
      # Plotting Change in Daily Steps Over Time
      ggplot(daily2, aes(x = date, y = Total_Steps)) + 
        geom_point(colour = "grey60", size = .5) +
        geom_smooth(colour = "red") + 
        labs(title="Daily Steps (By Time Period)", x = "Average Daily Steps", y = "Density")+
        theme_bw()
      
      # Distribution of Steps by Time Period
      mu <- plyr::ddply(daily2, "Pre.Post", summarise, grp.mean=mean(Total_Steps))
      ggplot(daily2, aes(x=Total_Steps, color=Pre.Post, fill=Pre.Post)) +
        geom_histogram(aes(y=..density..), position="identity", alpha=0.2, size = .2)+
        geom_density(alpha=0) +
        geom_vline(data=mu, aes(xintercept=grp.mean, color=Pre.Post),
                   linetype="dashed")+
        scale_color_manual(values=c("#E69F00", "#999999"))+
        scale_fill_manual(values=c("#E69F00", "#999999"))+
        labs(title="Daily Steps (By Time Period)", x = "Average Daily Steps", y = "Density")+
        theme_bw()
      
      # Table
        tbl_continuous(data=daily2, variable = Total_Steps, include = names(daily2)[c(10, 11, 4:9)]) 
        
        tbl_continuous(data=daily2, variable = Total_Steps, include = c("gender", "education", "Usborn",
                                                                        "married", "children_living2", "selfemployed",
                                                                        "rate_health")) |> add_p()
        
      # ANOVA - Note need to include repeated effect
        library(lme4)
        summary(lm(data = daily2, Total_Steps ~ Pre.Post))
        summary(lm(data = daily2, Total_Steps ~ Times + Age + gender + rate_health + Usborn +
                     UCLA_Loneliness3 + Ryff_Purpose))
        
        tbl_regression(lm(data = daily2, Total_Steps ~ Pre.Post)) |> add_glance_source_note() |>
        as_gt() |> gt::tab_source_note(gt::md("*Data as of November 18, 2024*"))
        
        tbl_regression(lm(data = daily2, Total_Steps ~ Times)) |> add_glance_source_note() |>
          as_gt() |> gt::tab_source_note(gt::md("*Data as of November 18, 2024*"))
        
        tbl_regression(lm(data = daily2, Total_Steps ~ Times + gender + Age + rate_health)) |> add_glance_source_note() |>
          as_gt() |> gt::tab_source_note(gt::md("*Data as of November 18, 2024*"))
        
      # Difference in Effect by Gender
        summary(lm(data = subset(daily2, gender == "Male"), Total_Steps ~ Pre.Post))
        summary(lm(data = subset(daily2, gender == "Female"), Total_Steps ~ Pre.Post))
        summary(lm(data = daily2, Total_Steps ~ Pre.Post*gender))
        
        tbl_continuous(subset(daily2, gender == "Female"), variable = Total_Steps, 
                       include = "Pre.Post",
                       statistic = ~"{mean} ({sd})") |> add_p()
        tbl_continuous(subset(daily2, gender == "Male"), variable = Total_Steps, 
                       include = "Pre.Post",
                       statistic = ~"{mean} ({sd})") |> add_p()
        
        # Diff-in-diff Plot
          plot_data <- daily2[complete.cases(daily2$gender), ] %>%
          # Make these categories instead of 0/1 numbers so they look nicer in the plot
          mutate(gender = factor(gender, labels = c("Female", "Male")),
                 Pre.Post = factor(Pre.Post, labels = c("Before DCI", "After DCI"))) %>%
          group_by(gender, Pre.Post) %>%
          summarize(Avg_Steps = mean(Total_Steps),
                    se = sd(Total_Steps) / sqrt(n()),
                    upper = Avg_Steps + (1.96 * se),
                    lower = Avg_Steps + (-1.96 * se))
      
        # Plot
        ggplot(plot_data, aes(x = Pre.Post, y = Avg_Steps, color = gender)) +
          geom_pointrange(aes(ymin = lower, ymax = upper), size = 1) +
          geom_line(aes(group = gender)) +
          theme_bw() + 
          labs(title="Interaction of Gender and Time", y = "Average Daily Steps", x = "")
        
        # Model
        tbl_regression(lm(data = daily2, Total_Steps ~ gender:Pre.Post)) |> add_glance_source_note() |>
          as_gt() |> gt::tab_source_note(gt::md("*Data as of November 18, 2024*"))
        tbl_regression(lm(data = daily2, Total_Steps ~ gender:Pre.Post + Age + rate_health + `HK Apple Watch` +
            Fitbit + `HK Oura` + `HK WHOOP` + `HK Apple Watch` + `HK Connect` +
              `HK omron connect` + `HK Peloton`)) |> add_glance_source_note() |>
          as_gt() |> gt::tab_source_note(gt::md("*Data as of November 18, 2024*"))
        
        # Nonlinear relationship with age
          ggplot(daily2, aes(x=Age, y=Total_Steps)) + geom_smooth()
        
          hist(daily2$Age)
          
          daily2$F
          
          ck <- distinct(daily2[complete.cases(daily2$Fitbit), c("ID", "Fitbit", "HK Oura")] )
            table(ck$`HK Oura`)
          # Weighted for device type?
        
        
        
        
        
        
        
        