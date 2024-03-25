import os
import csv
from dotenv import load_dotenv
import pandas as pd
import json
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path

def filter_engagement_script():
    actions_file_path = get_user_filepath_input("Enter the absolute path of your filtered consent csv file: ")
    
    output_filename = add_stem_to_filename(actions_file_path, "engagement")
    output_file_path = get_output_file_path(output_filename)
    
    filter_engagement(actions_file_path, output_file_path)

def filter_engagement(data_file_path, output_file_path):
    data = pd.read_csv(data_file_path)
    print(data)

#user, parent, child, type, question id, accuracy, num of attempts
#take the data, aggregate everything per concept 


if __name__ == "__main__":
    filter_engagement_script()