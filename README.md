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

## filterSubmissions.py

1. Go to https://gamification.ok.ubc.ca/

2. Inspect page -> Network tab

3. Login to your gamification account

4. On Network tab select ``api-token-auth`` -> Preview -> token

5. Set ``GAMIFICATION_SUBMISSION_URL`` and ``GAMIFICATION_TOKEN`` with your token

6. Make sure you have your actions csv filtered first with filterConsent.py

7. Run filterSubmissions.py file one your filtered actions csv by consent
    ```bash
        python3 -m src.scripts.filter_submissions
    ```