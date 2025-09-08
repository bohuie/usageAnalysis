import pandas as pd
import numpy as np # Used for np.nan (Not a Number)
from src.util.filepath_helpers import get_user_filepath_input, add_stem_to_filename, get_output_file_path

def process_skipped_questions_script():
    """
    Guides the user to input file paths and initiates the skipped questions processing.
    """
    # Prompt user for input file paths
    updated_output_path = get_user_filepath_input("Enter the absolute path of the updated_output.csv file: ")
    actions_file_path = get_user_filepath_input("Enter the absolute path of the actions_22_25.csv file: ")
    categories_difficulty_path = get_user_filepath_input("Enter the absolute path of the categories_with_difficulty.csv file: ")
    
    # Generate the output file path based on the input updated_output.csv
    output_filename = add_stem_to_filename(updated_output_path, "skipped_questions")
    output_file_path = get_output_file_path(output_filename)
    
    # Inform the user about the input and output file paths
    print(f"[INFO] Input updated_output.csv: {updated_output_path}")
    print(f"[INFO] Input actions_22_25.csv: {actions_file_path}")
    print(f"[INFO] Input categories_with_difficulty.csv: {categories_difficulty_path}")
    print(f"[INFO] Output file will be saved to: {output_file_path}")
    
    # Call the main processing function
    process_skipped_questions(updated_output_path, actions_file_path, output_file_path, categories_difficulty_path)

def process_skipped_questions(updated_output_path: str, actions_file_path: str, output_file_path: str, categories_difficulty_path: str):
    print("[INFO] Starting skipped questions processing... ")

    # Define the mapping for specific actor IDs
    actor_mapping = {
        3881: '388',
        5001: '500',
        5002: '500',
        5252: '525',
        4731: '473',
        4732: '473'
    }

    # Load DataFrames with error handling
    try:
        df_updated = pd.read_csv(updated_output_path)
        df_updated['time_created'] = df_updated['time_created'].astype(str)
        print(f"[INFO] Successfully loaded {len(df_updated)} rows from {updated_output_path}.")
    except Exception as e:
        print(f"[ERROR] Could not load updated_output.csv: {e}")
        return

    try:
        df_actions = pd.read_csv(actions_file_path, dtype={'actor': str, 'time_created': str, 'data.difficulty': str, 'data.category': str})
        # Data cleaning: standardize 'data.category' to string and strip whitespace
        df_actions['data.category'] = df_actions['data.category'].astype(str).str.strip()
        print(f"[INFO] Successfully loaded {len(df_actions)} rows from {actions_file_path}.")
    except Exception as e:
        print(f"[ERROR] Could not load actions_22_25.csv: {e}")
        return
        
    try:
        df_difficulty = pd.read_csv(categories_difficulty_path)
        # Data cleaning: standardize 'category_id' to string and strip whitespace
        df_difficulty['category_id'] = df_difficulty['category_id'].astype(str).str.strip()
        # Create a dictionary for efficient lookup: {category_id: difficulty}
        difficulty_lookup = pd.Series(df_difficulty['difficulty'].values, index=df_difficulty['category_id']).to_dict()
        print(f"[INFO] Successfully loaded {len(df_difficulty)} rows from {categories_difficulty_path}.")
    except Exception as e:
        print(f"[ERROR] Could not load categories_with_difficulty.csv: {e}")
        return

    # Filter df_updated for rows where 'action_code' is 'skip_to_next_question'
    print("[INFO] Filtering for 'skip_to_next_question' actions in updated_output.csv...")
    df_skipped_raw = df_updated[df_updated['action_code'] == 'skip_to_next_question'].copy()

    if df_skipped_raw.empty:
        print("[WARNING] No 'skip_to_next_question' actions found. Creating an empty output file. 🚫")
        pd.DataFrame(columns=list(df_updated.columns) + ['difficulty', 'category_id']).to_csv(output_file_path, index=False)
        return

    print(f"[INFO] Found {len(df_skipped_raw)} rows with 'skip_to_next_question' action to process.")

    # Pre-process df_actions for more efficient lookup
    print("[INFO] Pre-processing actions_22_25.csv for faster matching... 🔍")
    df_actions_filtered = df_actions[df_actions['description'] == 'User clicked on next question'].copy()
    
    processed_skipped_rows = []
    num_skipped_rows_to_process = len(df_skipped_raw)

    print(f"[INFO] Iterating through {num_skipped_rows_to_process} skipped rows to find matches and assign difficulty and category... ")

    # Iterate through each filtered skipped question row
    for i, skipped_row_series in enumerate(df_skipped_raw.iterrows()):
        original_row_data = skipped_row_series[1].to_dict()

        updated_actor_id = original_row_data.get('actor')
        updated_actor_prefix = actor_mapping.get(updated_actor_id, str(updated_actor_id)[:3])

        updated_time_suffix = original_row_data.get('time_created', '')[14:] if len(original_row_data.get('time_created', '')) >= 15 else ''
        
        potential_matches = df_actions_filtered[df_actions_filtered['actor'].str[:3] == updated_actor_prefix]
        
        matching_action_rows = potential_matches[
            potential_matches['time_created'].str.contains(updated_time_suffix, na=False)
        ]

        original_row_data['difficulty'] = np.nan
        original_row_data['category_id'] = np.nan

        if not matching_action_rows.empty:
            matched_action = matching_action_rows.iloc[0]
            
            # Get the cleaned category ID from the actions file
            category_id = matched_action.get('data.category')
            original_row_data['category_id'] = category_id
            
            # Look up the difficulty based on the cleaned category ID
            # The lookup will now succeed if the cleaned strings match
            if category_id is not None and category_id in difficulty_lookup:
                original_row_data['difficulty'] = difficulty_lookup[category_id]
        
        processed_skipped_rows.append(original_row_data)

        if (i + 1) % 1000 == 0:
            print(f"[PROGRESS] Processed {i + 1}/{num_skipped_rows_to_process} skipped rows.")

    print("[INFO] All skipped rows processed. Compiling final results... 📊")
    
    if processed_skipped_rows:
        df_final_skipped = pd.DataFrame(processed_skipped_rows)
    else:
        df_final_skipped = pd.DataFrame(columns=list(df_updated.columns) + ['difficulty', 'category_id'])
        
    output_columns_order = list(df_updated.columns)
    if 'difficulty' not in output_columns_order:
        output_columns_order.append('difficulty')
    if 'category_id' not in output_columns_order:
        output_columns_order.append('category_id')
    
    df_final_skipped = df_final_skipped.reindex(columns=output_columns_order)

    print(f"[INFO] Writing {len(df_final_skipped)} processed skipped questions to {output_file_path}... 💾")
    df_final_skipped.to_csv(output_file_path, index=False)
    
    print("[SUCCESS] Skipped questions processing complete. Output saved! 🎉")

if __name__ == "__main__":
    process_skipped_questions_script()