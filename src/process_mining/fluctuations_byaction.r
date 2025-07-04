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
    shift_data <- df_plot_ready %>%
      filter(shift_group == shift) %>%
      count(action_code) %>%
      complete(action_code = all_subcategories, fill = list(n = 0))

    shift_data$action_code <- factor(shift_data$action_code, levels = all_subcategories)
    n_students <- df_plot_ready %>% filter(shift_group == shift) %>% distinct(actor) %>% nrow()

    p <- ggplot(shift_data, aes(x = action_code, y = n)) +
      geom_bar(stat = "identity", fill = "steelblue", color = "black") +
      geom_text(aes(label = n), vjust = -0.3, size = 3) +
      scale_y_continuous(limits = c(0, max_count * 1.1)) +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      labs(title = paste("Action Code Frequency -", label, "-", shift),
           x = paste0("Action Code Subcategory (n=", n_students, ")"),
           y = "Count")

    ggsave(paste0("srl_hist_", label, "_", shift, ".png"), plot = p, width = 12, height = 6)
  }

  ## --- Heatmap ---
  heatmap_df <- df_plot_ready %>%
    count(shift_group, action_code) %>%
    complete(
      shift_group = all_shifts,
      action_code = all_subcategories,
      fill = list(n = 0)
    ) %>%
    pivot_wider(
      names_from = action_code,
      values_from = n,
      values_fill = 0
    )

  heatmap_df <- as.data.frame(heatmap_df)
  rownames(heatmap_df) <- heatmap_df$shift_group
  heatmap_df$shift_group <- NULL


  png(paste0("action_heatmap_", label, ".png"), width = 1400, height = 350)
  pheatmap(as.matrix(heatmap_df),
           main = paste("ActionCode Frequency by", label, "Group"),
           cluster_rows = FALSE, cluster_cols = FALSE,
           display_numbers = TRUE,
           fontsize_number = 15,
           fontsize = 20,
           number_color = ifelse(as.matrix(heatmap_df) > 3000, "white", "black"),
           color = colorRampPalette(c("white", "darkblue"))(100),
           angle_col = 45,
           cellwidth = 50)
  dev.off()
}