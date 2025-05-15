import sqlite3
import pandas as pd


df = pd.read_csv('average_salary_by_year_country_title.csv')

conn = sqlite3.connect('salary.db')

df.to_sql('avg_salaries', conn, if_exists='replace', index=False)

conn.close()
print("CSV успешно загружен в таблицу 'avg_salaries'")
