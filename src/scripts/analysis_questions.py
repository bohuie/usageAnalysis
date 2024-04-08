import os
from dotenv import load_dotenv
import pandas as pd
import json
from src.util.filepath_helpers import get_output_file_path
from src.util.filepath_helpers import get_user_filepath_input

load_dotenv()

def questions_analysis():
    questions_json_file_path = get_user_filepath_input("Enter the absolute path of your questions json file: ")
    analysis(questions_json_file_path)

def analysis(questions_json_file_path):
    questions_file = open(questions_json_file_path)
    questions_json = json.load(questions_file)
    questions_df = pd.json_normalize(questions_json['questions'])

    file_name = "questions_per_concept_and_type.csv"
    questions_df.groupby(['parent_category_name', 'category_name', 'type_name']).size().to_csv(get_output_file_path(file_name), sep='\t')

if __name__ == "__main__":
    questions_analysis()