import pandas as pd

# Read the CSV
df = pd.read_csv("/Users/adarasharmilaputri/Desktop/Coding/Work/usageAnalysis_REAL/skipped_questions_with_groups.csv")

# The group columns you want to check
group_columns = ["grade_group", "gender_group", "fluctuation_group1", "fluctuation_group2"]

# Loop through each grouping column
for group_col in group_columns:
    print(f"\n--- Counts by {group_col} ---")
    
    # Group by the current column and name, count occurrences
    grouped = df.groupby([group_col, "name"]).size().reset_index(name="count")
    
    # For each value in the group column (e.g., A, B, C, etc. for grade_group)
    for group_value in grouped[group_col].unique():
        subset = grouped[grouped[group_col] == group_value]
        
        # Format like: A: Basics - 5, OOP - 3
        counts_str = ", ".join([f"{row['name']} - {row['count']}" for _, row in subset.iterrows()])
        print(f"{group_value}: {counts_str}")
