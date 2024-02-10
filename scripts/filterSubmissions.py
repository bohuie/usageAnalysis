import csv
import sys
from pathlib import Path

csv.field_size_limit(sys.maxsize)

def filter_submissions_script():
    print("Enter the absolute path of your actions csv file: ", end="")
    actions_file_path = Path(input())
    if not actions_file_path.exists():
        raise Exception("Invalid path")
    
    output_filename = Path(Path(actions_file_path.name).stem + "_submissions.csv")
    project_root_file_path = Path(__file__).parent.parent
    output_file_path = project_root_file_path / "data" / output_filename
    
    filter_submissions(actions_file_path, output_file_path)

def filter_submissions(data_file, output_file_path):
    with open(data_file, 'r') as inp, open(output_file_path, 'w') as out:
        reader = csv.DictReader(inp)
        writer = csv.DictWriter(out, reader.fieldnames)
        writer.writeheader()
        for row in reader:
            if row['object_type'] == 'Submission' and row['description'] == 'Submission was evaluated':
                writer.writerow(row)
                
if __name__ == "__main__":
    filter_submissions_script()