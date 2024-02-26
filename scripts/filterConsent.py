import csv
import sys
from pathlib import Path

csv.field_size_limit(sys.maxsize)

def filter_data_by_consent_script():
    print("Enter the absolute path of your actions csv file: ", end="")
    actions_file_path = Path(input())
    if not actions_file_path.exists():
        raise Exception("Invalid path")

    print("Enter absolute path of your consent csv file: ", end="")
    consent_file_path = Path(input())
    if not consent_file_path.exists():
        raise Exception("Invalid path")
    
    output_filename = Path(Path(actions_file_path.name).stem + "_filtered.csv")
    project_root_file_path = Path(__file__).parent.parent
    output_file_path = project_root_file_path / "data" / output_filename
    
    filter_data_by_consent(actions_file_path, consent_file_path, output_file_path)

def filter_data_by_consent(data_file, consent_file, output_file_path):
    with open(data_file, 'r') as inp, open(consent_file, 'r') as consent, open(output_file_path, 'w') as out:
        consent_reader = csv.DictReader(consent)
        consent_hashmap = []
        for row in consent_reader:
            if row["consent"] == 'True':
                consent_hashmap.append(row["user"])
            if row["consent"] == 'False' and row["user"] in consent_hashmap:
                consent_hashmap.remove(row["user"])
        reader = csv.DictReader(inp)
        writer = csv.DictWriter(out, reader.fieldnames)
        writer.writeheader()

        id_field = ""
        id_array = ["actor", "user", "user_id"]
        for id in id_array:
            if id in reader.fieldnames:
                id_field = id
                break

        total_rows = 0
        consented_rows = 0
        omitted_rows = 0
        for row in reader:
            total_rows += 1
            if id_field in row and row[id_field] in consent_hashmap:
                consented_rows += 1
                writer.writerow(row)
            else:
                omitted_rows += 1

        print(f"Total rows: {total_rows}")
        print(f"Consented rows: {consented_rows}")
        print(f"Omitted rows: {omitted_rows}")
                
if __name__ == "__main__":
    filter_data_by_consent_script()