-- SQL-скрипт для создания всех триггеров

-- Создание таблицы avg_salaries_with_level, если она еще не существует
-- Важно: UNIQUE ограничение необходимо для корректной работы INSERT OR REPLACE
CREATE TABLE IF NOT EXISTS avg_salaries_with_level (
    job_title TEXT,
    work_year INTEGER,
    company_location TEXT,
    level TEXT,
    salary_in_usd REAL,
    UNIQUE (job_title, work_year, company_location, level) ON CONFLICT REPLACE
);

-- Отключение внешних ключей временно, если вы работаете с базой данных, которая их строго применяет
-- PRAGMA foreign_keys = OFF;

--------------------------------------------------------------------------------
-- Триггеры для таблицы salaries_correct
--------------------------------------------------------------------------------

-- 1. Триггер AFTER INSERT на salaries_correct
-- Назначение: Обновить среднюю зарплату при добавлении новой записи в salaries_correct.
CREATE TRIGGER IF NOT EXISTS trg_salaries_correct_after_insert
AFTER INSERT ON salaries_correct
FOR EACH ROW
BEGIN
    INSERT OR REPLACE INTO avg_salaries_with_level (job_title, work_year, company_location, level, salary_in_usd)
    SELECT
        NEW.job_title,
        NEW.work_year,
        NEW.company_location,
        (SELECT level FROM experience_levels WHERE id = NEW.id) AS level,
        AVG(T1.salary_in_usd)
    FROM salaries_correct AS T1
    JOIN experience_levels AS T2 ON T1.id = T2.id
    WHERE T1.job_title = NEW.job_title
      AND T1.work_year = NEW.work_year
      AND T1.company_location = NEW.company_location
      AND T2.level = (SELECT level FROM experience_levels WHERE id = NEW.id);
END;

-- 2. Триггер AFTER UPDATE на salaries_correct
-- Назначение: Обновить среднюю зарплату при изменении существующей записи в salaries_correct.
CREATE TRIGGER IF NOT EXISTS trg_salaries_correct_after_update
AFTER UPDATE ON salaries_correct
FOR EACH ROW
BEGIN
    -- Пересчитываем для старой комбинации, используя OLD данные
    DELETE FROM avg_salaries_with_level
    WHERE job_title = OLD.job_title
      AND work_year = OLD.work_year
      AND company_location = OLD.company_location
      AND level = (SELECT level FROM experience_levels WHERE id = OLD.id);

    INSERT OR REPLACE INTO avg_salaries_with_level (job_title, work_year, company_location, level, salary_in_usd)
    SELECT
        OLD.job_title,
        OLD.work_year,
        OLD.company_location,
        (SELECT level FROM experience_levels WHERE id = OLD.id) AS level,
        AVG(T1.salary_in_usd)
    FROM salaries_correct AS T1
    JOIN experience_levels AS T2 ON T1.id = T2.id
    WHERE T1.job_title = OLD.job_title
      AND T1.work_year = OLD.work_year
      AND T1.company_location = OLD.company_location
      AND T2.level = (SELECT level FROM experience_levels WHERE id = OLD.id);

    -- Пересчитываем для новой комбинации, используя NEW данные
    INSERT OR REPLACE INTO avg_salaries_with_level (job_title, work_year, company_location, level, salary_in_usd)
    SELECT
        NEW.job_title,
        NEW.work_year,
        NEW.company_location,
        (SELECT level FROM experience_levels WHERE id = NEW.id) AS level,
        AVG(T1.salary_in_usd)
    FROM salaries_correct AS T1
    JOIN experience_levels AS T2 ON T1.id = T2.id
    WHERE T1.job_title = NEW.job_title
      AND T1.work_year = NEW.work_year
      AND T1.company_location = NEW.company_location
      AND T2.level = (SELECT level FROM experience_levels WHERE id = NEW.id);
END;

-- 3. Триггер AFTER DELETE на salaries_correct
-- Назначение: Обновить среднюю зарплату при удалении записи из salaries_correct.
CREATE TRIGGER IF NOT EXISTS trg_salaries_correct_after_delete
AFTER DELETE ON salaries_correct
FOR EACH ROW
BEGIN
    DELETE FROM avg_salaries_with_level
    WHERE job_title = OLD.job_title
      AND work_year = OLD.work_year
      AND company_location = OLD.company_location
      AND level = (SELECT level FROM experience_levels WHERE id = OLD.id);

    -- Если остались еще записи для этой комбинации, пересчитываем и вставляем/обновляем
    INSERT OR REPLACE INTO avg_salaries_with_level (job_title, work_year, company_location, level, salary_in_usd)
    SELECT
        OLD.job_title,
        OLD.work_year,
        OLD.company_location,
        (SELECT level FROM experience_levels WHERE id = OLD.id) AS level,
        AVG(T1.salary_in_usd)
    FROM salaries_correct AS T1
    JOIN experience_levels AS T2 ON T1.id = T2.id
    WHERE T1.job_title = OLD.job_title
      AND T1.work_year = OLD.work_year
      AND T1.company_location = OLD.company_location
      AND T2.level = (SELECT level FROM experience_levels WHERE id = OLD.id);
END;

--------------------------------------------------------------------------------
-- Триггеры для таблицы experience_levels
--------------------------------------------------------------------------------

-- 4. Триггер AFTER INSERT на experience_levels
-- Назначение: Обновить среднюю зарплату при добавлении новой записи в experience_levels.
CREATE TRIGGER IF NOT EXISTS trg_experience_levels_after_insert
AFTER INSERT ON experience_levels
FOR EACH ROW
WHEN (SELECT COUNT(*) FROM salaries_correct WHERE id = NEW.id) > 0 -- Только если есть соответствующая запись в salaries_correct
BEGIN
    INSERT OR REPLACE INTO avg_salaries_with_level (job_title, work_year, company_location, level, salary_in_usd)
    SELECT
        T1.job_title,
        T1.work_year,
        T1.company_location,
        NEW.level,
        AVG(T3.salary_in_usd)
    FROM salaries_correct AS T1
    JOIN experience_levels AS T2 ON T1.id = T2.id
    LEFT JOIN salaries_correct AS T3 ON T3.job_title = T1.job_title AND T3.work_year = T1.work_year AND T3.company_location = T1.company_location
    LEFT JOIN experience_levels AS T4 ON T3.id = T4.id AND T4.level = NEW.level
    WHERE T1.id = NEW.id;
END;

-- 5. Триггер AFTER UPDATE на experience_levels
-- Назначение: Обновить среднюю зарплату при изменении уровня опыта для записи.
CREATE TRIGGER IF NOT EXISTS trg_experience_levels_after_update
AFTER UPDATE ON experience_levels
FOR EACH ROW
WHEN OLD.level != NEW.level AND (SELECT COUNT(*) FROM salaries_correct WHERE id = NEW.id) > 0
BEGIN
    -- Пересчитываем для старой комбинации, используя OLD.level
    DELETE FROM avg_salaries_with_level
    WHERE job_title = (SELECT job_title FROM salaries_correct WHERE id = OLD.id)
      AND work_year = (SELECT work_year FROM salaries_correct WHERE id = OLD.id)
      AND company_location = (SELECT company_location FROM salaries_correct WHERE id = OLD.id)
      AND level = OLD.level;

    INSERT OR REPLACE INTO avg_salaries_with_level (job_title, work_year, company_location, level, salary_in_usd)
    SELECT
        T1.job_title,
        T1.work_year,
        T1.company_location,
        OLD.level,
        AVG(T3.salary_in_usd)
    FROM salaries_correct AS T1
    JOIN experience_levels AS T2 ON T1.id = T2.id
    LEFT JOIN salaries_correct AS T3 ON T3.job_title = T1.job_title AND T3.work_year = T1.work_year AND T3.company_location = T1.company_location
    LEFT JOIN experience_levels AS T4 ON T3.id = T4.id AND T4.level = OLD.level
    WHERE T1.id = OLD.id;


    -- Пересчитываем для новой комбинации, используя NEW.level
    INSERT OR REPLACE INTO avg_salaries_with_level (job_title, work_year, company_location, level, salary_in_usd)
    SELECT
        T1.job_title,
        T1.work_year,
        T1.company_location,
        NEW.level,
        AVG(T3.salary_in_usd)
    FROM salaries_correct AS T1
    JOIN experience_levels AS T2 ON T1.id = T2.id
    LEFT JOIN salaries_correct AS T3 ON T3.job_title = T1.job_title AND T3.work_year = T1.work_year AND T3.company_location = T1.company_location
    LEFT JOIN experience_levels AS T4 ON T3.id = T4.id AND T4.level = NEW.level
    WHERE T1.id = NEW.id;
END;

-- 6. Триггер AFTER DELETE на experience_levels
-- Назначение: Обновить среднюю зарплату при удалении записи из experience_levels.
CREATE TRIGGER IF NOT EXISTS trg_experience_levels_after_delete
AFTER DELETE ON experience_levels
FOR EACH ROW
BEGIN
    DELETE FROM avg_salaries_with_level
    WHERE job_title = (SELECT job_title FROM salaries_correct WHERE id = OLD.id)
      AND work_year = (SELECT work_year FROM salaries_correct WHERE id = OLD.id)
      AND company_location = (SELECT company_location FROM salaries_correct WHERE id = OLD.id)
      AND level = OLD.level;

    -- Если остались еще записи для этой комбинации, пересчитываем и вставляем/обновляем
    INSERT OR REPLACE INTO avg_salaries_with_level (job_title, work_year, company_location, level, salary_in_usd)
    SELECT
        T1.job_title,
        T1.work_year,
        T1.company_location,
        OLD.level,
        AVG(T3.salary_in_usd)
    FROM salaries_correct AS T1
    JOIN experience_levels AS T2 ON T1.id = T2.id
    LEFT JOIN salaries_correct AS T3 ON T3.job_title = T1.job_title AND T3.work_year = T1.work_year AND T3.company_location = T1.company_location
    LEFT JOIN experience_levels AS T4 ON T3.id = T4.id AND T4.level = OLD.level
    WHERE T1.id = OLD.id;
END;

-- Включение внешних ключей обратно, если вы их временно отключали
-- PRAGMA foreign_keys = ON;