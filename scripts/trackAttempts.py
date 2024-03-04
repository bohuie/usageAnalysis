import csv
import sys
from pathlib import Path

csv.field_size_limit(sys.maxsize)

def track_attempts_script():
    print("Enter the absolute path of your filtered submissions csv file: ", end="")
    actions_file_path = Path(input())
    if not actions_file_path.exists():
        raise Exception("Invalid path")
    
    output_filename = Path(Path(actions_file_path.name).stem + "_attempts.csv")
    project_root_file_path = Path(__file__).parent.parent
    output_file_path = project_root_file_path / "data" / output_filename
    
    track_attempts(actions_file_path, output_file_path)


def track_attempts(data_file, output_file_path):
    with open(data_file, 'r', encoding='latin1') as inp, open(output_file_path, 'w') as out:
        reader = csv.DictReader(inp)
        fieldnames = reader.fieldnames + ['nth_attempt']
        writer = csv.DictWriter(out, fieldnames)
        writer.writeheader()
        question = {}

        for row in reader:
            question_id = row['question.id']
            actor = row['actor']
                
            # Check if question_id exists in the question dictionary
            if question_id not in question:
                question[question_id] = {actor: 1}
            else:
                # Check if actor exists for the given question_id
                if actor not in question[question_id]:
                    question[question_id][actor] = 1
                else:
                    question[question_id][actor] += 1
                
            # Write the nth attempt value to the 'nth_attempt' column
            row['nth_attempt'] = question[question_id][actor]
            
            # Write the row to the output CSV file
            writer.writerow(row)



if __name__ == "__main__":
    track_attempts_script()