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

## Order of scripts to run

1. filter_consent.py
2. filter_optional_submissions.py
3. track_attempts.py
4. engagement.py
5. barChart.py
6. filter_gradebook.py
7. grade_behavior.py
8. time_gap.py
9. state_diagram.py


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
- actor markov matrix csv
