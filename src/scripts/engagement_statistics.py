import pandas as pd
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path

GRADE_LEVELS = {
    "A+": 90,
    "A": 85,
    "A-": 80,
    "B+": 76,
    "B": 72,
    "B-": 68,
    "C+": 64,
    "C": 60,
    "C-": 55,
    "D": 50,
    "F": 0
}

def filter_engagement_script():
    attempts_file_path = get_user_filepath_input("Enter the absolute path of attempts csv file: ")
    output_filename = add_stem_to_filename(attempts_file_path, "engagement")

    grades_file_path = get_user_filepath_input("Enter the absolute path of attempts csv file: ")

    consent_file_path = get_user_filepath_input("Enter the absolute path of attempts csv file: ")

    output_file_path = get_output_file_path(output_filename)
    
    filter_engagement(attempts_file_path, grades_file_path, consent_file_path, output_file_path)

def filter_engagement(attempts_file_path, grades_file_path, consent_file_path, output_file_path):
    attempts_data = pd.read_csv(attempts_file_path)
    grades_data = pd.read_csv(grades_file_path)
    consent_data = pd.read_csv(consent_file_path)
            
    # print(data.head())

if __name__ == "__main__":
    filter_engagement_script()