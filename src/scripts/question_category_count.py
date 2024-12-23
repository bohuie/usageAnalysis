import pandas as pd
import json
from src.util.filepath_helpers import get_output_file_path
from src.util.filepath_helpers import get_user_filepath_input

def questions_analysis():
    questions_json_file_path = get_user_filepath_input("Enter the absolute path of your questions json file: ")
    analysis(questions_json_file_path)

def analysis(questions_json_file_path):
    questions_file = open(questions_json_file_path)
    questions_json = json.load(questions_file)
    questions_df = pd.json_normalize(questions_json['questions'])

    file_name = "questions_per_concept_and_type.csv"
    verified_questions_df = questions_df[questions_df["is_verified"] == True].groupby(['parent_category_name', 'category_name', 'type_name']).size().to_frame('count')
    verified_questions_df.to_csv(get_output_file_path(file_name), sep='\t')
    print(verified_questions_df['count'].sum())

if __name__ == "__main__":
    questions_analysis()