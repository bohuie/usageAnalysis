import os
from dotenv import load_dotenv
import pandas as pd
import json
from src.util.filepath_helpers import get_output_file_path

load_dotenv()

def analysis():
    questions_file = open()
    questions_file = open(os.environ.get("QUESTIONS_JSON_FILEPATH"))
    questions_json = json.load(questions_file)
    questions_df = pd.json_normalize(questions_json['questions'])

    file_name = "questions_per_concept_and_type.csv"
    questions_df.groupby(['parent_category_name', 'category_name', 'type_name']).size().to_csv(get_output_file_path(file_name), sep='\t')

if __name__ == "__main__":
    analysis()