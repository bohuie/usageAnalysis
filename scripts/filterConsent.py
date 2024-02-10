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
        consent_hashmap = {}
        for row in consent_reader:
            if row["consent"] == 'True':
                consent_hashmap[row["user"]] = [row["legal_first_name"], row["legal_last_name"]]
            if row["consent"] == 'False' and row["user"] in consent_hashmap:
                del consent_hashmap[row["user"]]
        reader = csv.DictReader(inp)
        writer = csv.DictWriter(out, ["legal_first_name", "legal_last_name"] + reader.fieldnames)
        writer.writeheader()

        id_field = ""
        id_array = ["actor", "user", "user_id"]
        for id in id_array:
            if id in reader.fieldnames:
                id_field = id
                break

        for row in reader:
            if id_field in row and row[id_field] in consent_hashmap:
                row["legal_first_name"] = consent_hashmap[row[id_field]][0] if consent_hashmap[row[id_field]][0] else "anonymous"
                row["legal_last_name"] = consent_hashmap[row[id_field]][1] if consent_hashmap[row[id_field]][1] else "anonymous"
                writer.writerow(row)
                
if __name__ == "__main__":
    filter_data_by_consent_script()