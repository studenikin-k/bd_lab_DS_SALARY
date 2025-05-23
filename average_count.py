import sqlite3
import pandas as pd

conn = sqlite3.connect('salary.db')

#
df = pd.read_sql_query("""
    SELECT 
        s.job_title, 
        s.work_year, 
        s.company_location, 
        s.salary_in_usd,
        e.level 
    FROM salaries s
    JOIN experience_levels e ON s.id = e.id
""", conn)

# Группируем данные по должности, году, местоположению компании и уровню опыта,
# и рассчитываем среднюю зарплату
agg_df = df.groupby(['job_title', 'work_year', 'company_location', 'level'])['salary_in_usd'].mean().reset_index()

# Записываем агрегированные данные в новую таблицу avg_salaries_with_level
# Вы можете выбрать другое имя таблицы, если хотите сохранить старую avg_salaries
agg_df.to_sql('avg_salaries_with_level', conn, if_exists='replace', index=False)

conn.close()