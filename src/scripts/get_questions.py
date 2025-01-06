import csv
import sys
from pathlib import Path
import requests
from dotenv import load_dotenv
import os
import json

csv.field_size_limit(1000000)

def get_questions():
    gamification_api_url, gamification_token = get_gamification_secrets()
    questions = []
    questions_first_page = get_questions_with_url(get_questions_first_page_url(gamification_api_url), gamification_token)
    questions += questions_first_page["results"]
    
    while questions_first_page["next"]:
        questions_first_page = get_questions_with_url(questions_first_page["next"], gamification_token)
        questions += questions_first_page["results"]

    for question in questions:
        print(f"Extracting variation types for question {question['id']}")
        question["variation_types"] = get_question_variation_types_by_id(gamification_token, gamification_api_url, question["id"])

    questions_json = json.dumps({"count": questions_first_page["count"], "questions": questions}, indent=4)

    output_filename = "questions.json"
    
    with open(output_filename, "w") as outfile:
        outfile.write(questions_json)


def get_gamification_secrets():
    load_dotenv()
    try:
        gamification_api_url = os.environ.get("GAMIFICATION_API_URL")
        gamification_token = os.environ.get("GAMIFICATION_TOKEN")
    except Exception as e:
        raise Exception("Environment variables not set")

    return gamification_api_url, gamification_token

def get_questions_first_page_url(gamification_api_url):
    return f"{gamification_api_url}/questions/?ordering=id&page={1}&page_size={100}"

def get_question_variation_types_by_id_url(gamification_api_url, id):
    return f"{gamification_api_url}/questions/{id}/"

def get_question_variation_types_by_id(gamification_token, gamification_api_url, id):
    url = get_question_variation_types_by_id_url(gamification_api_url, id)
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
    question = res.json()
    return question["variation_types"]

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