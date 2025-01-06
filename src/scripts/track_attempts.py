import csv
import sys
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path

csv.field_size_limit(1000000)

def track_attempts_script():
    actions_file_path = get_user_filepath_input("Enter the absolute path of your filtered submissions csv file: ")
    
    output_filename = add_stem_to_filename(actions_file_path, "attempts")
    output_file_path = get_output_file_path(output_filename)
    
    track_attempts(actions_file_path, output_file_path)

def track_attempts(data_file, output_file_path):
    with open(data_file, 'r', encoding='latin1') as inp, open(output_file_path, 'w') as out:
        reader = csv.DictReader(inp)
        fieldnames = reader.fieldnames + ['nth_attempt']
        writer = csv.DictWriter(out, fieldnames)
        writer.writeheader()
        question = {}
        optionalTotal = 0
        mandatoryTotal = 0
        questionsTotal = 0

        for row in reader:
            question_id = row['question.id']
            actor = row['actor']
            is_practice = row['question.is_practice']
                
            # Check if question_id exists in the question dictionary
            if question_id not in question:
                question[question_id] = {actor: 1}
            else:
                # Check if actor exists for the given question_id
                if actor not in question[question_id]:
                    question[question_id][actor] = 1
                else:
                    question[question_id][actor] += 1
                
            # Check if question is optional or mandatory
            if is_practice == 'True':
                optionalTotal += 1
            else:
                mandatoryTotal+= 1

            # Write the nth attempt value to the 'nth_attempt' column
            row['nth_attempt'] = question[question_id][actor]
            
            # Write the row to the output CSV file
            writer.writerow(row)

        # Print out total optional and mandatory questions
        print(f"Total optional submissions in May: {optionalTotal}")
        print(f"Total mandatory submissions in May: {mandatoryTotal}")
        questionsTotal = optionalTotal + mandatoryTotal
        print(f"Total number of submissions in May: {questionsTotal}")



if __name__ == "__main__":
    track_attempts_script()