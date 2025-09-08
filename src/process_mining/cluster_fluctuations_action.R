library(dplyr)
library(tidyr)
library(ggplot2)
library(lubridate)
library(pheatmap)
library(pMineR)
library(DiagrammeR)
library(tibble)

# Load pruned interaction data
df <- read.csv("output_pruned.csv", stringsAsFactors = FALSE)
df$time_created <- ymd_hms(df$time_created)

# Load grade data
grades <- read.csv("data/grades.csv", stringsAsFactors = FALSE)

# Clean and convert grade columns
grades <- grades %>%
  mutate(across(c(mid_1, mid_2, final_exam), ~ as.numeric(gsub("[^0-9\\.]", "", .))))

# Load gender data
gender_df <- read.csv("data/gender.csv", stringsAsFactors = FALSE)

# Load skipped questions data
skipped_df <- read.csv("data/updated_output_skipped_questions.csv", stringsAsFactors = FALSE)

# Create grade_group based on final_score in df
df <- df %>%
  mutate(final_score = as.numeric(final_score)) %>%
  mutate(
    grade_group = case_when(
      final_score > 100.00 ~ "A",
      final_score >= 80.00 & final_score <= 100.00 ~ "A",
      final_score >= 70.00 & final_score <= 79.00  ~ "B",
      final_score >= 60.00 & final_score <= 69.00  ~ "C",
      final_score >= 50.00 & final_score <= 59.00  ~ "D",
      final_score < 50.00                          ~ "F",
      TRUE                                         ~ NA_character_
    )
  )

# Prepare grade group and gender data for merging into skipped_df
grade_groups_df <- df %>%
  distinct(actor, grade_group)

gender_df <- gender_df %>%
  select(actor, gender_group = gender)

# Add the grade_group and gender_group columns to skipped_df
skipped_df <- skipped_df %>%
  left_join(grade_groups_df, by = "actor") %>%
  left_join(gender_df, by = "actor")

# Function to determine Up/Down/Stayed
get_change_label <- function(delta) {
  if (delta > 5) return("Up")
  else if (delta < -5) return("Down")
  else return("Stayed")
}

grade_pairs <- list(
  list(from = "mid_1", to = "mid_2", label = "MT1_to_MT2"),
  list(from = "mid_2", to = "final_exam", label = "MT2_to_Final")
)

# Initialize fluctuation group columns with NA values
df$fluctuation_group1 <- NA_character_
df$fluctuation_group2 <- NA_character_
skipped_df$fluctuation_group1 <- NA_character_
skipped_df$fluctuation_group2 <- NA_character_


for (pair in grade_pairs) {
  from_col <- pair$from
  to_col <- pair$to
  label <- pair$label

  cat("\n=== Processing:", label, "===\n")

  # Assign shift groups (Up/Down/Stayed)
  shift_df <- grades %>%
    mutate(
      delta = .data[[to_col]] - .data[[from_col]],
      shift_group = sapply(delta, get_change_label)
    ) %>%
    select(actor = actor_id, shift_group)

  # Merge shift group with pruned interaction data and gender data
  df_clustered <- df %>%
    left_join(shift_df, by = "actor") %>%
    left_join(gender_df, by = "actor")

  # Merge the current shift group into the main dataframes
  if (label == "MT1_to_MT2") {
    if ("fluctuation_group1" %in% names(skipped_df)) {
      skipped_df <- skipped_df %>%
        left_join(shift_df, by = "actor") %>%
        mutate(fluctuation_group1 = coalesce(fluctuation_group1, shift_group)) %>%
        select(-shift_group)
    } else {
      skipped_df <- skipped_df %>%
        left_join(shift_df, by = "actor") %>%
        rename(fluctuation_group1 = shift_group)
    }

  } else if (label == "MT2_to_Final") {
     if ("fluctuation_group2" %in% names(skipped_df)) {
       skipped_df <- skipped_df %>%
         left_join(shift_df, by = "actor") %>%
         mutate(fluctuation_group2 = coalesce(fluctuation_group2, shift_group)) %>%
         select(-shift_group)
     } else {
       skipped_df <- skipped_df %>%
         left_join(shift_df, by = "actor") %>%
         rename(fluctuation_group2 = shift_group)
     }
  }

  ## --- NEW CODE: GENERATE AND SAVE STACKED BAR GRAPHS ---

  # Prepare combined data for plotting
  plotting_df <- df_clustered %>%
    distinct(actor, shift_group, gender_group, grade_group)

  # Plot Grade Group Distribution
  grade_plot_data <- plotting_df %>%
    group_by(shift_group, grade_group) %>%
    summarise(count = n(), .groups = "drop")

  p_grade <- ggplot(grade_plot_data, aes(x = shift_group, y = count, fill = grade_group)) +
    geom_bar(stat = "identity", position = "stack") + # CHANGE FROM "fill" to "stack"
    geom_text(aes(label = count), position = position_stack(vjust = 0.5)) +
    labs(title = paste("Grade Group Distribution by", label, "Shift Group"),
        x = "Shift Group",
        y = "Number of Students", # Changed y-axis label
        fill = "Grade Group") +
    theme_minimal()
  ggsave(paste0("grade_distribution_", label, ".png"), plot = p_grade, width = 8, height = 6)

  # Plot Gender Group Distribution
  gender_plot_data <- plotting_df %>%
    group_by(shift_group, gender_group) %>%
    summarise(count = n(), .groups = "drop")

  p_gender <- ggplot(gender_plot_data, aes(x = shift_group, y = count, fill = gender_group)) +
    geom_bar(stat = "identity", position = "stack") + # CHANGE FROM "fill" to "stack"
    geom_text(aes(label = count), position = position_stack(vjust = 0.5)) +
    labs(title = paste("Gender Group Distribution by", label, "Shift Group"),
        x = "Shift Group",
        y = "Number of Students", # Changed y-axis label
        fill = "Gender Group") +
    theme_minimal()
  ggsave(paste0("gender_distribution_", label, ".png"), plot = p_gender, width = 8, height = 6)

  ## --- END NEW CODE ---


  # Cleaned subset for plotting
  df_plot_ready <- df_clustered %>%
    select(session_id, time_created, action_code, shift_group, actor)

  all_shifts <- sort(unique(df_plot_ready$shift_group))
  all_subcategories <- sort(unique(df_plot_ready$action_code))

  ## --- Histogram per Shift Group ---
  max_count <- 0
  for (shift in all_shifts) {
    shift_freq <- df_plot_ready %>%
      filter(shift_group == shift) %>%
      count(action_code) %>%
      complete(action_code = all_subcategories, fill = list(n = 0))

    max_count <- max(max_count, max(shift_freq$n))
  }

  for (shift in all_shifts) {
    n_students <- df_plot_ready %>%
      filter(shift_group == shift) %>%
      distinct(actor) %>%
      nrow()

    shift_data <- df_plot_ready %>%
      filter(shift_group == shift) %>%
      count(action_code) %>%
      complete(action_code = all_subcategories, fill = list(n = 0)) %>%
      mutate(avg_count_per_person = n / n_students)

    shift_data$action_code <- factor(shift_data$action_code, levels = all_subcategories)

    p <- ggplot(shift_data, aes(x = action_code, y = avg_count_per_person)) +
      geom_bar(stat = "identity", fill = "steelblue", color = "black") +
      geom_text(aes(label = sprintf("%.2f", avg_count_per_person)), vjust = -0.3, size = 3) +
      scale_y_continuous(limits = c(0, 200)) +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      labs(title = paste("Average Action Count per Person -", label, "-", shift),
          x = paste0("Action Code Subcategory (n=", n_students, ")"),
          y = "Average Count per Person")

    ggsave(paste0("fluc_action_hist", label, "_", shift, ".png"), plot = p, width = 12, height = 6)
  }

  ## --- Heatmap ---

  # Get number of students per shift group
  n_students_by_group <- df_plot_ready %>%
    distinct(actor, shift_group) %>%
    count(shift_group, name = "n_students")

  # Compute raw counts
  raw_counts_df <- df_plot_ready %>%
    count(shift_group, action_code) %>%
    complete(
      shift_group = all_shifts,
      action_code = all_subcategories,
      fill = list(n = 0)
    )

  # Pivot to wide format
  wide_counts <- raw_counts_df %>%
    pivot_wider(
      names_from = action_code,
      values_from = n,
      values_fill = 0
    )

  # Prepare count matrix
  count_matrix <- as.data.frame(wide_counts)
  rownames(count_matrix) <- count_matrix$shift_group
  count_matrix$shift_group <- NULL

  # Compute percentages using n_students_by_group
  heatmap_df <- count_matrix %>%
    rownames_to_column("shift_group") %>%
    left_join(n_students_by_group, by = "shift_group") %>%
    mutate(across(-c(shift_group, n_students), ~ .x / n_students)) %>%
    select(-n_students) %>%
    column_to_rownames("shift_group")

  # Identify and remove columns where all values are < 1
  low_percent_cols <- names(heatmap_df)[apply(heatmap_df, 2, function(col) all(col < 1))]

  if (length(low_percent_cols) > 0) {
    message("Omitting columns with all percentage values < 1%: ", paste(low_percent_cols, collapse = ", "))
  }

  heatmap_df <- heatmap_df[, !(names(heatmap_df) %in% low_percent_cols), drop = FALSE]

  # Reorder rows
  desired_order <- c("Up", "Stayed", "Down")
  heatmap_df <- heatmap_df[desired_order, , drop = FALSE]

  # Define desired column order
  desired_col_order <- c(
    "add_goal_item",
    "create_goal",
    "create_goal_item",
    "select_category",
    "select_practice_from_concept_map",
    "select_practice_from_goal",
    "start_practice_from_goal",
    "click_next_question",
    "select_assignments",
    "submit_until_correct",
    "create_report",
    "submit_first_in_session",
    "submit_after_correct",
    "skip_to_next_question",
    "view_personal_ranking",
    "view_team_ranking",
    "create_team",
    "join_team",
    "select_challenges",
    "select_leaderboard",
    "request_password_reset",
    "reset_password",
    "update_profile"
  )

  existing_col_order <- desired_col_order[desired_col_order %in% colnames(heatmap_df)]

  heatmap_df <- heatmap_df[, existing_col_order, drop = FALSE]

  # --- Heatmap ---
  png(paste0("fluc_action_heatmap", label, ".png"), width = 1400, height = 350)
  pheatmap(as.matrix(heatmap_df),
          main = paste("ActionCode Average Frequency by", label, "Group"),
          cluster_rows = FALSE, cluster_cols = FALSE,
          display_numbers = TRUE,
          fontsize_number = 15,
          fontsize = 20,
          number_color = ifelse(as.matrix(heatmap_df) > 20, "white", "black"),
          color = colorRampPalette(c("white", "darkblue"))(100),
          angle_col = 45,
          cellwidth = 60)
  dev.off()

  ## --- Markov Plot per Shift Group ---
  for (shift in all_shifts) {
    cluster_data <- df_plot_ready %>%
      filter(shift_group == shift) %>%
      rename(CaseID = session_id, Timestamp = time_created, Event = action_code)

    n_students <- cluster_data %>% distinct(actor) %>% nrow()

    cat("\n====", label, "-", shift, "(N =", n_students, ") ====\n")

    if (nrow(cluster_data) > 0) {
      objDL <- dataLoader(verbose.mode = FALSE)
      objDL$load.data.frame(
        mydata = cluster_data,
        IDName = "CaseID",
        EVENTName = "Event",
        dateColumnName = "Timestamp",
        format.column.date = "%Y-%m-%d %H:%M:%S"
      )

      fomm <- firstOrderMarkovModel(verbose.mode = FALSE)
      fomm$loadDataset(dataList = objDL$getData())
      fomm$trainModel()

      print(grViz(fomm$plot(giveItBack = TRUE)))

      if (shift != last(all_shifts)) {
        readline(prompt = "Press [Enter] to continue...")
      }
    } else {
      cat("⚠️ No data for group:", shift, "\n")
    }
  }

}

write.csv(skipped_df, "skipped_questions_with_groups.csv", row.names = FALSE)