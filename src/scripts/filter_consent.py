import csv
import sys
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path

csv.field_size_limit(sys.maxsize)

def filter_data_by_consent_script():
    actions_file_path = get_user_filepath_input("Enter the absolute path of your actions csv file: ")
    consent_file_path = get_user_filepath_input("Enter the absolute path of your consent csv file: ")
    teachers_file_path = get_user_filepath_input("Enter the absolute path of your teachers csv file: ")
    
    output_filename = add_stem_to_filename(actions_file_path, "filtered")
    output_file_path = get_output_file_path(output_filename)
    
    filter_data_by_consent(actions_file_path, consent_file_path, teachers_file_path, output_file_path)

def filter_data_by_consent(data_file, consent_file, teachers_file, output_file_path):
    with open(data_file, 'r') as inp, open(consent_file, 'r') as consent, open(teachers_file, 'r') as teachers, open(output_file_path, 'w') as out:
        consent_reader = csv.DictReader(consent)
        teachers_reader = csv.DictReader(teachers)
        consent_hashmap = []
        all_teachers = set()

        for row in teachers_reader:
            all_teachers.add(row["last_name"])

        for row in consent_reader:
            if row["legal_last_name"] not in all_teachers and row["consent"] == 'True':
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
        unique_consented_users = set()
        unique_omitted_users = set()

        for row in reader:
            total_rows += 1
            if id_field in row and row[id_field] in consent_hashmap:
                consented_rows += 1
                unique_consented_users.add(row[id_field])
                writer.writerow(row)
            else:
                omitted_rows += 1
                unique_omitted_users.add(row[id_field])

        print(f"Total rows: {total_rows}")
        print(f"Consented and non-admin rows: {consented_rows}")
        print(f"Omitted rows: {omitted_rows}")
        print(f"Total users: {len(unique_consented_users) + len(unique_omitted_users)}")
        print(f"Total consented students: {len(unique_consented_users)}")
        print(f"Total omitted users: {len(unique_omitted_users)}")
                
if __name__ == "__main__":
    filter_data_by_consent_script()