import os
import csv
import sys
from src.util.filepath_helpers import get_user_filepath_input, get_output_file_path

csv.field_size_limit(1000000)

SESSION_GRADE_COLUMN_MAP = {
    'S2023T1': ['Best'],
    'W2022T2': ['Final Grade Percent'],
    'W2023T1': ['Total', 'Total( Percentage ) (1733154)', 'Unofficial Final Total (1732073)']
}

def generate_final_grades_script():
    folder_path = get_user_filepath_input("Enter the absolute path of the folder containing outputs from filter_gradebook.py: ")
    
    if not os.path.isdir(folder_path):
        print("Invalid folder path.")
        sys.exit(1)

    output_data = []

    for filename in os.listdir(folder_path):
        file_path = os.path.join(folder_path, filename)
        if os.path.isfile(file_path) and filename.endswith('.csv'):
            session = extract_session_from_filename(filename)
            print(f"Processing file: {filename} for session: {session}")
            file_data = extract_grades_from_file(file_path, session)
            output_data.extend(file_data)

    output_file_path = get_output_file_path("final_grades_combined.csv")
    output_data.sort(key=lambda x: x['actor_id'])

    with open(output_file_path, 'w', encoding="utf8", newline='') as out:
        writer = csv.DictWriter(out, fieldnames=['actor_id', 'session', 'grade'])
        writer.writeheader()
        writer.writerows(output_data)


    print(f"Finished writing combined grades to {output_file_path}")

def extract_session_from_filename(filename):
    for session_tag in SESSION_GRADE_COLUMN_MAP.keys():
        if session_tag in filename:
            return session_tag
    return 'Unknown'

def extract_grades_from_file(file_path, session):
    data = []
    with open(file_path, 'r', encoding="utf8") as inp:
        reader = csv.DictReader(inp)
        grade_column = identify_grade_column(reader.fieldnames, session)
        if not grade_column:
            print(f"No valid grade column found for session {session} in {file_path}")
            return data

        for row in reader:
            actor_id = row.get('user')
            grade = row.get(grade_column)
            if actor_id and grade:
                data.append({
                    'actor_id': actor_id,
                    'session': session,
                    'grade': grade
                })
    return data

def identify_grade_column(fieldnames, session):
    possible_columns = SESSION_GRADE_COLUMN_MAP.get(session, [])
    for col in possible_columns:
        if col in fieldnames:
            return col
    return None

if __name__ == "__main__":
    generate_final_grades_script()