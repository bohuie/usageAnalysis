import csv
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path

csv.field_size_limit(1000000)

def filter_submissions_only_script():
    actions_file_path = get_user_filepath_input("Enter the absolute path of your filtered consent csv file: ")
    
    output_filename = add_stem_to_filename(actions_file_path, "filtered")
    output_file_path = get_output_file_path(output_filename)
    
    print(f"Input file: {actions_file_path}")
    print(f"Output will be saved to: {output_file_path}")
    
    filter_submissions_only(actions_file_path, output_file_path)
    print("Filtering complete!")

def filter_submissions_only(data_file, output_file_path):
    with open(data_file, 'r', encoding='utf-8-sig') as inp, open(output_file_path, 'w', newline='') as out:
        reader = csv.DictReader(inp)
        writer = csv.DictWriter(out, fieldnames=reader.fieldnames)
        writer.writeheader()
        
        total_rows = 0
        kept_rows = 0

        for row in reader:
            total_rows += 1
            if row['object_type'] == 'Submission' and row['description'] == 'Submission was evaluated':
                writer.writerow(row)
                kept_rows += 1

            if total_rows % 100 == 0:
                print(f"Processed {total_rows} rows... kept {kept_rows}")

        print(f"Done! Processed {total_rows} total rows, kept {kept_rows} submissions.")

if __name__ == "__main__":
    filter_submissions_only_script()
