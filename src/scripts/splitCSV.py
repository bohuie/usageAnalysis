import pandas as pd
import os

def split_csv(file_path, max_rows=20500):
    # Load the CSV
    df = pd.read_csv(file_path)
    
    # Get output directory
    base_dir = os.path.dirname(file_path)
    base_name = os.path.splitext(os.path.basename(file_path))[0]
    
    # Split into chunks
    total_rows = len(df)
    num_files = (total_rows // max_rows) + (1 if total_rows % max_rows != 0 else 0)
    
    print(f"Total rows: {total_rows}")
    print(f"Splitting into {num_files} files...")

    for i in range(num_files):
        start = i * max_rows
        end = min((i+1) * max_rows, total_rows)
        chunk = df.iloc[start:end]
        
        output_file = os.path.join(base_dir, f"{base_name}_part{i+1}.csv")
        chunk.to_csv(output_file, index=False)
        
        print(f"Saved {output_file} ({len(chunk)} rows)")

if __name__ == "__main__":
    file_path = input("Enter the absolute path of your CSV file: ").strip()
    split_csv(file_path)
