
# by grade group instead of by behavior cluster, srl stages

library(dplyr)
library(tidyr)
library(lubridate)
library(pheatmap)
library(reshape2)
library(tibble)
library(cluster)
library(factoextra)
library(ggplot2)
library(pMineR)
library(DiagrammeR)

# Load the full dataset
df <- read.csv("updated_output.csv", stringsAsFactors = FALSE)
df$time_created <- ymd_hms(df$time_created)
df <- df %>% filter(!is.na(srl_subcategory), srl_subcategory != "")
df$srl_subcategory[df$srl_subcategory == "Begin"] <- "Logged In"

# Compute action-to-action transitions
transitions <- df %>%
  arrange(actor, session_id, time_created) %>%
  group_by(actor, session_id) %>%
  mutate(next_action = lead(srl_subcategory)) %>%
  ungroup() %>%
  filter(!is.na(next_action))

transition_matrix <- transitions %>%
  count(srl_subcategory, next_action) %>%
  pivot_wider(names_from = next_action, values_from = n, values_fill = 0)

transition_matrix <- as.data.frame(transition_matrix)
rownames(transition_matrix) <- transition_matrix$srl_subcategory
transition_matrix$srl_subcategory <- NULL

# Frequency heatmap
pheatmap(as.matrix(transition_matrix),
         main = "Transition Frequency Heatmap",
         fontsize = 10,
         display_numbers = TRUE,
         number_format = "%.0f",
         cluster_rows = FALSE,
         cluster_cols = FALSE,
         color = colorRampPalette(c("white", "darkred"))(100))

# Compute z-scores and plot z-score heatmap
flat_z <- reshape2::melt(as.matrix(transition_matrix))
colnames(flat_z) <- c("from", "to", "count")
flat_z$z_score <- scale(flat_z$count)

write.csv(flat_z, "srl_flat_z.csv", row.names = FALSE)

# Plot histogram of z-scores to help decide threshold
library(ggplot2)

hist_plot <- ggplot(flat_z, aes(x = z_score)) +
  geom_histogram(binwidth = 0.5, fill = "salmon", color = "black") +
  geom_text(stat = "bin", aes(label = ..count..), binwidth = 0.5, vjust = -0.5, size = 3) +
  geom_vline(xintercept = 0, color = "blue", linetype = "dashed") +
  labs(title = "Histogram of Transition Z-Scores", x = "Z-Score", y = "Frequency") +
  theme_minimal()

ggsave("srl_zscore_histogram.png", plot = hist_plot, width = 10, height = 6)
cat("Saved histogram as: srl_zscore_histogram.png\n")

z_matrix <- reshape2::dcast(flat_z, from ~ to, value.var = "z_score", fill = 0)
rownames(z_matrix) <- z_matrix$from
z_matrix$from <- NULL

pheatmap(as.matrix(z_matrix),
         main = "Z-Score Heatmap",
         fontsize = 10,
         display_numbers = TRUE,
         number_format = "%.2f",
         cluster_rows = FALSE,
         cluster_cols = FALSE,
         color = colorRampPalette(c("blue", "white", "red"))(100),
         breaks = seq(-max(abs(flat_z$z_score), na.rm = TRUE),
                      max(abs(flat_z$z_score), na.rm = TRUE),
                      length.out = 101))

# Apply z-score filtering
flat_z$dropped <- ifelse(flat_z$z_score < -0.319, "Dropped", "Kept")
flat_z$valid <- ifelse(flat_z$dropped == "Dropped", NA, flat_z$count)

# Save dropped transitions to CSV
dropped_transitions <- flat_z %>%
  filter(dropped == "Dropped") %>%
  arrange(desc(count)) %>%
  select(from, to, count, z_score)

write.csv(dropped_transitions, "srl_alt_dropped.csv", row.names = FALSE)

highlight_matrix <- reshape2::dcast(flat_z, from ~ to, value.var = "valid", fill = NA)
rownames(highlight_matrix) <- highlight_matrix$from
highlight_matrix$from <- NULL

text_matrix <- reshape2::dcast(flat_z, from ~ to, value.var = "dropped", fill = "")
rownames(text_matrix) <- text_matrix$from
text_matrix$from <- NULL
text_matrix <- apply(text_matrix, c(1, 2), function(x) if (x == "Kept") "✓" else if (x == "Dropped") "×" else "")

pheatmap(as.matrix(highlight_matrix),
         main = "Z-Filtered Transitions (✓ Kept, × Dropped)",
         display_numbers = text_matrix,
         number_color = "black",
         cluster_rows = FALSE,
         cluster_cols = FALSE,
         color = colorRampPalette(c("white", "steelblue"))(100),
         na_col = "lightgray")

# Drop unwanted transitions
flat_z <- flat_z %>% mutate(pair = paste(from, to, sep = " → "))
dropped_pairs <- flat_z %>% filter(dropped == "Dropped") %>% pull(pair)

df_pruned <- df %>%
  arrange(actor, session_id, time_created) %>%
  group_by(actor, session_id) %>%
  mutate(
    session_size = n(),
    next_action = lead(srl_subcategory),
    prev_action = lag(srl_subcategory),
    transition_pair = paste(srl_subcategory, next_action, sep = " → "),
    reverse_pair = paste(prev_action, srl_subcategory, sep = " → "),
    drop_flag = (
      session_size == 1 |                                # drop sessions with only 1 action
        transition_pair %in% dropped_pairs |               # drop from-actions of dropped pairs
        (row_number() == n() & reverse_pair %in% dropped_pairs)  # drop last action if previous pair was dropped
    )
  ) %>%
  ungroup() %>%
  filter(!drop_flag) %>%
  select(-session_size, -next_action, -prev_action, -transition_pair, -reverse_pair, -drop_flag)

# Save Z-pruned dataset before analysis
write.csv(df_pruned, "srl_output_pruned.csv", row.names = FALSE)

# --- Replace clustering by grade groups based on final_score ---
df_pruned <- df_pruned %>%
  mutate(
    final_score = gsub("%", "", final_score),  # remove % sign
    final_score = as.numeric(final_score),     # convert to numeric
    grade_group = case_when(
      final_score >= 80.00 & final_score <= 100.00 ~ "A",
      final_score >= 70.00 & final_score <= 79.00  ~ "B",
      final_score >= 60.00 & final_score <= 69.00  ~ "C",
      final_score >= 50.00 & final_score <= 59.00  ~ "D",
      final_score < 50.00                       ~ "F",
      TRUE                                  ~ NA_character_
    )
  )

# Map each actor to their grade_group (taking distinct values)
actor_grade_groups <- df_pruned %>%
  select(actor, grade_group) %>%
  distinct() %>%
  filter(!is.na(grade_group))

# Join grade groups to df_pruned
df_with_clusters <- df_pruned %>%
  select(-grade_group) %>%  # Remove duplicate before join
  left_join(actor_grade_groups, by = "actor")


# Save clustered dataset with grade groups
write.csv(df_with_clusters, "srl_output_clustered_all_students.csv", row.names = FALSE)

# ----- Markov Model Plot with Grade Groups -----
df_clustered <- read.csv("srl_output_clustered_all_students.csv", stringsAsFactors = FALSE)
df_clustered$time_created <- ymd_hms(df_clustered$time_created)

# Clean and convert grade columns
grade_columns <- c("lab", "mid_1", "mid_2", "final_exam", "final_score")
for (col in grade_columns) {
  if (col %in% colnames(df_clustered)) {
    df_clustered[[col]] <- as.numeric(gsub("%", "", df_clustered[[col]]))
  }
}

# Prepare session-level data filtered by grade_group instead of cluster
df_plot_ready <- df_clustered %>%
  filter(!is.na(grade_group), !is.na(srl_subcategory)) %>%
  select(session_id, time_created, srl_subcategory, grade_group, actor, all_of(grade_columns))

# Rename the specific SRL subcategory before further analysis and plotting
df_plot_ready <- df_plot_ready %>%
  mutate(srl_subcategory = ifelse(srl_subcategory == "Setup, Technical & Account Management",
                                 "Setup & Technical",
                                 srl_subcategory))

# Get list of grade groups
all_grade_groups <- sort(unique(df_plot_ready$grade_group))

for (target_grade in all_grade_groups) {
  cluster_data <- df_plot_ready %>%
    filter(grade_group == target_grade) %>%
    rename(CaseID = session_id,
           Timestamp = time_created,
           Event = srl_subcategory)
  
  cluster_data$Timestamp <- ymd_hms(cluster_data$Timestamp)
  
  grade_avg <- cluster_data %>%
    summarise(across(all_of(grade_columns), ~ round(mean(.x, na.rm = TRUE), 2)))
  
  num_students <- cluster_data %>%
    select(actor) %>%
    distinct() %>%
    nrow()
  
  title_str <- paste0(
    "Grade Group ", target_grade, ": ",
    "Lab=", grade_avg$lab, ", ",
    "MT1=", grade_avg$mid_1, ", ",
    "MT2=", grade_avg$mid_2, ", ",
    "FinalExam=", grade_avg$final_exam, ", ",
    "FinalGrade=", grade_avg$final_score, ", ",
    "N=", num_students
  )
  
  if (nrow(cluster_data) > 0) {
    cat("\n====", title_str, "====\n\n")
    
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
    
    # Only pause if it's NOT the last group
    if (target_grade != max(all_grade_groups)) {
      readline(prompt = "Press [Enter] to continue to the next grade group...")
    }
  } else {
    cat("⚠️  Grade Group", target_grade, "has no valid data.\n")
  }
}

# --- Histogram of srl_subcategory per grade group (normalized: average count per person) ---

# Before the loop, get all unique srl_subcategory values (ordered)
all_subcategories <- sort(unique(df_plot_ready$srl_subcategory))

# Set a reasonable max y limit for avg counts per person (e.g., 200)
max_y_limit <- 200

for (grade in all_grade_groups) {
  grade_data <- df_plot_ready %>%
    filter(grade_group == grade) %>%
    count(srl_subcategory) %>%
    complete(srl_subcategory = all_subcategories, fill = list(n = 0))
  
  num_students_in_grade <- df_plot_ready %>%
    filter(grade_group == grade) %>%
    select(actor) %>%
    distinct() %>%
    nrow()

  # Normalize counts by number of students
  grade_data <- grade_data %>%
    mutate(avg_count_per_person = n / num_students_in_grade)

  # Make srl a factor for consistent order
  grade_data$srl_subcategory <- factor(grade_data$srl_subcategory, levels = all_subcategories)
  
  # Plot normalized histogram
  p <- ggplot(grade_data, aes(x = srl_subcategory, y = avg_count_per_person)) +
    geom_bar(stat = "identity", fill = "skyblue", color = "black") +
    geom_text(aes(label = sprintf("%.2f", avg_count_per_person)), vjust = -0.3, size = 3) +
    scale_y_continuous(limits = c(0, max_y_limit), expand = expansion(mult = c(0, 0.05))) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    labs(
      title = paste("Average SRL Count per Person - Grade Group", grade),
      x = paste0("SRL Subcategory (n = ", num_students_in_grade, ")"),
      y = "Average Count per Person"
    )
  
  # Save plot to PNG
  filename <- paste0("grade_srl_hist_", grade, ".png")
  ggsave(filename, plot = p, width = 12, height = 6)
  cat("Saved normalized histogram to:", filename, "\n")
}


# --- Heatmap: Normalized SRL Subcategory Frequency by Grade Group ---

# Build normalized frequency matrix: grade_group × srl
heatmap_df <- df_plot_ready %>%
  count(grade_group, srl_subcategory) %>%
  complete(
    grade_group = all_grade_groups,
    srl_subcategory = all_subcategories,
    fill = list(n = 0)
  )

# Get number of students per grade_group
n_students_by_grade <- df_plot_ready %>%
  distinct(actor, grade_group) %>%
  count(grade_group, name = "n_students")

# Join student counts and normalize counts by number of students
heatmap_df <- heatmap_df %>%
  left_join(n_students_by_grade, by = "grade_group") %>%
  mutate(avg_count_per_person = n / n_students) %>%
  select(grade_group, srl_subcategory, avg_count_per_person) %>%
  pivot_wider(
    names_from = srl_subcategory,
    values_from = avg_count_per_person,
    values_fill = 0
  ) %>%
  arrange(factor(grade_group, levels = c("A", "B", "C", "D", "F")))

# Reorder columns by desired SRL subcategory order
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

# Keep only columns that are present
existing_col_order <- desired_col_order[desired_col_order %in% colnames(heatmap_df)]
heatmap_df <- heatmap_df[, c("grade_group", existing_col_order), drop = FALSE]

# Prepare matrix for heatmap
rownames(heatmap_df) <- heatmap_df$grade_group
heatmap_df$grade_group <- NULL

heatmap_matrix <- as.matrix(heatmap_df)

# Colors for numbers: white text for large values, black otherwise
number_colors <- ifelse(heatmap_matrix > 80, "white", "black")

# Save the heatmap
png("grade_srl_heatmap.png", width = 1400, height = 600)
pheatmap(heatmap_matrix,
         main = "Grade SRL Heatmap",
         cluster_rows = FALSE,
         cluster_cols = FALSE,
         display_numbers = TRUE,
         number_format = "%.2f",
         fontsize_number = 15,
         fontsize = 20,
         angle_col = 45,
         number_color = number_colors,
         color = colorRampPalette(c("white", "darkblue"))(100),
         cellwidth = 60)
dev.off()

cat("Normalized heatmap saved as: grade_srl_heatmap.png\n")



# ----- Final Summary -----
overall_grade_avg <- df_plot_ready %>%
  summarise(across(all_of(grade_columns), ~ round(mean(.x, na.rm = TRUE), 2)))

overall_num_students <- df_plot_ready %>%
  select(actor) %>%
  distinct() %>%
  nrow()

final_summary <- paste0(
  "===== Overall Summary: ",
  "Lab=", overall_grade_avg$lab, ", ",
  "MT1=", overall_grade_avg$mid_1, ", ",
  "MT2=", overall_grade_avg$mid_2, ", ",
  "FinalExam=", overall_grade_avg$final_exam, ", ",
  "FinalGrade=", overall_grade_avg$final_score, ", ",
  "N=", overall_num_students, " ====="
)

cat("\n", final_summary, "\n")

# Markov plot without grouping (for all students)
df_pruned_all <- read.csv("srl_output_pruned.csv", stringsAsFactors = FALSE)
df_pruned_all$time_created <- ymd_hms(df_pruned_all$time_created)

markov_input <- df_pruned_all %>%
  filter(!is.na(srl_subcategory)) %>%
  rename(
    CaseID = session_id,
    Timestamp = time_created,
    Event = srl_subcategory
  )

objDL_full <- dataLoader(verbose.mode = FALSE)
objDL_full$load.data.frame(
  mydata = markov_input,
  IDName = "CaseID",
  EVENTName = "Event",
  dateColumnName = "Timestamp",
  format.column.date = "%Y-%m-%d %H:%M:%S"
)

fomm_full <- firstOrderMarkovModel(verbose.mode = FALSE)
fomm_full$loadDataset(dataList = objDL_full$getData())
fomm_full$trainModel()

print(grViz(fomm_full$plot(giveItBack = TRUE)))