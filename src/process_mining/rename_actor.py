import pandas as pd
from datetime import datetime, date

# Read the CSV file
df = pd.read_csv("data/input.csv")

# Drop rows with missing time_created
df = df.dropna(subset=['time_created'])

# Function to extract just the date part from time_created
def get_date_only(time_str):
    if isinstance(time_str, str) and len(time_str) >= 10:
        try:
            return datetime.strptime(time_str[:10], "%Y-%m-%d").date()
        except ValueError:
            return None
    return None

# Define the date ranges
ranges = {
    388: [
        (date(2023, 1, 9), date(2023, 4, 30), 3881),
        (date(2023, 9, 5), date(2023, 12, 22), 3883)
    ],
    500: [
        (date(2023, 1, 9), date(2023, 4, 30), 5001),
        (date(2023, 5, 15), date(2023, 7, 6), 5002)
    ],
    525: [
        (date(2023, 5, 15), date(2023, 7, 6), 5252),
        (date(2023, 9, 5), date(2023, 12, 22), 5253)
    ],
    473: [
        (date(2023, 1, 9), date(2023, 4, 30), 4731),
        (date(2023, 5, 15), date(2023, 7, 6), 4732),
        (date(2023, 9, 5), date(2023, 12, 22), 4733)
    ]
}

# Function to update actor based on date ranges
def rename_actor(row):
    actor = row['actor']
    time_created = row['time_created']
    date_only = get_date_only(time_created)
    
    if pd.isna(actor) or date_only is None:
        return actor  # leave unchanged if invalid

    if actor in ranges:
        for start, end, new_val in ranges[actor]:
            if start <= date_only <= end:
                return new_val
    return actor

# Apply the transformation
df['actor'] = df.apply(rename_actor, axis=1)

# Save the modified dataframe
df.to_csv("data/new_input.csv", index=False)