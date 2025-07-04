import pandas as pd
import math

df = pd.read_csv("flat_z.csv")
counts = df["count"].astype(float)

# Z-score calculation (mean, std dev)
mean_count = sum(counts) / len(counts)
squared_diffs = [(x - mean_count) ** 2 for x in counts]
std_dev = math.sqrt(sum(squared_diffs) / (len(counts) - 1))
df["z_python"] = df["count"].apply(lambda x: (x - mean_count) / std_dev if std_dev != 0 else 0)

# Compare with original z-score
for i, row in df.iterrows():
    original = round(row["z_score"], 6)
    manual = round(row["z_python"], 6)
    if original != manual:
        print(f"Mismatch at row {i}: z_score={original}, z_python={manual}")
        break
else:
    print("All z-scores match.")

df.to_csv("checked.csv", index=False)