# cluster_gender_action.R
# Clusters the updated_output.csv data by gender from gender.csv
# Generates: state diagrams, bar graphs, heatmaps

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

# -------------------- Load Data --------------------
df <- read.csv("updated_output.csv", stringsAsFactors = FALSE)
df$time_created <- ymd_hms(df$time_created)

# Load gender info
gender_info <- read.csv("data/gender.csv", stringsAsFactors = FALSE)
actor_gender <- gender_info %>%
  select(actor, gender) %>%
  distinct() %>%
  filter(!is.na(gender) & gender != "")

# -------------------- Transition Matrix --------------------
transitions <- df %>%
  arrange(actor, session_id, time_created) %>%
  group_by(actor, session_id) %>%
  mutate(next_action = lead(action_code)) %>%
  ungroup() %>%
  filter(!is.na(next_action))

transition_matrix <- transitions %>%
  count(action_code, next_action) %>%
  pivot_wider(names_from = next_action, values_from = n, values_fill = 0)

transition_matrix <- as.data.frame(transition_matrix)
rownames(transition_matrix) <- transition_matrix$action_code
transition_matrix$action_code <- NULL

# Frequency heatmap
pheatmap(as.matrix(transition_matrix),
         main = "Transition Frequency Heatmap",
         fontsize = 10,
         display_numbers = TRUE,
         number_format = "%.0f",
         cluster_rows = FALSE,
         cluster_cols = FALSE,
         color = colorRampPalette(c("white", "darkred"))(100))

# -------------------- Z-Score Heatmap --------------------
flat_z <- reshape2::melt(as.matrix(transition_matrix))
colnames(flat_z) <- c("from", "to", "count")
flat_z$z_score <- scale(flat_z$count)

write.csv(flat_z, "srl_flat_z.csv", row.names = FALSE)

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

# -------------------- Z-Score Filtering --------------------
flat_z$dropped <- ifelse(flat_z$z_score < 1.96, "Dropped", "Kept")
flat_z$valid <- ifelse(flat_z$dropped == "Dropped", NA, flat_z$count)

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

# -------------------- Drop Unwanted Transitions --------------------
flat_z <- flat_z %>% mutate(pair = paste(from, to, sep = " → "))
dropped_pairs <- flat_z %>% filter(dropped == "Dropped") %>% pull(pair)

df_pruned <- df %>%
  arrange(actor, session_id, time_created) %>%
  group_by(actor, session_id) %>%
  mutate(
    session_size = n(),
    next_action = lead(action_code),
    prev_action = lag(action_code),
    transition_pair = paste(action_code, next_action, sep = " → "),
    reverse_pair = paste(prev_action, action_code, sep = " → "),
    drop_flag = (
      session_size == 1 |
      transition_pair %in% dropped_pairs |
      (row_number() == n() & reverse_pair %in% dropped_pairs)
    )
  ) %>%
  ungroup() %>%
  filter(!drop_flag) %>%
  select(-session_size, -next_action, -prev_action, -transition_pair, -reverse_pair, -drop_flag)

write.csv(df_pruned, "srl_output_pruned.csv", row.names = FALSE)

# -------------------- Join Gender Info --------------------
df_with_clusters <- df_pruned %>%
  left_join(actor_gender, by = "actor")

write.csv(df_with_clusters, "srl_output_clustered_gender.csv", row.names = FALSE)

# -------------------- Markov Model Plots per Gender --------------------
df_clustered <- read.csv("srl_output_clustered_gender.csv", stringsAsFactors = FALSE)
df_clustered$time_created <- ymd_hms(df_clustered$time_created)

df_plot_ready <- df_clustered %>%
  filter(!is.na(gender), !is.na(action_code)) %>%
  select(session_id, time_created, action_code, gender, actor)

all_genders <- sort(unique(df_plot_ready$gender))

for (g in all_genders) {
  cluster_data <- df_plot_ready %>%
    filter(gender == g) %>%
    rename(CaseID = session_id,
           Timestamp = time_created,
           Event = action_code)
  
  cluster_data$Timestamp <- ymd_hms(cluster_data$Timestamp)
  
  num_students <- cluster_data %>%
    select(actor) %>%
    distinct() %>%
    nrow()
  
  title_str <- paste0("Gender: ", g, ", N=", num_students)
  
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
    
    if (g != tail(all_genders, 1)) {
      readline(prompt = "Press [Enter] to continue to the next gender group...")
    }
  } else {
    cat("⚠️ Gender", g, "has no valid data.\n")
  }
}

# -------------------- Histogram per Gender --------------------
all_subcategories <- sort(unique(df_plot_ready$action_code))
max_y_limit <- 200

for (g in all_genders) {
  gender_data <- df_plot_ready %>%
    filter(gender == g) %>%
    count(action_code) %>%
    complete(action_code = all_subcategories, fill = list(n = 0))
  
  num_students_in_gender <- df_plot_ready %>%
    filter(gender == g) %>%
    select(actor) %>%
    distinct() %>%
    nrow()

  gender_data <- gender_data %>%
    mutate(avg_count_per_person = n / num_students_in_gender)

  gender_data$action_code <- factor(gender_data$action_code, levels = all_subcategories)
  
  p <- ggplot(gender_data, aes(x = action_code, y = avg_count_per_person)) +
    geom_bar(stat = "identity", fill = "skyblue", color = "black") +
    geom_text(aes(label = sprintf("%.2f", avg_count_per_person)), vjust = -0.3, size = 3) +
    scale_y_continuous(limits = c(0, max_y_limit), expand = expansion(mult = c(0, 0.05))) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    labs(
      title = paste("Action Code Count per Person - Gender", g),
      x = paste0("Action Code (n = ", num_students_in_gender, ")"),
      y = "Average Count per Person"
    )
  
  filename <- paste0("gender_action_hist_", g, ".png")
  ggsave(filename, plot = p, width = 12, height = 6)
  cat("Saved normalized histogram to:", filename, "\n")
}

# -------------------- Heatmap per Gender --------------------
heatmap_df <- df_plot_ready %>%
  count(gender, action_code) %>%
  complete(
    gender = all_genders,
    action_code = all_subcategories,
    fill = list(n = 0)
  )

n_students_by_gender <- df_plot_ready %>%
  distinct(actor, gender) %>%
  count(gender, name = "n_students")

heatmap_df <- heatmap_df %>%
  left_join(n_students_by_gender, by = "gender") %>%
  mutate(avg_count_per_person = n / n_students) %>%
  select(gender, action_code, avg_count_per_person) %>%
  pivot_wider(
    names_from = action_code,
    values_from = avg_count_per_person,
    values_fill = 0
  )

rownames(heatmap_df) <- heatmap_df$gender
heatmap_df$gender <- NULL

low_percent_cols <- names(heatmap_df)[apply(heatmap_df, 2, function(col) all(col < 1))]
if (length(low_percent_cols) > 0) {
  message("Omitting columns with all values < 1: ", paste(low_percent_cols, collapse = ", "))
}
heatmap_df <- heatmap_df[, !(names(heatmap_df) %in% low_percent_cols), drop = FALSE]

heatmap_matrix <- as.matrix(heatmap_df)
number_colors <- ifelse(heatmap_matrix > 40, "white", "black")

png("gender_action_heatmap.png", width = 1400, height = 600)
pheatmap(heatmap_matrix,
         main = "Gender Action Heatmap",
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

cat("Normalized heatmap saved as: gender_action_heatmap.png\n")

# -------------------- Markov Plot for All Students --------------------
df_pruned_all <- read.csv("srl_output_pruned.csv", stringsAsFactors = FALSE)
df_pruned_all$time_created <- ymd_hms(df_pruned_all$time_created)

markov_input <- df_pruned_all %>%
  filter(!is.na(action_code)) %>%
  rename(
    CaseID = session_id,
    Timestamp = time_created,
    Event = action_code
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
