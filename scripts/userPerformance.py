import csv
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
    project_root_file_path = Path(__file__).parent.parent
    output_file_path = project_root_file_path / "data" / output_file_name
    with open(output_file_path, 'w') as out:
        w = csv.DictWriter( out, ["user_id", "total_submissions", "correct", "partially_correct", "incorrect", "score", "avg_score"] )
        w.writeheader()
        for key,val in sorted(user.items()):
            row = {'user_id': key}
            row.update(val)
            w.writerow(row)

                
if __name__ == "__main__":
    userPerformance_script()