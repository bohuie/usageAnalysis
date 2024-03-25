import os
import csv
from dotenv import load_dotenv
import pandas as pd
import json
import pathlib
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path
def filter_engagement_script():
    

    actions_file_path = pathlib.Path("/Users/jayati/usageAnalysis-1/data/Jan2023-actions_filtered_submissions_attempts.csv")
    # get_user_filepath_input("Enter the absolute path of your filtered consent csv file: ")
    output_filename = add_stem_to_filename(actions_file_path, "engagement")
    output_file_path = get_output_file_path(output_filename)
    
    filter_engagement(actions_file_path, output_file_path)

def filter_engagement(data_file_path, output_file_path):
    data = pd.read_csv(data_file_path)
    
    total = data.groupby(['actor','question.parent_category_name', 'question.category_name', 'question.type_name', 'question.id']).size().reset_index(name='counts')
    correct = data[data['data.status'] == "Correct"].groupby(['actor','question.parent_category_name', 'question.category_name', 'question.type_name', 'question.id']).size().reset_index(name='correctcounts')
    for index, row in total.iterrows():
        correctrow = correct[(correct['actor'] == row['actor']) & (correct['question.parent_category_name'] == row['question.parent_category_name']) & (correct['question.category_name'] == row['question.category_name']) & (correct['question.type_name'] == row['question.type_name']) & (correct['question.id'] == row['question.id'])]
        if correctrow['correctcounts'].values :
            row['counts'] = int(correctrow['correctcounts'])/int(row['counts'])
        else:
            row['counts'] = 0
    total.to_csv(get_output_file_path("test3.csv"), sep=',')
#user, parent, child, type, question id, accuracy, num of attempts
#take the data, aggregate everything per concept 


if __name__ == "__main__":
    filter_engagement_script()