# Power BI — Employee Attrition Report

Files: `fact_employees.csv`, `dim_department.csv`, `dim_job_role.csv`, `dim_education.csv`

## 1. Load and model

Get Data > Text/CSV, import all four files. In Model view, set up these relationships (all one-to-many, single direction, from dim to fact):

- `dim_department[department_id]` → `fact_employees[department_id]`
- `dim_job_role[job_role_id]` → `fact_employees[job_role_id]`
- `dim_education[education_id]` → `fact_employees[education_id]`

Mark `dim_department`, `dim_job_role`, `dim_education` as the "one" side. Hide the `*_id` key columns from report view once relationships are set (right-click column > Hide) so they don't clutter the field list.

## 2. Measures

Create these in a new table (Modeling > New Table > name it `_Measures`, or just add them to `fact_employees`):

```
Total Employees = COUNTROWS(fact_employees)

Attrition Count = CALCULATE([Total Employees], fact_employees[attrition] = 1)

Attrition Rate = DIVIDE([Attrition Count], [Total Employees])

High Risk Headcount =
CALCULATE([Total Employees], fact_employees[high_risk_segment] = "High Risk")

High Risk Attrition Rate =
CALCULATE([Attrition Rate], fact_employees[high_risk_segment] = "High Risk")

Avg Monthly Income = AVERAGE(fact_employees[monthly_income])

Avg Tenure = AVERAGE(fact_employees[company_tenure])

Attrition Rate - Prior Dept Rank =
VAR CurrentRate = [Attrition Rate]
RETURN
    RANKX(ALL(dim_department[department_name]), CALCULATE([Attrition Rate]), , DESC)
```

`Attrition Rate` is the one measure basically every visual should use instead of raw counts — it's what actually changes across segments; headcount alone doesn't tell you much given the departments are almost evenly sized.

## 3. Report pages

**Page 1 — Overview**
- Three cards across the top: `[Total Employees]`, `[Attrition Count]`, `[Attrition Rate]`
- Bar chart: `dim_department[department_name]` on axis, `[Attrition Rate]` as value
- Bar chart: `high_risk_segment` on axis, `[Attrition Rate]` as value — this is the one chart that should stand out on the page, since it's the actual driver
- Slicers along the left: Department, Job Role, Age Group

**Page 2 — Deep dive**
- Matrix visual: rows = `department_name`, columns = `job_role_name`, values = `[Attrition Rate]` — conditional formatting (background color) on the values so the pattern is visible at a glance
- Line or clustered column: `income_band` vs `[Attrition Rate]`
- Table: `v_high_risk_employees`-equivalent — filter the fact table visual to `overtime = "Yes"` and `job_satisfaction <= 2`, show employee_id, department, job_role, monthly_income, company_tenure

**Page 3 — Employee detail**
- Table/list of individual employees with a slicer panel, for drilling into any segment from the other two pages (right-click > Drill through, set up drillthrough on `employee_id`)

## 4. Notes

- `job_satisfaction`, `performance_rating`, `manager_rating`, `work_life_balance`, `environment_satisfaction`, `relationship_satisfaction` are all 1–5 scales — treat as categorical on slicers, not continuous axes.
- `age_group`, `income_band`, `tenure_group`, `high_risk_segment` are pre-binned in Python already, so no need to re-bucket them in DAX.
- The one pattern worth building the whole report around: attrition is close to 0% everywhere except `overtime = Yes` and `job_satisfaction <= 2`, where it jumps to ~25%. Every other split (department, education, age, income, tenure) is flat around 5%. Lead with that on page 1 rather than burying it.
