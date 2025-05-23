import sqlite3
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os

# Подключение к базе данных
conn = sqlite3.connect("salary.db")

# Запрос теперь к новой таблице avg_salaries_with_level
query = "SELECT * FROM avg_salaries_with_level"
df = pd.read_sql_query(query, conn)
conn.close()

# --- Параметры для фильтрации данных ---
country = 'IN'  # Пример страны
job = 'Data Analyst'  # Пример должности
level = 'EN'  # Пример SE, MI ,EX,EN
# ----------------------------------------

# Фильтрация данных по стране, должности И ГРЕЙДУ
filtered = df[(df['company_location'] == country) &
              (df['job_title'] == job) &
              (df['level'] == level)].copy()

# Если после фильтрации нет данных, выводим сообщение и завершаем выполнение
if filtered.empty:
    print(f"Нет данных для '{job}' с грейдом '{level}' в '{country}'. Проверьте параметры.")
else:
    # Округление work_year (если нужно, но для года это обычно не требуется)
    filtered['work_year'] = filtered['work_year'].round(0)  # Округляем до целых чисел, так как это годы

    # Группировка данных по году и расчет среднего
    # Группировка теперь не требуется, так как avg_salaries_with_level уже содержит средние по этим группам.
    # Просто убедимся, что столбец 'mean_salary' соответствует 'salary_in_usd'
    grouped = filtered[['work_year', 'salary_in_usd']].copy()
    grouped.columns = ['work_year', 'mean_salary']

    # Сортируем по году для корректного построения модели
    grouped = grouped.sort_values('work_year').reset_index(drop=True)

    # Проверка наличия данных за 2022 год
    if 2022.0 not in grouped['work_year'].values:
        print(f"Нет данных за 2022 год для '{job}' с грейдом '{level}' в '{country}' — невозможно вычислить S₀")
    else:
        S0 = grouped.loc[grouped['work_year'] == 2022.0, 'mean_salary'].values[0]

        # Точки для построения модели (после 2022 года)
        model_points = grouped[grouped['work_year'] > 2022.0].copy()
        if model_points.empty:
            print(
                f"Нет данных после 2022 года для '{job}' с грейдом '{level}' в '{country}' — построение модели невозможно.")
        else:
            model_points['t'] = model_points['work_year'] - 2022.0
            model_points['ln_salary'] = np.log(model_points['mean_salary'])

            X = model_points['t'].values.reshape(-1, 1)
            y = model_points['ln_salary'].values

            # Добавляем столбец единиц для свободного члена (intercept) в линейной регрессии
            X_with_intercept = np.c_[X, np.ones(X.shape[0])]

            # Решение системы линейных уравнений
            coeffs, residuals, rank, s = np.linalg.lstsq(X_with_intercept, y, rcond=None)
            a, b = coeffs[0], coeffs[1]  # a - наклон, b - свободный член

            # Построение модели для графика
            t_model = np.linspace(0, max(model_points['t'].max(), 7),
                                  100)  # Прогнозируем на 5 лет вперед или до последнего года в данных
            ln_S_model = a * t_model + b
            S_model = np.exp(ln_S_model)

            # Построение графика
            plt.figure(figsize=(12, 6))
            plt.scatter(model_points['t'], model_points['mean_salary'], color='blue',
                        label='Фактические средние (после 2022)')
            plt.plot(t_model, S_model, color='red', label=f'Логарифмическая модель: $ln(S) = {a:.4f}t + {b:.4f}$')
            plt.scatter(0, S0, color='green', zorder=5, label='Средняя за 2022 (S₀)')

            plt.title(f"Логарифмическая модель зарплаты: {job} ({level}) в {country}", fontsize=16)
            plt.xlabel("t (годы с 2022)", fontsize=12)
            plt.ylabel("Средняя зарплата (USD)", fontsize=12)
            plt.grid(True)
            plt.legend(fontsize=10)
            plt.tight_layout()

            # Сохранение графика
            output_dir = "output_graphs"  # Изменил название директории, чтобы избежать конфликтов
            os.makedirs(output_dir, exist_ok=True)
            filename = f"{country}_{job.replace(' ', '_')}_{level.replace(' ', '_')}_log_salary_model.png"
            save_path = os.path.join(output_dir, filename)
            plt.savefig(save_path, bbox_inches='tight', dpi=300)

            print(f"График сохранен в {save_path}")
            plt.show()