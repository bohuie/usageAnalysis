import pandas as pd
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path
from collections import defaultdict
import csv

GRADE_LEVELS = {
    "A+ (90 - 100)": (90, float("inf")),
    "A (85 - 89)": (85, 89),
    "A- (80 - 84)": (80, 84),
    "B+ (76 - 79)": (76, 79),
    "B (72 - 75)": (72, 75),
    "B- (68 - 71)": (68, 71),
    "C+ (64 - 68)": (64, 67),
    "C (60 - 63)": (60, 63),
    "C- (55 - 59)": (55, 59),
    "D (50 - 54)": (50, 54),
    "F (0 - 49)": (0, 49)
}

def filter_engagement_script():
    grades_file_path = get_user_filepath_input("Enter the absolute path of filtered gradebook csv file: ")
    attempts_file_path = get_user_filepath_input("Enter the absolute path of attempts csv file: ")
    
    filter_engagement(attempts_file_path, grades_file_path)

def filter_engagement(attempts_file_path, grades_file_path):
    final_exam_fields = ["FinalExam", "Final Exam Percent", "FinalReal", "Final Exam  (1733156)", "Final Exam (/74) (1731222)"]
    final_grade_fields = ["f", "Final Grade Percent", "Total", "Total( Percentage ) (1733154)", "Unofficial Final Total (1732073)"]

    attempts_data = pd.read_csv(attempts_file_path)
    grades_data = pd.read_csv(grades_file_path)

    for final_exam_field in final_exam_fields:
        if final_exam_field in grades_data.columns:
            break
    
    for final_grade_field in final_grade_fields:
        if final_grade_field in grades_data.columns:
            break

    if final_exam_field == "FinalExam":
        # The grade is x out of 30, so we need to convert it to a percentage
        grades_data[final_exam_field] = grades_data[final_exam_field].apply(lambda x: x / 30 * 100)

    if final_exam_field in ["Final Exam (/74) (1731222)", "Final Exam  (1733156)"]:
        # The grade is x out of 74, so we need to convert it to a percentage
        grades_data[final_exam_field] = grades_data[final_exam_field].apply(lambda x: x / 74 * 100)

    if final_exam_field == "FinalReal":
        # The grade has a % sign at the end, so we need to remove it
        grades_data[final_exam_field] = grades_data[final_exam_field].apply(lambda x: x.replace("%", ""))
    
    final_exam_user_id_map = {}
    final_grade_user_id_map = {}

    for grade_level, grade_range in GRADE_LEVELS.items():
        final_exam_user_id_map[grade_level] = []
        final_grade_user_id_map[grade_level] = []
        for _, row in grades_data.iterrows():
            if float(row[final_exam_field]) >= grade_range[0] and float(row[final_exam_field]) <= grade_range[1]:
                final_exam_user_id_map[grade_level].append(row["user"])
            if float(row[final_grade_field]) >= grade_range[0] and float(row[final_grade_field]) <= grade_range[1]:
                final_grade_user_id_map[grade_level].append(row["user"])

    user_total_attempts = defaultdict(int)
    user_correct_attempts = defaultdict(int)

    for i in range(len(attempts_data)):
        user_total_attempts[attempts_data["actor"][i]] += 1
        if attempts_data["data.status"][i] == "Correct":
            user_correct_attempts[attempts_data["actor"][i]] += 1
        
    final_exam_output_file_path = get_output_file_path(add_stem_to_filename(grades_file_path, "final_exam_engagement"))
    final_grade_output_file_path = get_output_file_path(add_stem_to_filename(grades_file_path, "final_grade_engagement"))

    with open(final_exam_output_file_path, 'w') as final_exam_out, open(final_grade_output_file_path, 'w') as final_grade_out:
        final_exam_writer = csv.DictWriter(final_exam_out, fieldnames=["total_user", "average_total_attempts", "average_accuracy", "grade_level"])
        final_exam_writer.writeheader()
        final_grade_writer = csv.DictWriter(final_grade_out, fieldnames=["total_user", "average_total_attempts", "average_accuracy", "grade_level"])
        final_grade_writer.writeheader()


        for grade_level, user_ids in final_exam_user_id_map.items():
            final_exam_writer.writerow({
                "total_user": len(user_ids),
                "average_total_attempts": (round(sum([user_total_attempts[user_id] for user_id in user_ids]) / len(user_ids), 2)) if len(user_ids) > 0 else 0.0,
                "average_accuracy": (round(sum([(user_correct_attempts[user_id] / user_total_attempts[user_id]) if user_total_attempts[user_id] > 0 else 0 for user_id in user_ids]) / len(user_ids) * 100, 2)) if len(user_ids) > 0 else 0.0,
                "grade_level": grade_level
            })


        for grade_level, user_ids in final_grade_user_id_map.items():
            final_grade_writer.writerow({
                "total_user": len(user_ids),
                "average_total_attempts": (round(sum([user_total_attempts[user_id] for user_id in user_ids]) / len(user_ids), 2)) if len(user_ids) > 0 else 0.0,
                "average_accuracy": (round(sum([(user_correct_attempts[user_id] / user_total_attempts[user_id]) if user_total_attempts[user_id] > 0 else 0 for user_id in user_ids]) / len(user_ids) * 100, 2)) if len(user_ids) > 0 else 0.0,
                "grade_level": grade_level
            })

if __name__ == "__main__":
    filter_engagement_script()