-- Employee Attrition Analysis
-- Schema: employees (fact) + dim_department, dim_job_role, dim_education
-- DB: attrition.db (SQLite)

-- 1. Headcount and attrition rate
SELECT
    COUNT(*) AS headcount,
    SUM(attrition) AS attritions,
    ROUND(100.0 * SUM(attrition) / COUNT(*), 2) AS attrition_rate_pct
FROM employees;


-- 2. Attrition rate by department, ranked
SELECT
    d.department_name,
    COUNT(*) AS headcount,
    SUM(e.attrition) AS attritions,
    ROUND(100.0 * SUM(e.attrition) / COUNT(*), 2) AS attrition_rate_pct,
    RANK() OVER (ORDER BY 1.0 * SUM(e.attrition) / COUNT(*) DESC) AS attrition_rank
FROM employees e
JOIN dim_department d ON d.department_id = e.department_id
GROUP BY d.department_name
ORDER BY attrition_rate_pct DESC;


-- 3. Department x job role attrition matrix
SELECT
    d.department_name,
    r.job_role_name,
    COUNT(*) AS headcount,
    ROUND(100.0 * SUM(e.attrition) / COUNT(*), 2) AS attrition_rate_pct
FROM employees e
JOIN dim_department d ON d.department_id = e.department_id
JOIN dim_job_role r ON r.job_role_id = e.job_role_id
GROUP BY d.department_name, r.job_role_name
ORDER BY d.department_name, attrition_rate_pct DESC;


-- 4. The high-risk segment: overtime + low job satisfaction
-- (this is the one variable combination that actually drives attrition in this data)
SELECT
    overtime,
    CASE WHEN job_satisfaction <= 2 THEN 'Low (1-2)' ELSE 'OK (3-5)' END AS satisfaction_bucket,
    COUNT(*) AS headcount,
    SUM(attrition) AS attritions,
    ROUND(100.0 * SUM(attrition) / COUNT(*), 2) AS attrition_rate_pct
FROM employees
GROUP BY overtime, satisfaction_bucket
ORDER BY attrition_rate_pct DESC;


-- 5. CTE + window function: income quartile vs attrition
WITH ranked AS (
    SELECT
        employee_id,
        monthly_income,
        attrition,
        NTILE(4) OVER (ORDER BY monthly_income) AS income_quartile
    FROM employees
)
SELECT
    income_quartile,
    COUNT(*) AS headcount,
    ROUND(100.0 * SUM(attrition) / COUNT(*), 2) AS attrition_rate_pct
FROM ranked
GROUP BY income_quartile
ORDER BY income_quartile;


-- 6. Correlated subquery: employees earning above their own department's average
SELECT
    e.employee_id,
    d.department_name,
    e.monthly_income,
    e.attrition
FROM employees e
JOIN dim_department d ON d.department_id = e.department_id
WHERE e.monthly_income > (
    SELECT AVG(e2.monthly_income)
    FROM employees e2
    WHERE e2.department_id = e.department_id
)
LIMIT 20;


-- 7. Window function: rank employees by tenure within their department, top 3 per dept
-- (SQLite has no QUALIFY clause like Snowflake/BigQuery, so filter the ranked CTE instead)
WITH ranked AS (
    SELECT
        employee_id,
        department_id,
        company_tenure,
        ROW_NUMBER() OVER (PARTITION BY department_id ORDER BY company_tenure DESC) AS tenure_rank_in_dept
    FROM employees
)
SELECT * FROM ranked WHERE tenure_rank_in_dept <= 3
ORDER BY department_id, tenure_rank_in_dept;


-- 8. LAG: change in average income as job level increases
WITH by_level AS (
    SELECT job_level, ROUND(AVG(monthly_income), 0) AS avg_income
    FROM employees
    GROUP BY job_level
)
SELECT
    job_level,
    avg_income,
    avg_income - LAG(avg_income) OVER (ORDER BY job_level) AS income_jump_from_prev_level
FROM by_level
ORDER BY job_level;


-- 9. View: high-risk employee list, for reuse in Excel/Power BI refreshes
DROP VIEW IF EXISTS v_high_risk_employees;
CREATE VIEW v_high_risk_employees AS
SELECT
    e.employee_id, d.department_name, r.job_role_name, e.age, e.monthly_income,
    e.job_satisfaction, e.work_hours_per_week, e.company_tenure, e.attrition
FROM employees e
JOIN dim_department d ON d.department_id = e.department_id
JOIN dim_job_role r ON r.job_role_id = e.job_role_id
WHERE e.overtime = 'Yes' AND e.job_satisfaction <= 2;

SELECT COUNT(*) AS high_risk_headcount,
       ROUND(100.0 * SUM(attrition) / COUNT(*), 2) AS attrition_rate_pct
FROM v_high_risk_employees;


-- 10. Departments with above-overall attrition rate (subquery in HAVING)
SELECT
    d.department_name,
    ROUND(100.0 * SUM(e.attrition) / COUNT(*), 2) AS dept_attrition_rate_pct
FROM employees e
JOIN dim_department d ON d.department_id = e.department_id
GROUP BY d.department_name
HAVING (1.0 * SUM(e.attrition) / COUNT(*)) > (
    SELECT 1.0 * SUM(attrition) / COUNT(*) FROM employees
)
ORDER BY dept_attrition_rate_pct DESC;


-- 11. Running total of headcount by tenure group (for a retention curve)
WITH tenure_counts AS (
    SELECT tenure_group,
           MIN(company_tenure) AS sort_key,
           COUNT(*) AS headcount
    FROM employees
    GROUP BY tenure_group
)
SELECT
    tenure_group,
    headcount,
    SUM(headcount) OVER (ORDER BY sort_key) AS running_total
FROM tenure_counts
ORDER BY sort_key;


-- 12. Education level vs performance rating vs attrition (three-way cut)
SELECT
    ed.education_level,
    e.performance_rating,
    COUNT(*) AS headcount,
    ROUND(100.0 * SUM(e.attrition) / COUNT(*), 2) AS attrition_rate_pct
FROM employees e
JOIN dim_education ed ON ed.education_id = e.education_id
GROUP BY ed.education_level, e.performance_rating
ORDER BY ed.education_level, e.performance_rating;
