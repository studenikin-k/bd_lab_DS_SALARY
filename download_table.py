import sqlite3
import csv


conn = sqlite3.connect('salary.db')
cursor = conn.cursor()


cursor.execute("SELECT * FROM salaries")
rows = cursor.fetchall()


with open('output_salary.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow([i[0] for i in cursor.description])
    writer.writerows(rows)

conn.close()