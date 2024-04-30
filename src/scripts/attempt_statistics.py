from collections import defaultdict
import csv
import statistics
import pandas as pd
from src.util.filepath_helpers import get_output_file_path
from src.util.filepath_helpers import get_user_filepath_input
from src.util.filepath_helpers import add_stem_to_filename

def attempt_statistics_analysis():
    attempts_file_path = get_user_filepath_input("Enter the absolute path of your attempts csv file: ")
    output_filename = add_stem_to_filename(attempts_file_path, "statistics")
    output_file_path = get_output_file_path(output_filename)
    
    attempt_statistics(attempts_file_path, output_file_path)

def attempt_statistics(data_file_path, output_file_path):
    with open(data_file_path, 'r') as inp, open(output_file_path, 'w') as out:
        csv_reader = csv.DictReader(inp)

        question_hashmap = defaultdict(lambda: defaultdict(int))

        for row in csv_reader:
            question_hashmap[(row["question.parent_category_name"], row["question.category_name"], row["question.id"])][row["actor"]] = int(row["nth_attempt"])

        statistics_hashmap = defaultdict(lambda: defaultdict(int))

        for question, user_attempts in question_hashmap.items():
            statistics_hashmap[question[2]]["parent_category_name"] = question[0]
            statistics_hashmap[question[2]]["category_name"] = question[1]
            statistics_hashmap[question[2]]["question_id"] = question[2]
            statistics_hashmap[question[2]]["average_attempts"] = round(statistics.mean(user_attempts.values()), 2)
            if len(user_attempts.values()) > 1:
                statistics_hashmap[question[2]]["stdev_attempts"] = round(statistics.stdev(user_attempts.values()), 2)
            else:
                statistics_hashmap[question[2]]["stdev_attempts"] = 0.0
            statistics_hashmap[question[2]]["max_attempts"] = max(user_attempts.values())
            statistics_hashmap[question[2]]["min_attempts"] = min(user_attempts.values())
            
        df = pd.DataFrame(statistics_hashmap).T
        df.to_csv(out, index=False, header=True)


if __name__ == "__main__":
    attempt_statistics_analysis()