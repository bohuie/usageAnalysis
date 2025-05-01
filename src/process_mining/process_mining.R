library(lubridate)
library(dplyr)
library(remotes)
library(DiagrammeR)
library(pMineR)
library(readr)

# Load the CSV files
myDF <- read.csv("input.csv", stringsAsFactors = FALSE, sep = ",", quote = "\"")
filterDF <- read.csv("filter.csv", stringsAsFactors = FALSE)
gradesDF <- read.csv("grades.csv", stringsAsFactors = FALSE)

# Clean the date format
myDF$time_created <- ymd_hms(gsub("T", " ", myDF$time_created)) 

# Ensure columns have correct types
myDF$actor <- as.character(myDF$actor)
myDF$description <- as.character(myDF$description)
myDF$time_created <- as.character(myDF$time_created)
filterDF$user <- as.character(filterDF$user)
gradesDF$actor_id <- as.character(gradesDF$actor_id)

# Only keep student who consented and is in the grade.csv
# valid_users <- filterDF %>%
#   filter(consent == TRUE, is_student == TRUE, user %in% gradesDF$actor_id) %>%
#   pull(user)

# myDF <- myDF[myDF$actor %in% valid_users, ]

# Keep all students
valid_users_all <- filterDF %>%
  filter(is_student == TRUE) %>%
  pull(user)

myDF <- myDF[myDF$actor %in% valid_users_all, ]

# Define action code mapping
action_code_mapping <- list(
  "Submission was evaluated" = "submission_evaluated",
  "User added goal item" = "add_goal_item",
  "User clicked on next question" = "clicked_next_question",
  "User consented." = "consented",
  "User removed their consent." = "removed_consent",
  "User created a goal item." = "created_goal_item",
  "User created a goal." = "created_goal",
  "User created a new report." = "created_report",
  "User created a team." = "created_team",
  "User created an event." = "created_event",
  "User deleted a question." = "deleted_question",
  "User imported an event." = "imported_event",
  "User joined a team." = "joined_team",
  "User logged in" = "logged_in",
  "User requested a password reset email." = "requested_password_reset",
  "User reset their password." = "reset_password",
  "User selected a category on the concept map" = "selected_category",
  "User selected assignments and exams on the course homepage" = "selected_assignments",
  "User selected challenges on the course homepage" = "selected_challenges",
  "User selected leaderboard on the course homepage" = "selected_leaderboard",
  "User selected practice on the course homepage" = "selected_practice_from_concept_map",
  "User started practice from goal" = "started_practice_from_goal",
  "User submitted a solution" = "submitted_solution",
  "User updated a question." = "updated_question",
  "User updated an event." = "updated_event",
  "User updated their profile." = "updated_profile",
  "User used recommended goal" = "used_recommended_goal",
  "User viewed personal ranking and tokens earned on the course leader board" = "viewed_personal_ranking",
  "User viewed team ranking and tokens earned on a challenge leader board" = "viewed_team_ranking"
)

# Apply action code mapping
myDF$action_code <- sapply(myDF$description, function(desc) {
  if (!is.null(action_code_mapping[[desc]])) {
    return(action_code_mapping[[desc]])
  } else {
    return(NA)
  }
})
myDF$action_code[is.na(myDF$action_code)] <- "UNKNOWN"

# Remove rows where action_code is NULL or NA
myDF <- myDF[!(is.na(myDF$action_code) | myDF$action_code == "NULL"), ]

# Remove all rows where action_code is "submission_evaluated"
# "submission_evaluated" is a system auto-generated action that occurs after question submission
myDF <- myDF[myDF$action_code != "submission_evaluated", ]

# Sort dataset by user and time
myDF <- myDF[order(myDF$actor, myDF$time_created), ]

# Initialize columns
myDF$srl_subcategory <- NA
myDF$srl_code <- NA

# Define SRL mapping for single actions
srl_mapping <- list(
  "created_goal" = list("sub_category" = "Goal Setting & Planning", "code" = "MC.P"),
  "add_goal_item" = list("sub_category" = "Goal Setting & Planning", "code" = "MC.P"),
  "created_report" = list("sub_category" = "Evaluation & Reflection", "code" = "MC.E"),
  "used_recommended_goal" = list("sub_category" = "Implementation", "code" = "C.I"),
  "viewed_personal_ranking" = list("sub_category" = "Social & Engagement", "code" = "M.S"),
  "viewed_team_ranking" = list("sub_category" = "Social & Engagement", "code" = "M.S"),
  "created_team" = list("sub_category" = "Social & Engagement", "code" = "M.S"),
  "joined_team" = list("sub_category" = "Social & Engagement", "code" = "M.S"),
  "selected_assignments" = list("sub_category" = "Orientation", "code" = "P.O"),
  "selected_challenges" = list("sub_category" = "Orientation", "code" = "P.O"),
  "selected_leaderboard" = list("sub_category" = "Orientation", "code" = "P.O"),
  "selected_practice_from_goal" = list("sub_category" = "Orientation", "code" = "P.O"),
  "clicked_next_question" = list("sub_category" = "Orientation", "code" = "P.O"),
  "selected_category" = list("sub_category" = "Orientation", "code" = "P.O"),
  "selected_practice_from_concept_map" = list("sub_category" = "Orientation", "code" = "P.O"),
  "requested_password_reset" = list("sub_category" = "Setup, Technical & Account Management", "code" = "P.T&M"),
  "updated_profile" = list("sub_category" = "Setup, Technical & Account Management", "code" = "P.T&M"),
  "created_goal_item" = list("sub_category" = "Goal Setting & Planning", "code" = "MC.P"),
  "logged_in" = list("sub_category" = "Begin", "code" = "Begin"),
  "reset_password" = list("sub_category" = "Setup, Technical & Account Management", "code" = "P.T&M"),
  "started_practice_from_goal" = list("sub_category" = "Goal Setting & Planning", "code" = "MC.P")
)

# Remove irrelevant actions cannot performed by students
myDF <- myDF[!myDF$action_code %in% c(
  "consented", "created_event", "deleted_question", "imported_event",
  "removed_consent", "updated_event", "updated_question"
), ]

# Track previous attempts per user-question pair
previous_attempts <- list()
for (i in 1:nrow(myDF)) {
  user <- myDF$actor[i]
  question <- myDF$question_id[i]
  status <- myDF$question_status[i]
  attempt <- myDF$nth_attempt[i]
  action <- myDF$action_code[i]  # Use action_code instead of description
  
  # Handle submitted_solution classification
  if (action == "submitted_solution") {
    
    if (is.null(previous_attempts[[user]]) || !question %in% names(previous_attempts[[user]])) {
      previous_attempts[[user]][[question]] <- list()
    }
    
    if (attempt == 1) {
      myDF$srl_subcategory[i] <- "Initial Attempt & Retry"
      myDF$srl_code[i] <- "C.A"
      
    } else if (!"Correct" %in% previous_attempts[[user]][[question]]) {
      myDF$srl_subcategory[i] <- "Evaluation & Reflection"
      myDF$srl_code[i] <- "MC.E"
      
    } else {
      myDF$srl_subcategory[i] <- "Revisiting & Reviewing"
      myDF$srl_code[i] <- "C.R"
    }
    
    previous_attempts[[user]][[question]] <- c(previous_attempts[[user]][[question]], status)
    
  } else if (action %in% names(srl_mapping)) {
    # Assign SRL classification for single-action events
    myDF$srl_subcategory[i] <- srl_mapping[[action]]$sub_category
    myDF$srl_code[i] <- srl_mapping[[action]]$code
  }
}

# Merge full grades into myDF
myDF <- merge(myDF, gradesDF, by.x = "actor", by.y = "actor_id", all.x = TRUE)

# Split by session, current time gap is set to 60 minutes
myDF <- myDF %>%
  arrange(actor, time_created) %>%
  group_by(actor) %>%
  mutate(
    prev_date = lag(time_created),
    prev_day = lag(as.Date(time_created)),
    curr_day = as.Date(time_created),
    gap_min = as.numeric(difftime(time_created, lag(time_created), units = "mins")),
    new_day = curr_day != prev_day,
    new_session_day_rule = ifelse(new_day & gap_min > 60, TRUE, FALSE),
    new_session_gap_rule = ifelse(!new_day & gap_min > 60, TRUE, FALSE),
    is_first = is.na(prev_date),
    new_session_flag = ifelse(is_first | new_session_day_rule | new_session_gap_rule, 1, 0),
    session_index = cumsum(new_session_flag),
    session_id = paste0(actor, "_S", session_index)
  ) %>%
  ungroup() %>%
  select(-prev_date, -prev_day, -curr_day, -gap_min, -new_day, 
         -new_session_day_rule, -new_session_gap_rule, -is_first, -new_session_flag, -session_index)

# write.csv(myDF, "output.csv", row.names = FALSE)
# cat("Output data saved to 'output.csv'\n")

write.csv(myDF, "output_all_students.csv", row.names = FALSE)
cat("Output including all students saved to 'output_all_students.csv'\n")


# Make a working copy of myDF
filteredDF <- myDF

# USER CONFIGURATION

# Filter by a specific person
# NULL by default to include all students
filter_actor_id <- NULL           # e.g., "100"
filter_student_id <- NULL         # e.g., "12345678"

# Filter by grade range
# NULL by default to include all grade range
grade_item <- NULL          # Options: "mid_1", "mid_2", "final_exam", "lab", "final_score", or NULL
min_score <- NULL                 # Minimum percentage
max_score <- NULL                  # Maximum percentage

# Define grade columns
grade_cols <- c("mid_1", "mid_2", "final_exam", "lab", "final_score")

# Data Cleaning

filteredDF <- filteredDF %>%
  mutate(across(all_of(grade_cols), ~ trimws(.))) %>%
  mutate(across(all_of(grade_cols), ~ na_if(., ""))) %>%
  mutate(across(all_of(grade_cols), ~ na_if(., "null"))) %>%
  mutate(across(all_of(grade_cols), ~ suppressWarnings(as.numeric(gsub("%", "", .)) / 100)))

# Data Filtering

# Person-based filtering
if (!is.null(filter_actor_id)) {
  if (!(filter_actor_id %in% filteredDF$actor)) stop("Actor ID not found.")
  filteredDF <- filteredDF %>% filter(actor == filter_actor_id)
}

if (!is.null(filter_student_id)) {
  if (!(filter_student_id %in% filteredDF$student_number)) stop("Student ID not found.")
  filteredDF <- filteredDF %>% filter(student_number == filter_student_id)
}

# Grade-based filtering
if (!is.null(grade_item)) {
  if (!(grade_item %in% grade_cols)) stop("Invalid grade item selected.")
  min_val <- min_score / 100
  max_val <- max_score / 100
  filteredDF <- filteredDF %>%
    filter(get(grade_item) >= min_val & get(grade_item) <= max_val)
}

# Filtered Output

if (nrow(filteredDF) == 0) {
  stop("No matching rows found for the given filters.")
}

write_csv(filteredDF, "filtered_output.csv")
cat("Filtered data saved to 'filtered_output.csv'\n")

# Load filtered_output.csv and plot Markov Model
filteredDF <- read_csv("filtered_output.csv", show_col_types = FALSE)
filteredDF$time_created <- ymd_hms(filteredDF$time_created)
filteredDF <- filteredDF %>%
  filter(!is.na(srl_subcategory), srl_subcategory != "Begin")

markov_input <- filteredDF %>%
  select(session_id, time_created, srl_subcategory) %>%
  rename(
    CaseID = session_id,
    Timestamp = time_created,
    Event = srl_subcategory
  ) %>%
  as.data.frame()

# create a data loader
data_loader <- dataLoader(verbose.mode = FALSE)

# load data frame into the data loader
data_loader$load.data.frame(
  mydata = markov_input,
  IDName = "CaseID",
  EVENTName = "Event",
  dateColumnName = "Timestamp",
  format.column.date = "%Y-%m-%d %H:%M:%S"
)

# train the first-order Markov model
markov_model <- firstOrderMarkovModel(verbose.mode = FALSE)
markov_model$loadDataset(dataList = data_loader$getData())
markov_model$trainModel()

# plot
grViz(markov_model$plot(giveItBack = TRUE))

