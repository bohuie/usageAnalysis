import pandas as pd
import matplotlib.pyplot as plt
import os
from src.util.filepath_helpers import get_user_filepath_input


def barChart_script():
    actions_file_path = get_user_filepath_input("Enter the absolute path of attempts csv file: ")
    session = os.path.basename(actions_file_path)[:7]

    barChart(actions_file_path, session)

def barChart(input_file, session):
    df = pd.read_csv(input_file)
    df['time_created'] = df['time_created'].str[:10]

    try:
        df['time_created'] = pd.to_datetime(df['time_created'])
    except ValueError:
        print("Warning: Could not convert all values in 'time_created' to datetime format.")

    df['week'] = df['time_created'].dt.isocalendar().week
    submissions_per_week = df.groupby('week')['time_created'].count()
    all_weeks = range(submissions_per_week.index.min(), submissions_per_week.index.max() + 1)
    submissions_per_week = submissions_per_week.reindex(all_weeks, fill_value=0)

    plt.bar(submissions_per_week.index, submissions_per_week.values)
    plt.xlabel('Week Number')
    plt.ylabel('Number of Submissions')
    plt.title(f'Submissions per Week ({session} Term)')
    plt.ylim(0, 2000) 
    plt.yticks(range(0, 2001, 250))
    plt.xticks(rotation=45, ha='right')
    plt.show()


if __name__ == "__main__":
    barChart_script()






