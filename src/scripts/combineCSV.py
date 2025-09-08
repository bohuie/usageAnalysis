import csv

# List your 5 CSV files here (in order you want to combine them)
input_files = [
    "data/actions_22_25_filtered_part1_submissions.csv",
    "data/actions_22_25_filtered_part2_submissions.csv",
    "data/actions_22_25_filtered_part3_submissions.csv",
    "data/actions_22_25_filtered_part4_submissions.csv",
    "data/actions_22_25_filtered_part5_submissions.csv"
]

# Output file name
output_file = "data/actions_22_25_filtered_submissions.csv"

with open(output_file, "w", newline="", encoding="utf-8") as outfile:
    writer = None
    
    for i, infile_name in enumerate(input_files):
        with open(infile_name, "r", newline="", encoding="utf-8") as infile:
            reader = csv.reader(infile)
            header = next(reader)  # read header row
            
            # Initialize writer with header from the first file only
            if writer is None:
                writer = csv.writer(outfile)
                writer.writerow(header)
            
            # Write the rest of the rows
            for row in reader:
                writer.writerow(row)

print(f"Combined {len(input_files)} files into {output_file}")
