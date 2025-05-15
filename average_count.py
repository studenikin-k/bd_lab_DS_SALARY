import sqlite3
import pandas as pd


conn = sqlite3.connect('salary.db')


df = pd.read_sql_query("""
    SELECT job_title, work_year, company_location, salary_in_usd
    FROM salaries
""", conn)


agg_df = df.groupby(['job_title', 'work_year', 'company_location'])['salary_in_usd'].mean().reset_index()


agg_df.to_sql('avg_salaries', conn, if_exists='replace', index=False)



conn.close()
