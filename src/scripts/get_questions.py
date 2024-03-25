import csv
import sys
from pathlib import Path
import requests
from dotenv import load_dotenv
import os
import json

csv.field_size_limit(sys.maxsize)

def get_questions():
    gamification_api_url, gamification_token = get_gamification_secrets()
    questions = []
    questions_first_page = get_questions_with_url(get_questions_first_page_utl(gamification_api_url), gamification_token)
    questions += questions_first_page["results"]
    
    while questions_first_page["next"]:
        questions_first_page = get_questions_with_url(questions_first_page["next"], gamification_token)
        questions += questions_first_page["results"]

    questions_json = json.dumps({"count": questions_first_page["count"], "questions": questions}, indent=4)

    output_filename = "questions.json"
    project_root_file_path = Path(__file__).parent.parent
    output_file_path = project_root_file_path / "data" / output_filename
    with open(output_file_path, "w") as outfile:
        outfile.write(questions_json)


def get_gamification_secrets():
    load_dotenv()
    try:
        gamification_api_url = os.environ.get("GAMIFICATION_API_URL")
        gamification_token = os.environ.get("GAMIFICATION_TOKEN")
    except Exception as e:
        raise Exception("Environment variables not set")

    return gamification_api_url, gamification_token

def get_questions_first_page_utl(gamification_api_url):
    return f"{gamification_api_url}questions/?ordering=id&page={1}&page_size={1}"

def get_questions_with_url(url, gamification_token):
    try:
        res = requests.get(
            url=url,
            headers={
                "accept": "application/json",
                'Authorization': f'Token {gamification_token}'
        })
    except Exception as e:
        print(e)
        return None
    return res.json()
        
if __name__ == "__main__":
    get_questions()