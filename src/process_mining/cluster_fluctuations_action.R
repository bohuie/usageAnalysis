library(dplyr)
library(tidyr)
library(ggplot2)
library(lubridate)
library(pheatmap)
library(pMineR)
library(DiagrammeR)

# Load pruned interaction data
df <- read.csv("output_pruned.csv", stringsAsFactors = FALSE)
df$time_created <- ymd_hms(df$time_created)

# Load grade data
grades <- read.csv("data/grades.csv", stringsAsFactors = FALSE)

# Clean and convert grade columns
grades <- grades %>%
  mutate(across(c(mid_1, mid_2, final_exam), ~ as.numeric(gsub("[^0-9\\.]", "", .))))

# Function to determine Up/Down/Stayed
get_change_label <- function(delta) {
  if (delta > 5) return("Up")  # or > 5
  else if (delta < -5) return("Down") # or < -5
  else return("Stayed")
}

grade_pairs <- list(
  list(from = "mid_1", to = "mid_2", label = "MT1_to_MT2"),
  list(from = "mid_2", to = "final_exam", label = "MT2_to_Final")
)

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

  # Merge shift group with pruned interaction data
  df_clustered <- df %>%
    left_join(shift_df, by = "actor")

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
      scale_y_continuous(limits = c(0, 200)) +  # or adjust max as you want
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      labs(title = paste("Average Action Count per Person -", label, "-", shift),
          x = paste0("Action Code Subcategory (n=", n_students, ")"),
          y = "Average Count per Person")


    ggsave(paste0("fluc_action_hist", label, "_", shift, ".png"), plot = p, width = 12, height = 6)
  }

  ## --- Heatmap ---

  # First, get number of students per shift group
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

  # Pivot to wide format (rows = shift groups, columns = action codes, values = counts)
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

  # Print omitted columns
  if (length(low_percent_cols) > 0) {
    message("Omitting columns with all percentage values < 1%: ", paste(low_percent_cols, collapse = ", "))
  }

  # Filter them out
  heatmap_df <- heatmap_df[, !(names(heatmap_df) %in% low_percent_cols), drop = FALSE]


  # Reorder rows
  desired_order <- c("Up", "Stayed", "Down")
  heatmap_df <- heatmap_df[desired_order, , drop = FALSE]

  # Define desired column order
desired_col_order <- c(
  "add_goal_item",
  "created_goal",
  "created_goal_item",
  "selected_category",
  "selected_practice_from_concept_map",
  "selected_practice_from_goal",
  "started_practice_from_goal",
  "clicked_next_question1",
  "selected_assignments",
  "submitted_solution1",
  "created_report",
  "submitted_solution2",
  "submitted_solution3",
  "clicked_next_question2",
  "viewed_personal_ranking",
  "viewed_team_ranking",
  "created_team",
  "joined_team",
  "selected_challenges",
  "selected_leaderboard",
  "requested_password_reset",
  "reset_password",
  "updated_profile"
)

# Keep only those columns present in the current data
existing_col_order <- desired_col_order[desired_col_order %in% colnames(heatmap_df)]

# Reorder columns
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