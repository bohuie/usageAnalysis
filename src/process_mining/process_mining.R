library(lubridate)
library(dplyr)
library(remotes)
library(DiagrammeR)
library(pMineR)
library(readr)

# Load the CSV files
myDF <- read.csv("data/new_input.csv", stringsAsFactors = FALSE, sep = ",", quote = "\"")
filterDF <- read.csv("data/filter.csv", stringsAsFactors = FALSE)
gradesDF <- read.csv("data/grades.csv", stringsAsFactors = FALSE)

# Clean the date format
myDF$time_created <- ymd_hms(gsub("T", " ", myDF$time_created))

# Ensure columns have correct types
myDF$actor <- as.character(myDF$actor)
myDF$description <- as.character(myDF$description)
myDF$time_created <- as.character(myDF$time_created)
filterDF$user <- as.character(filterDF$user)
gradesDF$actor_id <- as.character(gradesDF$actor_id)

# Only keep student who consented and is in the grade.csv (exclude 384 and 474 as not fully)
valid_users <- filterDF %>%
  filter(
    consent == TRUE,
    is_student == TRUE,
    user %in% gradesDF$actor_id,
    !user %in% c(384, 474)
  ) %>%
  pull(user)

myDF <- myDF[myDF$actor %in% valid_users, ]

# Define action code mapping
action_code_mapping <- list(
  "Submission was evaluated" = "submission_evaluated",
  "User added goal item" = "add_goal_item",
  "User clicked on next question" = "click_next_question",
  "User consented." = "consent",
  "User removed their consent." = "remove_consent",
  "User created a goal item." = "create_goal_item",
  "User created a goal." = "create_goal",
  "User created a new report." = "create_report",
  "User created a team." = "create_team",
  "User created an event." = "create_event",
  "User deleted a question." = "delete_question",
  "User imported an event." = "importe_event",
  "User joined a team." = "join_team",
  "User logged in" = "logged_in",
  "User requested a password reset email." = "request_password_reset",
  "User reset their password." = "reset_password",
  "User selected a category on the concept map" = "select_category",
  "User selected assignments and exams on the course homepage" = "select_assignments",
  "User selected challenges on the course homepage" = "select_challenges",
  "User selected leaderboard on the course homepage" = "select_leaderboard",
  "User selected practice on the course homepage" = "select_practice_from_concept_map",
  "User started practice from goal" = "start_practice_from_goal",
  "User submitted a solution" = "submit_solution",
  "User updated a question." = "update_question",
  "User updated an event." = "update_event",
  "User updated their profile." = "update_profile",
  "User viewed personal ranking and tokens earned on the course leader board" = "view_personal_ranking",
  "User viewed team ranking and tokens earned on a challenge leader board" = "view_team_ranking"
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

# Debug unknown values
print(unique(myDF$description[myDF$action_code == "UNKNOWN"]))

# Omit if it is 'user used recommended goal' action
myDF <- myDF[myDF$action_code != "UNKNOWN", ]

# Remove rows where action_code is NULL or NA
myDF <- myDF[!(is.na(myDF$action_code) | myDF$action_code == "NULL"), ]

# Remove all rows where action_code is "submission_evaluated"
myDF <- myDF[myDF$action_code != "submission_evaluated", ]

# Sort dataset by user and time
myDF <- myDF[order(myDF$actor, myDF$time_created), ]

# Initialize columns
myDF$srl_subcategory <- NA
myDF$srl_code <- NA

# Define SRL mapping for single actions
srl_mapping <- list(
  "create_goal" = list("sub_category" = "Planning", "code" = "MC.P"),
  "add_goal_item" = list("sub_category" = "Planning", "code" = "MC.P"),
  "create_report" = list("sub_category" = "Evaluation", "code" = "MC.E"),
  "view_personal_ranking" = list("sub_category" = "Gamification Engagement", "code" = "M.SE"),
  "view_team_ranking" = list("sub_category" = "Gamification Engagement", "code" = "M.SE"),
  "create_team" = list("sub_category" = "Gamification Engagement", "code" = "M.SE"),
  "join_team" = list("sub_category" = "Gamification Engagement", "code" = "M.SE"),
  "select_assignments" = list("sub_category" = "Monitoring", "code" = "MC.M"),
  "select_challenges" = list("sub_category" = "Gamification Engagement", "code" = "M.SE"),
  "select_leaderboard" = list("sub_category" = "Gamification Engagement", "code" = "M.SE"),
  "select_practice_from_goal" = list("sub_category" = "Planning", "code" = "MC.P"),
  "select_category" = list("sub_category" = "Planning", "code" = "MC.P"),
  "select_practice_from_concept_map" = list("sub_category" = "Planning", "code" = "MC.P"),
  "request_password_reset" = list("sub_category" = "Technical Management", "code" = "P.TM"),
  "update_profile" = list("sub_category" = "Technical Management", "code" = "P.TM"),
  "create_goal_item" = list("sub_category" = "Planning", "code" = "MC.P"),
  "logged_in" = list("sub_category" = "Begin", "code" = "Begin"),
  "reset_password" = list("sub_category" = "Technical Management", "code" = "P.TM"),
  "start_practice_from_goal" = list("sub_category" = "Planning", "code" = "MC.P"),
  "click_next_question" = list("sub_category" = "Planning", "code" = "MC.P")
)

# Remove irrelevant actions that cannot be performed by students
myDF <- myDF[!myDF$action_code %in% c(
  "consent", "create_event", "delete_question", "import_event",
  "remove_consent", "update_event", "update_question"
), ]

# Fill SRL category and code for all rows
correct_attempts <- list()
updated_action_codes <- myDF$action_code

for (i in 1:nrow(myDF)) {
  action <- myDF$action_code[i]
  user <- as.character(myDF$actor[i])
  question <- as.character(myDF$question_id[i])
  status <- myDF$question_status[i]
  attempt <- myDF$nth_attempt[i]

  if (action == "submit_solution") {

    # Handle NA cases
    if (is.na(attempt) && is.na(question)) {
      myDF$srl_subcategory[i] <- "Evaluation"
      myDF$srl_code[i] <- "MC.E"
      myDF$action_code[i] <- "submit_until_correct"
      updated_action_codes[i] <- "submit_until_correct"
      next
    }

    # Initialize if needed
    if (is.null(correct_attempts[[user]])) {
      correct_attempts[[user]] <- list()
    }
    if (is.null(correct_attempts[[user]][[question]])) {
      correct_attempts[[user]][[question]] <- FALSE
    }

    # Now classify
    if (correct_attempts[[user]][[question]] == TRUE) {
      # Already got this correct in the past
      myDF$srl_subcategory[i] <- "Revisiting"
      myDF$srl_code[i] <- "C.R"
      myDF$action_code[i] <- "submit_after_correct"
      updated_action_codes[i] <- "submit_after_correct"
    } else {
      if (attempt == 1) {
        myDF$srl_subcategory[i] <- "First Attempt (per session)"
        myDF$srl_code[i] <- "C.F"
        myDF$action_code[i] <- "submit_first_in_session"
        updated_action_codes[i] <- "submit_first_in_session"
      } else {
        myDF$srl_subcategory[i] <- "Evaluation"
        myDF$srl_code[i] <- "MC.E"
        myDF$action_code[i] <- "submit_until_correct"
        updated_action_codes[i] <- "submit_until_correct"
      }
    }

    # AFTER classification, update correct_attempts
    if (!is.na(status) && status == "Correct") {
      correct_attempts[[user]][[question]] <- TRUE
    }

  } else if (action == "click_next_question") {
    myDF$srl_subcategory[i] <- "NA"
    myDF$srl_code[i] <- "NA"
    myDF$action_code[i] <- "click_next_question"

    if (i > 1 && myDF$actor[i] == myDF$actor[i - 1]) {
      prev_action <- updated_action_codes[i - 1]
      prev_status <- myDF$question_status[i - 1]

      if (prev_action %in% c("submit_until_correct", "submit_first_in_session", "submit_after_correct")) {
        if (prev_status == "Incorrect") {
          myDF$srl_subcategory[i] <- "Planning"
          myDF$srl_code[i] <- "MC.P"
          myDF$action_code[i] <- "click_next_question"
        } else {
          myDF$srl_subcategory[i] <- "Skipping Questions"
          myDF$srl_code[i] <- "C.S"
          myDF$action_code[i] <- "skip_to_next_question"
        }
      } else {
        myDF$srl_subcategory[i] <- "Skipping Questions"
        myDF$srl_code[i] <- "C.S"
        myDF$action_code[i] <- "skip_to_next_question"
      }
    } else {
      myDF$srl_subcategory[i] <- "Skipping Questions"
      myDF$srl_code[i] <- "C.S"
      myDF$action_code[i] <- "skip_to_next_question"
    }
    updated_action_codes[i] <- myDF$action_code[i]
  } else if (action %in% names(srl_mapping)) {
    myDF$srl_subcategory[i] <- srl_mapping[[action]]$sub_category
    myDF$srl_code[i] <- srl_mapping[[action]]$code
  }
}

# Merge full grades into myDF
myDF <- merge(myDF, gradesDF, by.x = "actor", by.y = "actor_id", all.x = TRUE)

# Split by session (60-minute gap)
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

# Write to output
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
  mutate(across(all_of(grade_cols), ~ suppressWarnings(as.numeric(gsub("%", "", .)))))

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


write_csv(filteredDF, "updated_output.csv")
cat("Filtered data saved to 'updated_output.csv'\n")

# Load updated_output.csv and plot Markov Model
filteredDF <- read_csv("updated_output.csv", show_col_types = FALSE)
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

