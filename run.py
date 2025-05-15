import csv
import sqlite3

conn = sqlite3.connect("salary.db")
cursor = conn.cursor()


column_types = {
    "id": "INTEGER",
    "work_year": "INTEGER",
    "experience_level": "TEXT",
    "employment_type": "TEXT",
    "job_title": "TEXT",
    "salary_currency": "TEXT",
    "salary_in_usd": "INTEGER",
    "employee_residence": "TEXT",
    "remote_ratio": "INTEGER",
    "company_location": "TEXT",
    "company_size": "TEXT"
}

with open("filtered_ds_salaries.csv", "r", encoding="utf-8") as file:
    reader = csv.reader(file)
    header = next(reader)


    columns_definition = ", ".join([f'"{col}" {column_types.get(col, "TEXT")}' for col in header])
    cursor.execute(f'CREATE TABLE IF NOT EXISTS salaries ({columns_definition})')


    placeholders = ", ".join(["?"] * len(header))
    for row in reader:
        try:
            cursor.execute(f'INSERT INTO salaries VALUES ({placeholders})', row)
        except sqlite3.IntegrityError as e:
            print(f"Ошибка при вставке строки {row}: {e}")
            continue

conn.commit()
conn.close()