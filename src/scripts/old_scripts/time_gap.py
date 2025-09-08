import pandas as pd
import numpy as np
import os
import matplotlib.pyplot as plt
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path

def time_gap_script():
    file_path = str(get_user_filepath_input("Enter the absolute path of time gap input csv file: "))
    output_file_path = os.path.dirname(file_path)
    avg_time_gap = time_gap(file_path, output_file_path)
    create_grouped_bar_chart(avg_time_gap)

def time_gap(file, output_dir):
    df = pd.read_csv(file)    
    df['time_created'] = pd.to_datetime(df['time_created'])
    df = df.sort_values(['actor', 'question.id', 'time_created'])
    df['time_diff'] = df.groupby(['actor', 'question.id'])['time_created'].diff()
    df = df[df['time_diff'].notnull()]
    df['time_diff'] = df['time_diff'].dt.total_seconds() / 60.0
    df.to_csv(f"{output_dir}/processed_timediff.csv", index=False)
    avg_time_gap = df.groupby(['actor', 'question.id', 'final_score', 'question.parent_category_name'])['time_diff'].mean()
    avg_time_gap = avg_time_gap.reset_index()

    return avg_time_gap

def create_grouped_bar_chart(avg_time_gap):
    avg_time_gap_grouped = avg_time_gap.groupby(['question.parent_category_name', 'final_score'])['time_diff'].mean()
    avg_time_gap_grouped = avg_time_gap_grouped.unstack()

    avg_time_gap_grouped.to_csv('average_time_gap.csv')  

    colors = ['purple', 'blue', 'green', 'yellow', 'red']
    ax = avg_time_gap_grouped.plot(kind='bar', figsize=(10, 6), color=colors)

    plt.ylabel('Average Time Gap (minutes)')
    plt.title('Average Time Gap Between Attempts by Category and Grade Level')
    plt.xticks(rotation=45)
    plt.legend(title='Final Score', labels=['A', 'B', 'C', 'D', 'F'])  
    
    for container in ax.containers:
        ax.bar_label(container, fmt='%.2f', label_type='edge', rotation=60)

    plt.tight_layout()  
    plt.show()

if __name__ == "__main__":
    time_gap_script()