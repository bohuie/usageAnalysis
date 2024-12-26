import csv
import pandas as pd
import sys
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path

csv.field_size_limit(1000000)

def filter_data_by_consent_script():
    gradebook_filepath = get_user_filepath_input("Enter the absolute path of your gradebook csv file: ")
    consent_file_path = get_user_filepath_input("Enter the absolute path of your consent csv file: ")
    
    output_filename = add_stem_to_filename(gradebook_filepath, "filtered")
    output_file_path = get_output_file_path(output_filename)
    
    filter_data_by_consent(gradebook_filepath, consent_file_path, output_file_path)

def filter_data_by_consent(gradebook_filepath, consent_file, output_file_path):
    gradebook_data = pd.read_csv(gradebook_filepath)
    consent_data = pd.read_csv(consent_file)

    student_number_fields = ["student_number", "Student Number"]

    for student_number_field in student_number_fields:
        if student_number_field in gradebook_data.columns:
            break
    
    consent_hashset = set()
    student_number_map = {}
    for _, row in consent_data.iterrows():
        try:
            student_number = int(row["student_number"])
        except Exception as e:
            continue
        if row["consent"] and row["access_course_grades"] and row["access_submitted_course_work"] and row["student_number"] is not None and row["student_number"] != "":
            student_number_map[student_number] = row["user"]
            consent_hashset.add(student_number)
        else:
            consent_hashset.discard(student_number)

    gradebook_data = gradebook_data.dropna(subset=[student_number_field])
    gradebook_data[student_number_field] = gradebook_data[student_number_field].astype(int)
    filtered_gradebook_data = gradebook_data[gradebook_data[student_number_field].isin(consent_hashset)]
    
    actor_column = []
    for _, row in filtered_gradebook_data.iterrows():
        actor_column.append(student_number_map[row[student_number_field]])

    filtered_gradebook_data = filtered_gradebook_data.assign(user=actor_column)
    filtered_gradebook_data.to_csv(output_file_path, index=False)
                
if __name__ == "__main__":
    filter_data_by_consent_script()