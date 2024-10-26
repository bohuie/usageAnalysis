from collections import defaultdict
import pandas as pd
import csv
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path

def input_behavior_script():
    engagement_file_path = get_user_filepath_input("Enter the absolute path of engagement csv file: ")
    grade_file_path = get_user_filepath_input("Enter the absolute path to filtered gradebook csv file: ")
    output_filename = add_stem_to_filename(engagement_file_path, "sort")
    output_file_path = get_output_file_path(output_filename)
    
    input_behavior(engagement_file_path, grade_file_path, output_file_path)

def input_behavior(input1, input2, output):
    with open(input1, 'r', encoding='latin1') as inp1, open(input2, 'r', encoding='latin1') as inp2, open(output, 'w') as out:
        reader1 = csv.DictReader(inp1)
        reader2 = csv.DictReader(inp2)
                
        fieldnames = ["actor", "parent_category", "category", "grade", "count_unique_question_id", "total_attempts", "average_accuracy"]
        writer = csv.DictWriter(out, fieldnames)
        writer.writeheader()
        
        actor_data = defaultdict(lambda: defaultdict(lambda: {
            "count_unique_question_id": 0,
            "total_attempts": 0,
            "average_accuracy": 0.0,
            "unique_question_ids": set(),
            "accuracies": [],
            "grade": 0
        }))
        
        grades = {}
        A = 80
        B1 = 70
        B2 = 79
        C1 = 60 
        C2 = 69
        D1 = 50
        D2 = 59
        F = 49
        
        for row in reader2:
            numerical = float(row['final_score'])
            
            if numerical >= A:
                grades[row['ï»¿actor_id']] = 'A'
            elif numerical >= B1 and numerical <= B2:
                grades[row['ï»¿actor_id']] = 'B'
            elif numerical >= C1 and numerical <= C2:
                grades[row['ï»¿actor_id']] = 'C'
            elif numerical >= D1 and numerical <= D2:
                grades[row['ï»¿actor_id']] = 'D'
            elif numerical <= F:
                grades[row['ï»¿actor_id']] = 'F'
        
        for row in reader1:
            actor = row['actor']
            parent_category = row['question.parent_category_name']
            category = row['question.category_name']
            question_id = row['question.id']
            accuracy = float(row['accuracy'])
            attempt = int(row['counts'])
            
            if actor in grades.keys():
            
                data = actor_data[actor][(parent_category, category)]
            
                if question_id not in data['unique_question_ids']:
                    data['unique_question_ids'].add(question_id)
                    data['count_unique_question_id'] += 1
            
                data['total_attempts'] += attempt
                data['accuracies'].append(accuracy)
                data['average_accuracy'] = sum(data['accuracies']) / len(data['accuracies'])
                data['grade'] = grades[actor]
            
        for actor, categories in actor_data.items():
            for (parent_category, category), metrics in categories.items():
                writer.writerow({
                    "actor": actor,
                    "parent_category": parent_category,
                    "category": category,
                    "grade": metrics["grade"],
                    "count_unique_question_id": metrics["count_unique_question_id"],
                    "total_attempts": metrics["total_attempts"],
                    "average_accuracy": metrics["average_accuracy"]
                })
        
if __name__ == "__main__":
    input_behavior_script()