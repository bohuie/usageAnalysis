import csv
import sys
from src.util.filepath_helpers import get_user_filepath_input, get_output_file_path

csv.field_size_limit(1000000)

def userPerformance_script():
    filtered_submissions_file_path = get_user_filepath_input()

    with open(filtered_submissions_file_path, 'r') as inp:
        reader = csv.DictReader(inp)
        user = {}
        for row in reader:
            if row ['object_type'] == "Submission":
                if row['actor'] not in user:
                    user[row['actor']] = {"total_submissions": 1, "correct": 0, "partially_correct": 0, "incorrect": 0, "score": 0, "avg_score": 0}
                else:
                    user[row['actor']]["total_submissions"] += 1
            if row['data.status'] == "Correct":
                user[row['actor']]["score"] += 1
                user[row['actor']]["correct"] += 1
            elif row['data.status'] == "Partially Correct":
                user[row['actor']]["score"] += 0.5
                user[row['actor']]["partially_correct"] += 1
            elif row['data.status'] == "Incorrect":
                user[row['actor']]["score"] += 0
                user[row['actor']]["incorrect"] += 1
        for key, value in user.items():
            user[key]["avg_score"] = round(value["score"]/value["total_submissions"], 2)
        userPerformance_file(user, "userPerformance.csv")

def userPerformance_file(user, output_file_name):
    output_file_path = get_output_file_path(output_file_name)
    with open(output_file_path, 'w') as out:
        w = csv.DictWriter( out, ["user_id", "total_submissions", "correct", "partially_correct", "incorrect", "score", "avg_score"] )
        w.writeheader()
        for key,val in sorted(user.items()):
            row = {'user_id': key}
            row.update(val)
            w.writerow(row)

                
if __name__ == "__main__":
    userPerformance_script()