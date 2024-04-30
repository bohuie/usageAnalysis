import pandas as pd
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path

def filter_engagement_script():
    attempts_file_path = get_user_filepath_input("Enter the absolute path of attempts csv file: ")
    output_filename = add_stem_to_filename(attempts_file_path, "engagement")
    output_file_path = get_output_file_path(output_filename)
    
    filter_engagement(attempts_file_path, output_file_path)

def filter_engagement(data_file_path, output_file_path):
    data = pd.read_csv(data_file_path)
    
    total = data.groupby(['actor','question.parent_category_name', 'question.category_name', 'question.type_name', 'question.id']).size().reset_index(name='counts')
    total['accuracy'] = pd.Series(dtype='float')

    correct = data[data['data.status'] == "Correct"].groupby(['actor','question.parent_category_name', 'question.category_name', 'question.type_name', 'question.id']).size().reset_index(name='correctcounts')

    for index, row in total.iterrows():
        correctrow = correct[(correct['actor'] == row['actor']) & (correct['question.parent_category_name'] == row['question.parent_category_name']) & (correct['question.category_name'] == row['question.category_name']) & (correct['question.type_name'] == row['question.type_name']) & (correct['question.id'] == row['question.id'])]
        if len(correctrow['correctcounts'].values) >= 1 :
            total.at[index, 'accuracy'] = int(correctrow['correctcounts'])/int(row['counts'])
        else:
            total.at[index, 'accuracy'] = 0
            
    total.to_csv(output_file_path, sep=',')

if __name__ == "__main__":
    filter_engagement_script()