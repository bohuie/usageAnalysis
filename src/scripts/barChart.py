import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os
from src.util.filepath_helpers import get_user_filepath_input


def barChart_script():
    # Ask the user to input the file path of the attempts CSV file
    actions_file_path = get_user_filepath_input("Enter the absolute path of attempts csv file: ")
    reference_file_path = get_user_filepath_input("Enter the absolute path of reference dates for this session: ")
    reference_dates = pd.read_csv(reference_file_path, encoding='utf-8')
    print(reference_dates.head(10))
    print(reference_dates.dtypes)

    session = os.path.basename(actions_file_path)[:7]
    
    barChart(actions_file_path, reference_dates, session)


def barChart(input_file, reference_dates, session):
    df = pd.read_csv(input_file)
    df['time_created'] = pd.to_datetime(df['time_created'].str[:10])
    reference_dates['week'] = reference_dates['week'].astype(float)
    reference_dates['date'] = pd.to_datetime(reference_dates['date'])

    # Sort both dataframes by date for merge_asof to work
    df = df.sort_values('time_created')
    reference_dates = reference_dates.sort_values('date')

    # Use merge_asof to assign each row in df the latest ref_date ≤ time_created
    df = pd.merge_asof(df, reference_dates, left_on='time_created', right_on='date', direction='backward')
    print("Unique weeks assigned after merge:", sorted(df['week'].unique()))


    # Now 'week' column is automatically aligned
    df['week'] = df['week']

    submissions_per_week = df.groupby('week')['time_created'].count()
    print("\n=== Submissions per week ===")
    print(submissions_per_week)

    start = submissions_per_week.index.min()
    end = submissions_per_week.index.max()
    step = 0.5 if any((submissions_per_week.index % 1) != 0) else 1
    all_weeks = np.arange(start, end + step, step)

    submissions_per_week = submissions_per_week.reindex(all_weeks, fill_value=0).sort_index()
    # Remove weeks 8.0 and above
    submissions_per_week = submissions_per_week[submissions_per_week.index < 8.0]

    x = submissions_per_week.index.to_list()
    y = submissions_per_week.values
    plt.bar(x, y, width=0.4, align='center')

    plt.xlabel('Week Number')
    plt.ylabel('Number of Submissions')
    plt.title(f'Submissions per Week ({session} Term) diff = 2')
    plt.ylim(0, 2750)
    plt.yticks(range(0, 2751, 250))
    plt.xticks(ticks=x, labels=[str(week) for week in x], rotation=45, ha='right')

    for xi, yi in zip(x, y):
        plt.text(xi, yi + 50, str(yi), ha='center', fontsize=8)

    plt.show()
    
    print("X-axis values:", x)


if __name__ == "__main__":
    barChart_script()






