import pandas as pd
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path

def filter_engagement_script():
    attempts_file_path = get_user_filepath_input("Enter the absolute path of attempts csv file: ")
    output_filename = add_stem_to_filename(attempts_file_path, "engagement")
    output_file_path = get_output_file_path(output_filename)
    
    filter_engagement(attempts_file_path, output_file_path)

def filter_engagement(data_file_path, output_file_path):
    print("[INFO] Starting data processing...")
    
    # Specify the dtype for the third column (index 2) as string
    data = pd.read_csv(data_file_path, dtype={2: str})
    print(f"[INFO] Successfully read {len(data)} rows from the input CSV file.")
    
    print("[INFO] Grouping data and calculating total attempts per question...")
    total = data.groupby(['actor','question.parent_category_name', 'question.category_name', 'question.type_name', 'question.id']).size().reset_index(name='counts')
    total['accuracy'] = pd.Series(dtype='float')

    correct = data[data['data.status'] == "Correct"].groupby(['actor','question.parent_category_name', 'question.category_name', 'question.type_name', 'question.id']).size().reset_index(name='correctcounts')

    print("[INFO] Calculating accuracy for each group...")
    num_rows_to_process = len(total)

    # Create a temporary DataFrame for the "parsons" and "java" questions
    test_based_questions = data[data['question.type_name'].isin(['parsons question', 'java question'])].copy()
    test_based_questions['total_tests'] = test_based_questions['num_passed_tests'] + test_based_questions['num_failed_tests']

    # Filter for questions with at least one test
    test_based_questions = test_based_questions[test_based_questions['total_tests'] > 0]
    
    # Group by the specified columns and calculate the mean of 'num_passed_tests' and the mean of 'total_tests'
    test_based_agg = test_based_questions.groupby(['actor', 'question.parent_category_name', 'question.category_name', 'question.type_name', 'question.id']).agg(
        avg_passed_tests=('num_passed_tests', 'mean'),
        avg_total_tests=('total_tests', 'mean')
    ).reset_index()

    # Iterate through the main 'total' DataFrame
    for index, row in total.iterrows():
        is_parsons_or_java = row['question.type_name'] in ['parsons question', 'java question']

        if is_parsons_or_java:
            # Find the corresponding data in the aggregated DataFrame
            test_row = test_based_agg[
                (test_based_agg['actor'] == row['actor']) & 
                (test_based_agg['question.id'] == row['question.id'])
            ]
            
            if not test_row.empty and test_row.iloc[0]['avg_total_tests'] > 0:
                # Use the test-based calculation
                accuracy = test_row.iloc[0]['avg_passed_tests'] / test_row.iloc[0]['avg_total_tests']
                total.at[index, 'accuracy'] = accuracy
            else:
                # If no test data or total tests is 0, default to 0
                total.at[index, 'accuracy'] = 0

        else:
            # Keep the original accuracy calculation for other question types
            correct_row = correct[
                (correct['actor'] == row['actor']) & 
                (correct['question.parent_category_name'] == row['question.parent_category_name']) & 
                (correct['question.category_name'] == row['question.category_name']) & 
                (correct['question.type_name'] == row['question.type_name']) & 
                (correct['question.id'] == row['question.id'])
            ]
            if not correct_row.empty:
                total.at[index, 'accuracy'] = int(correct_row['correctcounts'].iloc[0]) / int(row['counts'])
            else:
                total.at[index, 'accuracy'] = 0

        # Add a progress print statement here
        if (index + 1) % 1000 == 0 or (index + 1) == num_rows_to_process:
            print(f"[PROGRESS] Processed {index + 1}/{num_rows_to_process} rows.")

    print("[INFO] Accuracy calculation complete.")
    
    print(f"[INFO] Writing results to {output_file_path}...")
    total.to_csv(output_file_path, sep=',')

    print("[SUCCESS] Data processing is complete and the output file has been saved.")

if __name__ == "__main__":
    filter_engagement_script()