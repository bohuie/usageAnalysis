# usageAnalysis

Analysis of data

## Project requirements:
- Python3

## Project setup
1. Insert csv files into the data folder (*actions.csv, grades.csv, gradebook from each sessions, grades.csv, *timeinput.csv, *dates.csv) * = for all 3 sessions (Jan, May, Sep)

2. Make a python virtual environment
    ```bash
    python3 -m venv venv
    ```
    OR for windows,
    ```bash
    py -m venv venv
    ```

3. Activate python virtual environment
    ```bash
    source venv/bin/activate
    ```
    OR for windows,
    ```bash
    venv/Scripts/activate
    ```

4. Install the required packages
    ```bash
    pip3 install -r requirements.txt
    ```

5. API Request Requirements

- Go to https://gamification.ok.ubc.ca/
- Inspect page -> Network tab (make sure to do this before logging in, log out first if needed)
- Login to your gamification account
- On Network tab select ``api-token-auth`` -> Preview -> token
- Set ``GAMIFICATION_SUBMISSION_URL`` and ``GAMIFICATION_TOKEN`` with your token in your created ``.env`` file
- rename .env.txt file to ".env" and save

6. run scripts following the order below
    ```bash
    python3 -m src.scripts.<script_name_without_.py>
    ```
    OR for windows,
    ```bash
    py -m src.scripts.<script_name_without_.py>
    ```

## Running specific scripts

All scripts with their description and requirements.

## Order of scripts to run (description of scripts and required input files can be found below)

To get student performance metrics and activity bar chart:
1. filter_consent.py
2. filter_submissions.py
3. track_attempts.py
4. engagement.py
5. filter_gradebook.py
6. grade_behavior.py
7. bar_chart.py

To get index of difficulty for all questions in Course Gamification throughout 2022-2025:
1. filter_consent.py
2. filter_all_submissions.py 
3. splitCSV.py 
4. filter_submissions.py
5. combineCSV.py 
6. track_attempts.py
7. engagement.py 
8. Create pivot table on Microsoft Excel
9. get_skipped_ID.py 
10. count_skipped.py

To get heatmaps and process maps of cluster groups:
1. rename_actor.py
2. process_mining.R
3. cluster_behavior_action.R
4. cluster_behavior_srl.R
5. cluster_fluctuations_action.R
6. cluster_fluctuations_srl.R
7. cluster_grade_action.R
8. cluster_grade_srl.R
9. cluster_gender_action.R
10. cluster_gender_srl.R

## Scripts to ignore

old_scripts:
- attempt_statistics.py
- filter_optional_submissions.py 
- gradebook_engagement_statistics.py 
- question_category_count.py 
- question_variation_count.py 
- statistics.py
- user_performance.py
- time_gap.py
- state_diagram.py

## get_questions.py

### Description
Gets all gamification questions through api and saves it as ``questions.json`` in data folder

### Requirement:
- None


## questions_category_count.py

### Description
Counts all questions from gamification by categories and saves the statistic into a csv file

### Requirement:
- questions.json from get_questions.py


## question_variation_count.py

### Description
Gets all question variation from gamification and is saved into a csv file

### Requirement:
- questions.json from get_questions.py


## filter_consent.py

### Description
Filters actions csv data, that can be downloaded from gamification admin panel, by student consent.

### Requirement:
- actions csv data from gamification
- student consent csv data from gamification
- teachers csv data


## filter_submission.py

### Description
Filters actions csv data to get only student submissions. Gets question details for each submission and saves it into a csv file.

### Requirement:
- filtered consent csv data from filter_consent.py


## filter_optional_submission.py

### Description
Filters actions csv data to get only student submissions. Gets question details for each submission and saves it into a ``2 different csv file, 1 includes only optional submissions (submissions for practice questions) and the other is every other submissions``.

### Requirement:
- actions csv data from gamification


## track_attempts.py

### Description
Adds a attemps column to the submission csv data which counts which attempt it was for a certain user for a certain question.

### Requirement:
- submissions csv data from filter_submission.py or filter_optional_submission.py


## engagement.py

### Description
Analyses correct and incorrect submissions with users' attemps to check user accuracy per question per category.

### Requirement:
- submissions csv data with attemps column from track_attempts.py
- may need to run ```pip uninstall numpy``` and ```pip install numpy``` if there are issues with importing pandas


## barChart.py

### Description
Creates bar chart for submissions csv data for number of submissions per period of time (per week).

### Requirement:
- session dates csv


## attempt_statistic.py

### Description
Analyses submissions data to get per question per user statistics like avg attempts per user, stdev, minimum number of attermpts, maximum number of attempts, and total users attempted. This statistic is saved into a csv file.

### Requirement:
- submissions csv data from filter_submission.py or filter_optional_submission.py


## filter_gradebook.py

### Description
Filters gradebook based on consent from gamification

### Requirement:
- gradebook csv data
- consent csv data from gamification


## gradebook_engagement_statistics.py

### Description
Analyzes the gradebook and submissions seperating student engagement based on final exam grade and overall course grade.

### Requirement:
- submissions csv data from filter_submission.py or filter_optional_submission.py
- filtered gradebook csv data from filter_gradebook.py

## grade_behavior.py

### Description
Summarizes student activity and performance on Canvas Gamification. Sorted by overall grade level and question categories, as TA (average total attempts), %A (average correct attempts), TQ (average total questions)

### Requirement:
- engagement csv data from engagement.py
- compiled grade data from grades.csv

## time_gap.py

### Description
Produces bar graph of the average time gap between students' attempts on questions per categories

### Requirement:
- time gap input csv file (currently excel generated; merged between attempts and gradebook csv file)


## state_diagram.py

### Description
Produces state diagram graph visualization of student's behavior/ activities on Canvas Gamification website

### Requirement:
- pip install networkx
- actor markov matrix csv

## filter_all_submissions.py

### Description
Filters out unnecessary rows for files that are beyond one year in duration

### Requirement:
- filtered consent csv file

## splitCSV.py

### Description
Splits large csv file into modifiable smaller parts

### Requirement:
- large actions.csv

## combineCSV.py 

### Description
Combines previously split csv into one csv

### Requirement:
- Separate parts of the csv (code modifiable based on the number of parts)

## get_skipped_ID.py

### Description
Returns csv with rows of skipped questions and their estimated index of difficulty

### Requirement:
- updated_output.csv
- actions_22_25.csv
- categories_with_difficulty.csv

## rename_actor.py

### Description
Renames user id who did course more than once as its own actor id (e.g. 388 becomes 3881 and 3882 for January and May sessions)

### Requirement:
- input.csv

## process_mining.R

### Description
Prepares raw data for process mapping

### Requirement:
- new_input.csv
- filter.csv
- grades.csv

## cluster_behavior_action.R

### Description
Clusters student data into groups based on commonly shared actions, with action_code as the nodes/ events

### Requirement:
- updated_output.csv

## cluster_behavior_srl.R

### Description
Clusters student data into groups based on commonly shared actions, with srl_subcategory as the nodes/ events

### Requirement:
- updated_output.csv

## cluster_fluctuations_action.R

### Description
- Clusters student data into groups based on fluctuation shift groups (Midterm 1 to Midterm 2 and Midterm 2 to Finals), with action_code as the nodes/ events. 
- Generates heatmaps for average frequency of each action_code by shift group. 
- Adds group information to skipped questions data

### Requirement:
- output_pruned.csv
- grades.csv
- gender.csv
- updated_output_skipped_questions.csv

## cluster_fluctuations_srl.R

### Description
- Clusters student data into groups based on fluctuation shift groups (Midterm 1 to Midterm 2 and Midterm 2 to Finals), with srl_subcategory as the nodes/ events. 
- Generates heatmaps for average frequency of each srl_subcategory by shift group. 

### Requirement:
- output_pruned.csv
- grades.csv

## cluster_grade_action.R

### Description
- Clusters student data into groups based on end of course grade level, with action_code as the nodes/ events. 
- Generates heatmaps for average frequency of each action_code by grade group. 

### Requirement:
- updated_output.csv

## cluster_grade_srl.R

### Description
- Clusters student data into groups based on end of course grade level, with srl_subcategory as the nodes/ events. 
- Generates heatmaps for average frequency of each srl_subcategory by grade group. 

### Requirement:
- updated_output.csv

## cluster_gender_action.R

### Description
- Clusters student data into groups based on gender, with action_code as the nodes/ events. 
- Generates heatmaps for average frequency of each action_code by gender group.

### Requirement:
- updated_output.csv

## cluster_gender_srl.R

### Description
- Clusters student data into groups based on gender, with srl_subcategory as the nodes/ events. 
- Generates heatmaps for average frequency of each srl_subcategory by gender group.

### Requirement:
- updated_output.csv

