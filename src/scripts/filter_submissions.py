import csv
import sys
from datetime import datetime
from pathlib import Path
import requests
from dotenv import load_dotenv
import os
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path

csv.field_size_limit(1000000)

def filter_submissions_script():
    actions_file_path = get_user_filepath_input("Enter the absolute path of your filtered consent csv file: ")
    
    output_filename = add_stem_to_filename(actions_file_path, "submissions")
    output_file_path = get_output_file_path(output_filename)
    
    filter_submissions(actions_file_path, output_file_path)

def filter_submissions(data_file, output_file_path):
    with open(data_file, 'r', encoding='utf-8-sig') as inp, open(output_file_path, 'w') as out:
        submission_column_names = ["actor", "data.status", "object_id", "time_created"]
        concept_column_names = ["question.type_name", "question.parent_category_name", "question.category_name"]
        question_column_names = ["question.id", "question.difficulty", "question.event_obj.name", "question.is_practice", "question.is_exam"]
        tests_column_names = ["get_passed_test_results", "get_failed_test_results", "num_passed_tests", "num_failed_tests"]
        
        column_names = question_column_names + submission_column_names + concept_column_names + tests_column_names

        reader = csv.DictReader(inp)
        writer = csv.DictWriter(out, column_names)
        writer.writeheader()

        gamification_api_url, gamification_token = get_gamification_secrets()

        rows_to_sort = []
        for row in reader:
            if row['object_type'] == 'Submission' and row['description'] == 'Submission was evaluated':
                
                # remove unwanted columns
                for key in list(row):
                    if key not in column_names:
                        del row[key]

                submission_details = get_submissions_details_from_id(gamification_api_url=gamification_api_url, gamification_token=gamification_token, submission_id=int(row['object_id']))

                # concept/category fields
                row["question.type_name"] = get_submission_details_field(submission_details, ["question", "type_name"])
                row["question.parent_category_name"] = get_submission_details_field(submission_details, ["question", "parent_category_name"])
                row["question.category_name"] = get_submission_details_field(submission_details, ["question", "category_name"])

                # question fields
                row["question.id"] = get_submission_details_field(submission_details, ["question", "id"])
                row["question.difficulty"] = get_submission_details_field(submission_details, ["question", "difficulty"])
                row["question.event_obj.name"] = get_submission_details_field(submission_details, ["question", "event_obj", "name"])
                row["question.is_practice"] = get_submission_details_field(submission_details, ["question", "is_practice"])
                row["question.is_exam"] = get_submission_details_field(submission_details, ["question", "is_exam"])

                # tests fields
                passed_test = get_submission_details_field(submission_details, ["get_passed_test_results"])
                failed_test = get_submission_details_field(submission_details, ["get_failed_test_results"])
                row["get_passed_test_results"] = passed_test
                row["get_failed_test_results"] = failed_test
                row["num_passed_tests"] = len(passed_test)
                row["num_failed_tests"] = len(failed_test)

                rows_to_sort.append(row)

        sorted_rows = sorted(rows_to_sort, key=lambda x: ( x["question.id"],x["actor"],datetime.fromisoformat(x["time_created"])))
    
        for row in sorted_rows:
            writer.writerow(row)

def get_submission_details_field(submission_details: dict, field_path: list):
    try:
        temp = submission_details
        for field in field_path:
            temp = temp[field]
        return temp
    except KeyError:
        return ""

def get_gamification_secrets():
    load_dotenv()
    try:
        gamification_api_url = os.environ.get("GAMIFICATION_API_URL")
        gamification_token = os.environ.get("GAMIFICATION_TOKEN")
    except Exception as e:
        raise Exception("Environment variables not set")

    return gamification_api_url, gamification_token

def get_submissions_details_from_id(gamification_api_url: str, gamification_token: str, submission_id: int):
    res = requests.get(
        url=f"{gamification_api_url}/submission/{str(submission_id)}/",
        headers={
            "accept": "application/json",
            'Authorization': f'Token {gamification_token}'
    })

    return res.json()
        
if __name__ == "__main__":
    filter_submissions_script()