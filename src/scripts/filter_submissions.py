import os
import requests
from datetime import datetime
from dotenv import load_dotenv
import polars as pl
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path

def filter_submissions_script():
    actions_file_path = get_user_filepath_input("Enter the absolute path of your filtered consent csv file: ")

    output_filename = add_stem_to_filename(actions_file_path, "submissions")
    output_file_path = get_output_file_path(output_filename)

    filter_submissions(actions_file_path, output_file_path)

def filter_submissions(data_file, output_file_path):
    submission_column_names = ["actor", "data.status", "object_id", "time_created"]
    concept_column_names = ["question.type_name", "question.parent_category_name", "question.category_name"]
    question_column_names = [
        "question.id", "question.difficulty", "question.event_obj.name",
        "question.is_practice", "question.is_exam"
    ]
    tests_column_names = [
        "get_passed_test_results", "get_failed_test_results",
        "num_passed_tests", "num_failed_tests"
    ]
    column_names = question_column_names + submission_column_names + concept_column_names + tests_column_names

    print("Reading CSV with Polars...")
    df = pl.read_csv(data_file, ignore_errors=True)

    # Filter only needed rows
    print("Filtering relevant submissions...")
    df = df.filter(
        (pl.col("object_type") == "Submission") &
        (pl.col("description") == "Submission was evaluated")
    )

    gamification_api_url, gamification_token = get_gamification_secrets()

    print(f"Processing {df.height} matching rows...")
    rows = []
    for idx, row in enumerate(df.iter_rows(named=True), start=1):
        # Keep only required columns first
        clean_row = {key: row.get(key, "") for key in column_names}

        # API call for submission details
        submission_details = get_submissions_details_from_id(
            gamification_api_url, gamification_token, int(row["object_id"])
        )

        # Fill concept/category fields
        clean_row["question.type_name"] = get_submission_details_field(submission_details, ["question", "type_name"])
        clean_row["question.parent_category_name"] = get_submission_details_field(submission_details, ["question", "parent_category_name"])
        clean_row["question.category_name"] = get_submission_details_field(submission_details, ["question", "category_name"])

        # Question fields
        clean_row["question.id"] = get_submission_details_field(submission_details, ["question", "id"])
        clean_row["question.difficulty"] = get_submission_details_field(submission_details, ["question", "difficulty"])
        clean_row["question.event_obj.name"] = get_submission_details_field(submission_details, ["question", "event_obj", "name"])
        clean_row["question.is_practice"] = get_submission_details_field(submission_details, ["question", "is_practice"])
        clean_row["question.is_exam"] = get_submission_details_field(submission_details, ["question", "is_exam"])

        # Tests fields
        passed_test = get_submission_details_field(submission_details, ["get_passed_test_results"])
        failed_test = get_submission_details_field(submission_details, ["get_failed_test_results"])
        clean_row["get_passed_test_results"] = passed_test
        clean_row["get_failed_test_results"] = failed_test
        clean_row["num_passed_tests"] = len(passed_test) if isinstance(passed_test, list) else 0
        clean_row["num_failed_tests"] = len(failed_test) if isinstance(failed_test, list) else 0

        rows.append(clean_row)

        # Progress print every 500 rows
        if idx % 500 == 0:
            print(f"  Processed {idx}/{df.height} rows...")

    print("Sorting results...")
    result_df = pl.DataFrame(rows).sort(
        by=["question.id", "actor", "time_created"],
        descending=[False, False, False]
    )

    print(f"Writing output CSV to {output_file_path}...")
    result_df.write_csv(output_file_path)
    print("Done!")

def get_submission_details_field(submission_details: dict, field_path: list):
    try:
        temp = submission_details
        for field in field_path:
            temp = temp[field]
        return temp
    except (KeyError, TypeError):
        return ""

def get_gamification_secrets():
    load_dotenv()
    gamification_api_url = os.environ.get("GAMIFICATION_API_URL")
    gamification_token = os.environ.get("GAMIFICATION_TOKEN")
    if not gamification_api_url or not gamification_token:
        raise Exception("Environment variables GAMIFICATION_API_URL and GAMIFICATION_TOKEN must be set")
    return gamification_api_url, gamification_token

def get_submissions_details_from_id(gamification_api_url: str, gamification_token: str, submission_id: int):
    res = requests.get(
        url=f"{gamification_api_url}/submission/{submission_id}/",
        headers={
            "accept": "application/json",
            "Authorization": f"Token {gamification_token}"
        }
    )
    return res.json()

if __name__ == "__main__":
    filter_submissions_script()
