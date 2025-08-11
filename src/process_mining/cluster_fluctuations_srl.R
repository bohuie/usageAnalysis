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

  df_clustered <- df_clustered %>%
    filter(!is.na(shift_group), !is.na(srl_subcategory)) %>%
    mutate(srl_subcategory = ifelse(srl_subcategory == "Setup, Technical & Account Management",
                                    "Setup & Technical", srl_subcategory))

  # Cleaned subset for plotting
  df_plot_ready <- df_clustered %>%
    select(session_id, time_created, srl_subcategory, shift_group, actor)

  all_shifts <- sort(unique(df_plot_ready$shift_group))
  all_subcategories <- sort(unique(df_plot_ready$srl_subcategory))


  ## --- Histogram per Shift Group ---
  max_count <- 0
  for (shift in all_shifts) {
    shift_freq <- df_plot_ready %>%
      filter(shift_group == shift) %>%
      count(srl_subcategory) %>%
      complete(srl_subcategory = all_subcategories, fill = list(n = 0))

    max_count <- max(max_count, max(shift_freq$n))
  }

  for (shift in all_shifts) {
    n_students <- df_plot_ready %>%
      filter(shift_group == shift) %>%
      distinct(actor) %>%
      nrow()

    shift_data <- df_plot_ready %>%
      filter(shift_group == shift) %>%
      count(srl_subcategory) %>%
      complete(srl_subcategory = all_subcategories, fill = list(n = 0)) %>%
      mutate(avg_count_per_person = n / n_students)

    shift_data$srl_subcategory <- factor(shift_data$srl_subcategory, levels = all_subcategories)

    p <- ggplot(shift_data, aes(x = srl_subcategory, y = avg_count_per_person)) +
      geom_bar(stat = "identity", fill = "steelblue", color = "black") +
      geom_text(aes(label = sprintf("%.2f", avg_count_per_person)), vjust = -0.3, size = 3) +
      scale_y_continuous(limits = c(0, 200)) +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      labs(title = paste("Average SRL Count per Person -", label, "-", shift),
          x = paste0("SRL Subcategory (n=", n_students, ")"),
          y = "Average Count per Person")

    ggsave(paste0("fluc_srl_hist", label, "_", shift, ".png"), plot = p, width = 12, height = 6)
  }

  ## --- Heatmap ---

  # First, get number of students per shift group
  n_students_by_group <- df_plot_ready %>%
    distinct(actor, shift_group) %>%
    count(shift_group, name = "n_students")

  # Then compute percentages
  heatmap_df <- df_plot_ready %>%
    count(shift_group, srl_subcategory) %>%
    complete(
      shift_group = all_shifts,
      srl_subcategory = all_subcategories,
      fill = list(n = 0)
    ) %>%
    left_join(n_students_by_group, by = "shift_group") %>%
    mutate(percent = (n / n_students)) %>%
    select(shift_group, srl_subcategory, percent) %>%
    pivot_wider(
      names_from = srl_subcategory,
      values_from = percent,
      values_fill = 0
    )

  # Convert to data frame and set rownames
  heatmap_df <- as.data.frame(heatmap_df)
  rownames(heatmap_df) <- heatmap_df$shift_group
  heatmap_df$shift_group <- NULL

  # Reorder rows (shift groups)
  desired_order <- c("Up", "Stayed", "Down")
  heatmap_df <- heatmap_df[desired_order, , drop = FALSE]

  # Define desired column order for SRL subcategories
  desired_col_order <- c(
    "Planning",
    "Monitoring",
    "Evaluation",
    "First Attempt (per session)",
    "Revisiting",
    "Skipping Questions",
    "Gamification Engagement",
    "Technical Management"
  )

  # Keep only columns that exist in the data
  existing_col_order <- desired_col_order[desired_col_order %in% colnames(heatmap_df)]
  heatmap_df <- heatmap_df[, existing_col_order, drop = FALSE]

  # Generate heatmap
  png(paste0("fluc_srl_heatmap", label, ".png"), width = 1400, height = 350)
  pheatmap(as.matrix(heatmap_df),
          main = paste("SRL Average Frequency by", label, "Group"),
          cluster_rows = FALSE,
          cluster_cols = FALSE,
          display_numbers = TRUE,
          fontsize_number = 15,
          fontsize = 20,
          number_color = ifelse(as.matrix(heatmap_df) > 80, "white", "black"),
          color = colorRampPalette(c("white", "darkblue"))(100),
          angle_col = 45,
          cellwidth = 50)
  dev.off()


  ## --- Markov Plot per Shift Group ---
  for (shift in all_shifts) {
    cluster_data <- df_plot_ready %>%
      filter(shift_group == shift) %>%
      rename(CaseID = session_id, Timestamp = time_created, Event = srl_subcategory)

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
