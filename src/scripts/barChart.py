import pandas as pd
import matplotlib.pyplot as plt
import os
from src.util.filepath_helpers import get_user_filepath_input


def barChart_script():
    # Ask the user to input the file path of the attempts CSV file
    actions_file_path = get_user_filepath_input("Enter the absolute path of attempts csv file: ")
    reference_file_path = get_user_filepath_input("Enter the absolute path of reference dates for this session: ")
    reference_dates = pd.read_csv(reference_file_path, encoding='utf-8')

    session = os.path.basename(actions_file_path)[:7]
    
    barChart(actions_file_path, reference_dates, session)


def barChart(input_file, reference_dates, session):
    df = pd.read_csv(input_file)
    df['time_created'] = pd.to_datetime(df['time_created'].str[:10])  # Convert time_created to datetime

    # Function to find the closest date in the reference file
    def find_closest_date(date):
        closest_date = reference_dates['date'][0]
        for ref_date in reference_dates['date']:
            if abs((date - pd.to_datetime(ref_date)).days) < abs((date - pd.to_datetime(closest_date)).days):
                closest_date = ref_date
        return closest_date

    # Function to assign week number based on closest date
    def assign_week_number(date):
        closest_date = find_closest_date(date)
        week_number = reference_dates.loc[reference_dates['date'] == closest_date, 'week count'].iloc[0]
        return week_number

    # Apply the assign_week_number function to each date in the DataFrame
    df['week'] = df['time_created'].apply(assign_week_number)

    # Group the DataFrame by week number and count the number of submissions in each week
    submissions_per_week = df.groupby('week')['time_created'].count()
    all_weeks = range(submissions_per_week.index.min(), submissions_per_week.index.max() + 1)
    submissions_per_week = submissions_per_week.reindex(all_weeks, fill_value=0)

    # Create a bar plot with week numbers on x-axis and number of submissions on y-axis
    plt.bar(submissions_per_week.index, submissions_per_week.values)
    plt.xlabel('Week Number')
    plt.ylabel('Number of Submissions')
    plt.title(f'Submissions per Week ({session} Term)')
    plt.ylim(0, 2750)
    plt.yticks(range(0, 2751, 250))
    plt.xticks(rotation=45, ha='right')

    for i, v in enumerate(submissions_per_week.values):
        plt.text(i + 2, v + 50, str(v), ha='center')  # Add some offset to avoid overlapping bars

    plt.show()

if __name__ == "__main__":
    barChart_script()






