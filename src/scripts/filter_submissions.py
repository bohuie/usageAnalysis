import csv
import sys
from datetime import datetime
from pathlib import Path
import requests
from dotenv import load_dotenv
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
import time
from functools import wraps

from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path

# --- Retry and Timeout Wrapper ---
def retry(max_retries=3, backoff_factor=0.5):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            for i in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except (requests.exceptions.RequestException, requests.exceptions.Timeout) as e:
                    if i < max_retries - 1:
                        sleep_time = backoff_factor * (2 ** i)
                        print(f"[WARNING] Request failed ({e}). Retrying in {sleep_time:.2f} seconds...")
                        time.sleep(sleep_time)
                    else:
                        print(f"[ERROR] Max retries reached for request. Giving up.")
                        raise
        return wrapper
    return decorator

# --- Main Functions ---
def filter_submissions_script():
    actions_file_path = get_user_filepath_input("Enter the absolute path of your filtered consent csv file: ")
    
    output_filename = add_stem_to_filename(actions_file_path, "submissions")
    output_file_path = get_output_file_path(output_filename)
    
    print(f"[INFO] Input file: {actions_file_path}")
    print(f"[INFO] Output file will be saved to: {output_file_path}")
    filter_submissions(actions_file_path, output_file_path)

@retry(max_retries=5, backoff_factor=1)
def fetch_submission_details_with_retry(session, gamification_api_url, gamification_token, submission_id, timeout=10):
    """
    Fetches submission details with retry logic and a timeout.
    
    This function is wrapped with a retry decorator.
    """
    url = f"{gamification_api_url}/submission/{str(submission_id)}/"
    print(f"[DEBUG] Sending request for submission_id={submission_id}")
    res = session.get(
        url=url,
        headers={
            "accept": "application/json",
            'Authorization': f'Token {gamification_token}'
        },
        timeout=timeout
    )
    res.raise_for_status() # Raise an HTTPError for bad responses (4xx or 5xx)
    print(f"[DEBUG] Response status for submission_id={submission_id}: {res.status_code}")
    return res.json()

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
        print("[INFO] Retrieved Gamification API credentials")

        total_rows = 0
        kept_rows = 0
        
        kept_rows_to_process = []
        
        print("[INFO] Starting to read rows...")
        for row in reader:
            total_rows += 1
            if row['object_type'] == 'Submission' and row['description'] == 'Submission was evaluated':
                kept_rows += 1

                # Remove unwanted columns
                for key in list(row):
                    if key not in column_names:
                        del row[key]
                kept_rows_to_process.append(row)

                if kept_rows % 50 == 0:
                    print(f"[INFO] Found {kept_rows} kept rows so far...")
        
        print(f"[INFO] Finished scanning: {total_rows} total rows, {kept_rows} kept.")
        print("[INFO] Starting parallel requests...")
        
        rows_to_sort = []
        with requests.Session() as session:
            with ThreadPoolExecutor(max_workers=20) as executor:
                # Submit tasks to the thread pool
                future_to_row = {
                    executor.submit(
                        fetch_submission_details_with_retry, 
                        session, 
                        gamification_api_url, 
                        gamification_token, 
                        int(row['object_id'])
                    ): row for row in kept_rows_to_process
                }

                # Process results as they complete
                for future in as_completed(future_to_row):
                    row = future_to_row[future]
                    try:
                        submission_details = future.result()
                    except Exception as exc:
                        print(f"[ERROR] Request for submission {row['object_id']} failed: {exc}")
                        continue
                    
                    # Concept/category fields
                    row["question.type_name"] = get_submission_details_field(submission_details, ["question", "type_name"])
                    row["question.parent_category_name"] = get_submission_details_field(submission_details, ["question", "parent_category_name"])
                    row["question.category_name"] = get_submission_details_field(submission_details, ["question", "category_name"])

                    # Question fields
                    row["question.id"] = get_submission_details_field(submission_details, ["question", "id"])
                    row["question.difficulty"] = get_submission_details_field(submission_details, ["question", "difficulty"])
                    row["question.event_obj.name"] = get_submission_details_field(submission_details, ["question", "event_obj", "name"])
                    row["question.is_practice"] = get_submission_details_field(submission_details, ["question", "is_practice"])
                    row["question.is_exam"] = get_submission_details_field(submission_details, ["question", "is_exam"])

                    # Tests fields
                    passed_test = get_submission_details_field(submission_details, ["get_passed_test_results"])
                    failed_test = get_submission_details_field(submission_details, ["get_failed_test_results"])
                    row["get_passed_test_results"] = passed_test
                    row["get_failed_test_results"] = failed_test
                    row["num_passed_tests"] = len(passed_test) if passed_test else 0
                    row["num_failed_tests"] = len(failed_test) if failed_test else 0

                    rows_to_sort.append(row)

        print(f"[INFO] All requests complete. Sorting {len(rows_to_sort)} rows...")
        sorted_rows = sorted(rows_to_sort, key=lambda x: (x.get("question.id", ""), x.get("actor", ""), datetime.fromisoformat(x.get("time_created"))))
        print("[INFO] Sorting complete.")

        print(f"[INFO] Writing {len(sorted_rows)} rows to output file...")
        for i, row in enumerate(sorted_rows, 1):
            writer.writerow(row)
            if i % 100 == 0:
                print(f"[INFO] Wrote {i}/{len(sorted_rows)} rows")

        print(f"[SUCCESS] Done! Processed {total_rows} total rows, kept {kept_rows} submissions.")

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
    try:
        gamification_api_url = os.environ.get("GAMIFICATION_API_URL")
        gamification_token = os.environ.get("GAMIFICATION_TOKEN")
        if not gamification_api_url or not gamification_token:
            raise ValueError("GAMIFICATION_API_URL or GAMIFICATION_TOKEN not set in environment variables.")
    except Exception as e:
        raise Exception("Environment variables not set")
    return gamification_api_url, gamification_token

if __name__ == "__main__":
    filter_submissions_script()
