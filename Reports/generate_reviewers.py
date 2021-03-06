#Requirements
#pandas, xlrd, openpyxl

import random
import pandas
import logging
import os

#log errors
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s', handlers=[logging.handlers.RotatingFileHandler("generate_reviewers_log.txt", maxBytes=100000, backupCount=0)])
logging.info('Running generate reviewers')
logging.info(f'Directory: {os.getcwd()}')
logging.info(f'students_reviewers.xlsx Exists? {os.path.isfile("students_reviewers.xlsx")}')


#Get Data from Excel file
excel_file = pandas.read_excel('students_reviewers.xlsx')
reviewers = list(excel_file[['Reviewer','Reviewer Dept']].dropna(how='any').to_dict('index').values())
students = list(excel_file[['Student','Student Dept']].dropna(how='any').to_dict('index').values())

#Initialize count and assigned
i = 0
for reviewer in reviewers:
    reviewer['id'] = i
    reviewer['Count'] = 0
    reviewer['Assigned'] = []
    i = i + 1

#Loop through each student and assign reviewers
for student in students:
    student_dept = student['Student Dept']
    student_name = student['Student']

    in_dept_reviewers = list(filter(lambda x: x['Reviewer Dept'] == student_dept,reviewers))
    out_dept_reviewers = list(filter(lambda x: x['Reviewer Dept'] != student_dept,reviewers))

    if len(in_dept_reviewers) == 0:
        in_dept_reviewers = out_dept_reviewers

    random.shuffle(in_dept_reviewers)
    random.shuffle(out_dept_reviewers)

    #Loop through in department reviewers and assign reviewer with lowest assigned
    in_dept_reviewer = in_dept_reviewers[0]
    for reviewer in in_dept_reviewers:
        if reviewer['Count'] < in_dept_reviewer['Count']:
            in_dept_reviewer = reviewer
    reviewers[in_dept_reviewer['id']]['Assigned'].append(student_name)
    reviewers[in_dept_reviewer['id']]['Count'] = in_dept_reviewer['Count'] + 1

    #Ensure they can't be assigned to same reviewer
    if in_dept_reviewer in out_dept_reviewers:
        out_dept_reviewers.remove(in_dept_reviewer)

    #Repeat for out department reviewers
    out_dept_reviewer = out_dept_reviewers[0]
    for reviewer in out_dept_reviewers:
        if reviewer['Count'] < out_dept_reviewer['Count']:
            out_dept_reviewer = reviewer
    reviewers[out_dept_reviewer['id']]['Assigned'].append(student_name)
    reviewers[out_dept_reviewer['id']]['Count'] = out_dept_reviewer['Count'] + 1

df = pandas.DataFrame(reviewers)
del df['id']
df.to_excel(r'Output.xlsx')
