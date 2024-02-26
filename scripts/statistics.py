import csv
from ast import literal_eval
import sys
from pathlib import Path

csv.field_size_limit(sys.maxsize)

def userPerformance_script():
    print("Enter the absolute path of your filtered submissions csv file: ", end="")
    filtered_submissions_file_path = Path(input())
    if not filtered_submissions_file_path.exists():
        raise Exception("Invalid path")

    with open(filtered_submissions_file_path, 'r') as inp:
        reader = csv.DictReader(inp)
        total_submissions = 0
        total_questions = 0
        total_categories = 0
        questions = {}
        categories = {}
        junits = {}
        for row in reader:
            if row["question.type_name"] not in questions:
                total_questions += 1
                questions[row["question.type_name"]] = {
                    "type": row["question.type_name"],
                    "total_submissions": 0,
                    "unique_submissions": 0,
                    "unique_users": set(),
                    "correct": 0,
                    "partially_correct": 0,
                    "incorrect": 0,
                    "grade": 0,
                    "avg_grade": 0,
                    "success_rate": 0,
                    "popular_rate": 0
                }

            if row["question.category_name"] not in categories:
                total_categories += 1
                categories[row["question.category_name"]] = {
                    "type": row["question.category_name"],
                    "total_submissions": 0,
                    "unique_submissions": 0,
                    "unique_users": set(),
                    "correct": 0,
                    "partially_correct": 0,
                    "incorrect": 0,
                    "grade": 0,
                    "avg_grade": 0,
                    "success_rate": 0,
                    "popular_rate": 0
                }

            if row["get_passed_test_results"] != "" and row["get_passed_test_results"] != "":
                passed_tests = literal_eval(row["get_passed_test_results"])
                failed_tests = literal_eval(row["get_failed_test_results"])
                for test in passed_tests:
                    if test["name"] not in junits:
                        junits[test["name"]] = {
                            "junit_name": test["name"],
                            "question_type": set(),
                            "question_category": set(),
                            "total_submissions": 0,
                            "passed_submissions": 0,
                            "failed_submissions": 0,
                        }

                    junits[test["name"]]["total_submissions"] += 1
                    junits[test["name"]]["question_type"].add(row["question.type_name"])
                    junits[test["name"]]["question_category"].add(row["question.category_name"])
                    junits[test["name"]]["passed_submissions"] += 1
                
                for test in failed_tests:
                    if test["name"] not in junits:
                        junits[test["name"]] = {
                            "junit_name": test["name"],
                            "question_type": set(),
                            "question_category": set(),
                            "total_submissions": 0,
                            "passed_submissions": 0,
                            "failed_submissions": 0,
                        }

                    junits[test["name"]]["total_submissions"] += 1
                    junits[test["name"]]["question_type"].add(row["question.type_name"])
                    junits[test["name"]]["question_category"].add(row["question.category_name"])
                    junits[test["name"]]["failed_submissions"] += 1

            total_submissions += 1
            
            questions[row["question.type_name"]]["total_submissions"] += 1
            questions[row["question.type_name"]]["grade"] += float(row["data.grade"])
            questions[row["question.type_name"]]["unique_users"].add(row["actor"])

            categories[row["question.category_name"]]["total_submissions"] += 1
            categories[row["question.category_name"]]["unique_users"].add(row["actor"])
            categories[row["question.category_name"]]["grade"] += float(row["data.grade"])

            if row['data.status'] == "Correct":
                questions[row["question.type_name"]]["correct"] += 1
                categories[row["question.category_name"]]["correct"] += 1
            elif row['data.status'] == "Partially Correct":
                questions[row["question.type_name"]]["partially_correct"] += 1
                categories[row["question.category_name"]]["partially_correct"] += 1
            else:
                questions[row["question.type_name"]]["incorrect"] += 1
                categories[row["question.category_name"]]["incorrect"] += 1

        for key, val in questions.items():
            val["unique_submissions"] = len(val["unique_users"])
            if val["total_submissions"] > 0:
                val["avg_grade"] = round(val["grade"] / val["total_submissions"], 2)
                val["success_rate"] = round(100 * val["correct"] / val["total_submissions"], 2)
            if total_questions > 0:
                val["popular_rate"] = round(100 * val["total_submissions"] / total_submissions, 2)
            del val["unique_users"]
            del val["grade"]

        for key, val in categories.items():
            val["unique_submissions"] = len(val["unique_users"])
            if val["total_submissions"] > 0:
                val["avg_grade"] = round(val["grade"] / val["total_submissions"], 2)
                val["success_rate"] = round(100 * val["correct"] / val["total_submissions"], 2)
            if total_questions > 0:
                val["popular_rate"] = round(100 * val["total_submissions"] / total_submissions, 2)
            del val["unique_users"]
            del val["grade"]

        statistics_file(questions, "questions_stats.csv")
        statistics_file(categories, "categories_stats.csv")
        statistics_file(junits, "junits_stats.csv")

def statistics_file(data, output_file_name):
    project_root_file_path = Path(__file__).parent.parent
    output_file_path = project_root_file_path / "data" / output_file_name
    with open(output_file_path, 'w') as out:
        w = csv.DictWriter( out, list(data.values())[0].keys())
        w.writeheader()
        for key, val in sorted(data.items()):
            w.writerow(val)

if __name__ == "__main__":
    userPerformance_script()