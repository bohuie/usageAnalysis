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
# STEP 1: Compute transitions BEFORE pruning
df <- read.csv("data/output.csv", stringsAsFactors = FALSE)
df$time_created <- ymd_hms(df$time_created)

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

# Build actor vectors BEFORE pruning
actor_vectors_raw <- df %>%
  group_by(actor, action_code) %>%
  summarise(count = n(), .groups = "drop") %>%
  pivot_wider(names_from = action_code, values_from = count, values_fill = 0)

X <- actor_vectors_raw %>% column_to_rownames("actor")
X <- X[complete.cases(X), ]
X <- X[!apply(X, 1, function(row) any(is.nan(row) | is.infinite(row))), ]
X <- X[rowSums(X) > 0, ]

# Perform k-means clustering (same as before)
set.seed(42)
k_best <- 3
km_result <- kmeans(X, centers = k_best, nstart = 25)
actor_clusters <- tibble(actor = rownames(X), cluster = km_result$cluster)

# Save clusters BEFORE pruning so we can reuse them later
write.csv(actor_clusters, "actor_clusters_before_filter.csv", row.names = FALSE)

df$actor <- as.character(df$actor)
actor_clusters$actor <- as.character(actor_clusters$actor)

df_clustered <- df %>%
  left_join(actor_clusters, by = "actor")

write.csv(df_clustered, "output_clustered_pre_filter.csv", row.names = FALSE)

# STEP 2: Plot Markov per cluster (BEFORE Z-filter)
df_clustered$time_created <- ymd_hms(df_clustered$time_created)
grade_columns <- c("lab", "mid_1", "mid_2", "final_exam", "final_score")
df_clustered[grade_columns] <- lapply(df_clustered[grade_columns], function(x) as.numeric(gsub("%", "", x)))

df_plot_ready <- df_clustered %>%
  filter(!is.na(cluster), !is.na(action_code)) %>%
  select(session_id, time_created, action_code, cluster, actor, all_of(grade_columns))

all_clusters <- sort(unique(df_plot_ready$cluster))
cat("\n=== Markov Model BEFORE z-score filtering ===\n")
for (target_cluster in all_clusters) {
  cluster_data <- df_plot_ready %>%
    filter(cluster == target_cluster) %>%
    rename(CaseID = session_id, Timestamp = time_created, Event = action_code)

  if (nrow(cluster_data) > 0) {
    grade_avg <- cluster_data %>%
      summarise(across(all_of(grade_columns), ~ round(mean(.x, na.rm = TRUE), 2)))
    num_students <- cluster_data %>% select(actor) %>% distinct() %>% nrow()
    title_str <- paste0("Cluster ", target_cluster, ": ",
                        "Lab=", grade_avg$lab, ", MT1=", grade_avg$mid_1,
                        ", MT2=", grade_avg$mid_2, ", FinalExam=", grade_avg$final_exam,
                        ", FinalGrade=", grade_avg$final_score, ", N=", num_students)
    cat("\n====", title_str, "====\n\n")

    objDL <- dataLoader(verbose.mode = FALSE)
    objDL$load.data.frame(cluster_data,
                          IDName = "CaseID",
                          EVENTName = "Event",
                          dateColumnName = "Timestamp",
                          format.column.date = "%Y-%m-%d %H:%M:%S")
    fomm <- firstOrderMarkovModel(verbose.mode = FALSE)
    fomm$loadDataset(objDL$getData())
    fomm$trainModel()
    print(grViz(fomm$plot(giveItBack = TRUE)))

    if (target_cluster != max(all_clusters)) {
      readline(prompt = "Press [Enter] to continue...")
    }
  }
}

# Compute z-scores and plot z-score heatmap
flat_z <- reshape2::melt(as.matrix(transition_matrix))
colnames(flat_z) <- c("from", "to", "count")
flat_z$z_score <- scale(flat_z$count)

write.csv(flat_z, "flat_z.csv", row.names = FALSE)

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
flat_z$dropped <- ifelse(flat_z$z_score < 1.96, "Dropped", "Kept")
flat_z$valid <- ifelse(flat_z$dropped == "Dropped", NA, flat_z$count)

# Save dropped transitions to CSV
dropped_transitions <- flat_z %>%
  filter(dropped == "Dropped") %>%
  arrange(desc(count)) %>%
  select(from, to, count, z_score)

write.csv(dropped_transitions, "dropped_transitions.csv", row.names = FALSE)

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
    next_action = lead(action_code),
    prev_action = lag(action_code),
    transition_pair = paste(action_code, next_action, sep = " → "),
    reverse_pair = paste(prev_action, action_code, sep = " → "),
    drop_flag = (
      session_size == 1 |                                # drop sessions with only 1 action
        transition_pair %in% dropped_pairs |               # drop from-actions of dropped pairs
        (row_number() == n() & reverse_pair %in% dropped_pairs)  # drop last action if previous pair was dropped
    )
  ) %>%
  ungroup() %>%
  filter(!drop_flag) %>%
  select(-session_size, -next_action, -prev_action, -transition_pair, -reverse_pair, -drop_flag)

# Load original actor cluster assignments from before z-filtering
actor_clusters <- read.csv("actor_clusters_before_filter.csv", stringsAsFactors = FALSE)

# Ensure IDs are characters to match
df_pruned$actor <- as.character(df_pruned$actor)
actor_clusters$actor <- as.character(actor_clusters$actor)

# Reassign original clusters to pruned dataset
df_with_clusters <- df_pruned %>%
  left_join(actor_clusters, by = "actor")

# Save this dataset to use for Markov plotting
write.csv(df_with_clusters, "output_clustered_pruned_using_original_clusters.csv", row.names = FALSE)



# Save Z-pruned dataset before clustering
write.csv(df_pruned, "output_pruned.csv", row.names = FALSE)
# write.csv(df_pruned, "output_pruned_all_students.csv", row.names = FALSE)

# Build vectors for clustering
kept_actions <- unique(c(flat_z$from[flat_z$dropped == "Kept"], flat_z$to[flat_z$dropped == "Kept"]))

actor_vectors <- df_pruned %>%
  filter(action_code %in% kept_actions) %>%
  group_by(actor, action_code) %>%
  summarise(count = n(), .groups = "drop") %>%
  pivot_wider(names_from = action_code, values_from = count, values_fill = 0)

X <- actor_vectors %>% column_to_rownames("actor")
X <- X[complete.cases(X), ]
X <- X[!apply(X, 1, function(row) any(is.nan(row) | is.infinite(row))), ]
X <- X[rowSums(X) > 0, ]

# Elbow plot
fviz_nbclust(X, kmeans, method = "wss", k.max = 10) +
  labs(title = "Elbow Method")

# Silhouette analysis for k = 2 to 10
silhouette_scores <- c()

for (k in 2:10) {
  km_temp <- kmeans(X, centers = k, nstart = 25)
  sil <- silhouette(km_temp$cluster, dist(X))
  avg_sil <- mean(sil[, 3])
  silhouette_scores <- c(silhouette_scores, avg_sil)
}

# Plot silhouette scores
plot(2:10, silhouette_scores, type = "b", pch = 19,
     xlab = "Number of clusters (k)", ylab = "Average Silhouette Score",
     main = "Silhouette Analysis for K-Means")

# Print silhouette score for chosen k = 3
set.seed(42)
k_best <- 3
km_result <- kmeans(X, centers = k_best, nstart = 25)
sil_k3 <- silhouette(km_result$cluster, dist(X))
cat("✅ Average Silhouette Score for k = 3:", round(mean(sil_k3[, 3]), 4), "\n")


# Assign clusters
actor_clusters <- tibble(actor = rownames(X), cluster = km_result$cluster)
df_pruned$actor <- as.character(df_pruned$actor)
actor_clusters$actor <- as.character(actor_clusters$actor)

df_with_clusters <- df_pruned %>%
  left_join(actor_clusters, by = "actor")

# Save clustered dataset
# write.csv(df_with_clusters, "output_clustered.csv", row.names = FALSE)
write.csv(df_with_clusters, "output_clustered_all_students.csv", row.names = FALSE)

# ----- Markov Model Plot with Grade Averages -----
# df_clustered <- read.csv("output_clustered.csv", stringsAsFactors = FALSE)
# Load the z-pruned dataset with original clusters
df_clustered <- read.csv("output_clustered_pruned_using_original_clusters.csv", stringsAsFactors = FALSE)
df_clustered$time_created <- ymd_hms(df_clustered$time_created)

# Clean and convert grade columns
grade_columns <- c("lab", "mid_1", "mid_2", "final_exam", "final_score")
for (col in grade_columns) {
  if (col %in% colnames(df_clustered)) {
    df_clustered[[col]] <- as.numeric(gsub("%", "", df_clustered[[col]]))
  }
}

# Prepare session-level data
df_plot_ready <- df_clustered %>%
  filter(!is.na(cluster), !is.na(action_code)) %>%
  select(session_id, time_created, action_code, cluster, actor, all_of(grade_columns))

# Get list of clusters
all_clusters <- sort(unique(df_plot_ready$cluster))

for (target_cluster in all_clusters) {
  cluster_data <- df_plot_ready %>%
    filter(cluster == target_cluster) %>%
    rename(CaseID = session_id,
           Timestamp = time_created,
           Event = action_code)
  
  cluster_data$Timestamp <- ymd_hms(cluster_data$Timestamp)
  
  grade_avg <- cluster_data %>%
    summarise(across(all_of(grade_columns), ~ round(mean(.x, na.rm = TRUE), 2)))
  
  num_students <- cluster_data %>%
    select(actor) %>%
    distinct() %>%
    nrow()
  
  title_str <- paste0(
    "Cluster ", target_cluster, ": ",
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
    
    # Only pause if it's NOT the last cluster
    if (target_cluster != max(all_clusters)) {
      readline(prompt = "Press [Enter] to continue to the next cluster...")
    }
  } else {
    cat("⚠️  Cluster", target_cluster, "has no valid data.\n")
  }
}

# ----- Final Summary -----
overall_grade_avg <- df_plot_ready %>%
  summarise(across(all_of(grade_columns), ~ round(mean(.x, na.rm = TRUE), 2)))

overall_num_students <- df_plot_ready %>%
  select(actor) %>%
  distinct() %>%
  nrow()

# Print all final summary values in one line
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


# Markov plot without clustering
df_pruned_all <- read.csv("output_pruned.csv", stringsAsFactors = FALSE)
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
