# usageAnalysis

Analysis of data

## Project requirements:
- Python3

## Project setup
1. Insert csv files into the data folder

2. Make a python virtual environment
    ```bash
    python3 -m venv venv
    ```

3. Activate python virtual environment
    ```bash
    source venv/bin/activate
    ```

4. Install the required packages
    ```bash
    pip3 install -r requirements.txt
    ```

5. Launch Jupyter Notebook OR run filtering script
    ```bash
    python3 -m jupyterlab
    ```

    OR

    ```bash
    python3 -m src.scripts.<script_name_without_.py>
    ```

## Environment setup

1. Go to https://gamification.ok.ubc.ca/

2. Inspect page -> Network tab

3. Login to your gamification account

4. On Network tab select ``api-token-auth`` -> Preview -> token

5. Set ``GAMIFICATION_SUBMISSION_URL`` and ``GAMIFICATION_TOKEN`` with your token in your created ``.env`` file

## Running specific scripts

All scripts with their description and requirements.

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


## filter_submission.py

### Description
Filters actions csv data to get only student submissions. Gets question details for each submission and saves it into a csv file.

### Requirement:
- actions csv data from gamification


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


## barChart.py

### Description
Creates bar chart for submissions csv data for number of submissions per period of time (per week).

### Requirement:
- submissions csv data from filter_submission.py or filter_optional_submission.py


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
