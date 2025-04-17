![image](https://github.com/user-attachments/assets/78f37c4e-461e-4bc6-972f-94fdd476c548)


#### process_mining.R

The process_mining.R takes various input data source file and maps user behaviours to SRL subcategories, filter records based on student IDs and grade ranges. It generates a cleaned combined output filed output.csv and visualizes student behavior patterns using a Markov model with pMineR library.
##### Required Packages

The following R packages are required to run the script. Use the following commands to install them.

| Package    | Installation Command                                    |
| ---------- | ------------------------------------------------------- |
| lubridate  | `install.packages(lubridate)`                           |
| dplyr      | `install.packages(dplyr)`                               |
| DiagrammeR | `install.packages(DiagrammeR)`                          |
| remotes    | `install.packages(remotes)`                             |
| pMineR     | `remotes::install_github(PMLiquidLab/pMineR.v046@main)` |
##### Input Data Files

The following three input files must be placed under the working directory of R. Please note these three input files are created manually putting 
relevant data together from source data files. Sample files can be found on OneDrive.

To check the current working directory
`getwd()`

To set a new working directory
`setwd("path/to/folder")`
###### input.csv
| Column Name     | Description                                                                   | Source        |
| --------------- | ----------------------------------------------------------------------------- | ------------- |
| actor           | The identifier of an user of the system                                       | actions.csv   |
| description     | Text description of the user action                                           | actions.csv   |
| time_created    | Timestamp of when the action occurred                                         | actions.csv   |
| question_status | Outcome of the question attempt (e.g., Correct, Incorrect, Partially Correct) | TimeInput.csv |
| nth_attempt     | The number of times the user has attempted this specific question             | TimeInput.csv |
| question_id     | Unique identifier for the question being attempted                            | TimeInput.csv |
###### filter.csv
| Column Name | Description                                                   | Source           |
| ----------- | ------------------------------------------------------------- | ---------------- |
| user        | Unique identifier for the user                                | all-consents.csv |
| consent     | Indicates whether the user gave research consent (TRUE/FALSE) | all-consents.csv |
| is_student  | Indicates whether the user is a student (TRUE/FALSE)          | all-consents.csv |
###### grades.csv
| Column Name | Description                        | Source               |
| ----------- | ---------------------------------- | -------------------- |
| actor_id    | The unique identifier of a student | grades.csv           |
| lab         | % score of lab component           | various grades files |
| mid_1       | % score of midterm 1               | various grades files |
| mid_2       | % score of midterm 2               | various grades files |
| final_exam  | % score of final exam              | various grades files |
| final_score | Final course grade of the student  | grades.csv           |

##### Action Code Mapping
The list of actions is originated from the source file actions.csv

| Description                                                               | Action Code                        | Note                  |
| ------------------------------------------------------------------------- | ---------------------------------- | --------------------- |
| Submission was evaluated                                                  | submission_evaluated               | Student Action        |
| User added goal item                                                      | add_goal_item                      | Student Action        |
| User clicked on next question                                             | clicked_next_question              | Student Action        |
| User consented.                                                           | consented                          | Student Action        |
| User removed their consent.                                               | removed_consent                    | Student Action        |
| User created a goal item.                                                 | created_goal_item                  | Student Action        |
| User created a goal.                                                      | created_goal                       | Student Action        |
| User created a new report.                                                | created_report                     | Student Action        |
| User created a team.                                                      | created_team                       | Not seen in 2024 data |
| User created an event.                                                    | created_event                      | Not seen in 2024 data |
| User deleted a question.                                                  | deleted_question                   | Admin Only            |
| User imported an event.                                                   | imported_event                     | Admin Only            |
| User joined a team.                                                       | joined_team                        | Not seen in 2024 data |
| User logged in                                                            | logged_in                          | Student Action        |
| User requested a password reset email.                                    | requested_password_reset           | Student Action        |
| User reset their password.                                                | reset_password                     | Student Action        |
| User selected a category on the concept map                               | selected_category                  | Student Action        |
| User selected assignments and exams on the course homepage                | selected_assignments               | Student Action        |
| User selected challenges on the course homepage                           | selected_challenges                | Student Action        |
| User selected leaderboard on the course homepage                          | selected_leaderboard               | Student Action        |
| User selected practice on the course homepage                             | selected_practice_from_concept_map | Student Action        |
| User started practice from goal                                           | started_practice_from_goal         | Student Action        |
| User submitted a solution                                                 | submitted_solution                 | Student Action        |
| User updated a question.                                                  | updated_question                   | Admin Only            |
| User updated an event.                                                    | updated_event                      | Not seen in 2024 data |
| User updated their profile.                                               | updated_profile                    | Student Action        |
| User used recommended goal                                                | used_recommended_goal              | Student Action        |
| User viewed personal ranking and tokens earned on the course leader board | viewed_personal_ranking            | Student Action        |
| User viewed team ranking and tokens earned on a challenge leader board    | viewed_team_ranking                | Student Action        |
|                                                                           |                                    |                       |
##### SRL Subcategory Maping

| Action Code                           | SRL Subcategory                 |
| ------------------------------------- | ------------------------------- |
| created_goal                          | Goal Setting & Planning         |
| add_goal_item                         | Goal Setting & Planning         |
| created_goal_item                     | Goal Setting & Planning         |
| started_practice_from_goal            | Goal Setting & Planning         |
| used_recommended_goal                 | Implementation                  |
| created_report                        | Evaluation & Reflection         |
| submitted_solution (1st attempt)      | Initial Attempt & Retry         |
| submitted_solution (no prior correct) | Evaluation & Reflection         |
| submitted_solution (prior correct)    | Revisiting & Reviewing          |
| viewed_personal_ranking               | Social & Engagement             |
| viewed_team_ranking                   | Social & Engagement             |
| created_team                          | Social & Engagement             |
| joined_team                           | Social & Engagement             |
| selected_assignments                  | Orientation                     |
| selected_challenges                   | Orientation                     |
| selected_leaderboard                  | Orientation                     |
| selected_practice_from_goal           | Orientation                     |
| selected_category                     | Orientation                     |
| clicked_next_question                 | Orientation                     |
| selected_practice_from_concept_map    | Orientation                     |
| logged_in                             | Begin                           |
| requested_password_reset              | Setup, Technical & Account Mgmt |
| reset_password                        | Setup, Technical & Account Mgmt |
| updated_profile                       | Setup, Technical & Account Mgmt |
##### SRL Category Explanation
| Main Category | Subcategory                    | Code  | Description                                                                                         |
| ------------- | ------------------------------ | ----- | --------------------------------------------------------------------------------------------------- |
| Metacognition | Goal Setting & Planning        | MC.P  | The learner sets or adjusts goals and strategies.                                                   |
|               | Progress Monitoring            | MC.M  | The learner monitors progress by tracking performance relative to goals.                            |
|               | Evaluation & Reflection        | MC.E  | The learner evaluates outcomes and reflects on performance.                                         |
| Cognition     | Initial Attempt & Retry        | C.A   | The learner engages with content through first attempts or retries on assessments.                  |
|               | Revisiting & Reviewing         | C.R   | The learner reviews/re-attempts previously solved materials or practices topics they have mastered. |
|               | Implementation                 | C.I   | The learner executes study plans by engaging with tasks, focusing on areas, or by difficulty level. |
| Motivation    | Social & Engagement            | M.S   | The learner engages in social or motivational actions.                                              |
| Procedural    | Orientation                    | P.O   | The learner orients to the platform environment.                                                    |
|               | Technical & Account Management | P.T&M | The learner manages account-related tasks or technical settings.                                    |
#### clustering.R
This script performs clustering and process mining analysis on student action sequence. It computes transition frequencies between actions, filter statistically insignificant transitions using z-scores, applies k-means clustering to group students based on their behavior, and then visualizes the clustered behavior patterns using the first-order Markov models with pMineR.

##### Required Packages
| Package    | Installation Command                                      |
| ---------- | --------------------------------------------------------- |
| lubridate  | `install.packages("lubridate")`                           |
| dplyr      | `install.packages("dplyr")`                               |
| tidyr      | `install.packages("tidyr")`                               |
| pheatmap   | `install.packages("pheatmap")`                            |
| reshape2   | `install.packages("reshape2")`                            |
| tibble     | `install.packages("tibble")`                              |
| cluster    | `install.packages("cluster")`                             |
| factoextra | `install.packages("factoextra")`                          |
| ggplot2    | `install.packages("ggplot2")`                             |
| DiagrammeR | `install.packages("DiagrammeR")`                          |
| remotes    | `install.packages("remotes")`                             |
| <br>pMineR | `remotes::install_github("PMLiquidLab/pMineR.v046@main")` |
##### Input Data Files

The output.csv generated from process_minine.R is required to put under working directory. output_clustered.csv will be generated showing the clustering of each student based on k value. output_clustered_cleaned.csv will be generated to drop the filtered out statistically insignificant actions.
