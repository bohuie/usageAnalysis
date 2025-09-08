import pandas as pd
import json
from src.util.filepath_helpers import get_output_file_path
from src.util.filepath_helpers import get_user_filepath_input

VARIATION_TYPES = [
    "Variable Name Change",
    "Function Name Change",
    "Method Parameter Order Change",
    "Constant Change",
    "Polarity Reverse",
    "Data Type Change",
    "No Variations",
    "Console Output Format Change",
    "Question Text Change",
]

def questions_analysis():
    questions_json_file_path = get_user_filepath_input("Enter the absolute path of your questions json file: ")
    analysis(questions_json_file_path)

def analysis(questions_json_file_path):
    questions_file = open(questions_json_file_path)
    questions_json = json.load(questions_file)
    for question in questions_json['questions']:
        for variation_type in VARIATION_TYPES:
            if variation_type in question["variation_types"]:
                question[variation_type] = True
            else:
                question[variation_type] = False
        
        if not question["variation_types"]:
            question["Not Logged"] = True
        else:
            question["Not Logged"] = False
    
    questions_df = pd.json_normalize(questions_json['questions'])

    file_name = "question_variation_count.csv"

    aggregation = {'Not Logged': 'sum'}
    for variation_type in VARIATION_TYPES:
        aggregation[variation_type] = 'sum'
    
    verified_questions_df = questions_df[questions_df["is_verified"] == True].groupby(['parent_category_name', 'category_name', 'type_name']).agg(aggregation)

    verified_questions_df.to_csv(get_output_file_path(file_name), sep='\t')
    

if __name__ == "__main__":
    questions_analysis()