import csv
import sys
from pathlib import Path
import pandas as pd

csv.field_size_limit(sys.maxsize)

def filter_data_by_consent_script():
    print("Enter the absolute path of your actions csv file: ", end="")
    actions_file_path = Path(input())
    if not actions_file_path.exists():
        raise Exception("Invalid path")

    print("Enter absolute path of your page views csv file: ", end="")
    page_views_path = Path(input())
    if not page_views_path.exists():
        raise Exception("Invalid path")

    output_filename = Path(Path(actions_file_path.name).stem + "_combined.csv")
    project_root_file_path = Path(__file__).parent.parent
    output_file_path = project_root_file_path / "data" / output_filename

    filter_data_by_consent(actions_file_path, page_views_path, output_file_path)

def filter_data_by_consent(data_file, page_views_path, output_file_path):
    df = pd.concat([pd.read_csv(data_file), pd.read_csv(page_views_path)])
    df.dropna(how='all', axis=1, inplace=True)
    df.sort_values(by=['time_created'], inplace=True)
    df.to_csv(output_file_path, sep=',')
                
if __name__ == "__main__":
    filter_data_by_consent_script()