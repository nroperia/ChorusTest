-- ─────────────────────────────────────────────────────────────
-- SEED: REFERENCE DATA GENERATRED BY THE MODEL
-- ─────────────────────────────────────────────────────────────

-- Allow explicit value insert into IDENTITY column temporarily
SET IDENTITY_INSERT dim_occurrence_status ON;

INSERT INTO dim_occurrence_status
    (status_key, status_code,    status_label,  status_category, is_terminal, sort_order)
VALUES
    (1, 'not_started', 'Not Started', 'active',   0, 1),
    (2, 'in_progress', 'In Progress', 'active',   0, 2),
    (3, 'completed',   'Completed',   'terminal', 1, 3);

SET IDENTITY_INSERT dim_occurrence_status OFF;
GO


-- ─────────────────────────────────────────────────────────────
-- SEED: SAMPLE PEOPLE
-- ─────────────────────────────────────────────────────────────

INSERT INTO dim_person
    (person_id, first_name, last_name, email, department, role_title, effective_date)
VALUES
    ('P001', 'Ricardo', 'Garcia',   'r.garcia@example.com',   'Operations', 'Analyst',   '2025-01-01'),
    ('P002', 'Shanaya', 'Patel',    's.patel@example.com',    'Operations', 'Lead',      '2025-01-01'),
    ('P003', 'Daniel',  'Thompson', 'd.thompson@example.com', 'Operations', 'Associate', '2025-01-01');
GO


-- ─────────────────────────────────────────────────────────────
-- SEED: SAMPLE TASK DEFINITIONS
-- ─────────────────────────────────────────────────────────────

INSERT INTO dim_task_definition
    (task_code,          task_title,        cadence,   max_occurrences, priority)
VALUES
    ('MONTHLY-REVIEW',   'Monthly Review',  'monthly', 12,  'high'),
    ('KICKOFF-MEETING',  'Kickoff Meeting', 'once',     1,  'high'),
    ('DAILY-STANDUP',    'Daily Standup',   'daily',   30,  'normal');
GO


-- ─────────────────────────────────────────────────────────────
-- ANALYTICAL VIEWS
-- Uses CREATE OR ALTER VIEW (SQL Server 2016+)
-- String concat: || replaced with + / CONCAT()
-- ::NUMERIC cast replaced with CAST(... AS DECIMAL(10,1))
-- ─────────────────────────────────────────────────────────────

-- Full occurrence detail with all dimension labels resolved
CREATE OR ALTER VIEW vw_occurrence_detail AS
SELECT
    td.task_code,
    td.task_title,
    td.cadence,
    td.priority,
    o.occurrence_index,
    o.occurrence_id,
    CONCAT(p.first_name, ' ', p.last_name)  AS assignee_name,
    p.department,
    p.role_title,
    da.full_date                            AS assigned_date,
    dd.full_date                            AS due_date,
    dc.full_date                            AS completed_date,
    s.status_label                          AS current_status,
    s.is_terminal,
    o.days_from_assignment,
    o.days_to_complete,
    o.is_overdue
FROM  fact_task_occurrence      o
JOIN  dim_task_definition       td ON o.task_definition_key = td.task_definition_key
JOIN  dim_occurrence_status     s  ON o.status_key          = s.status_key
LEFT JOIN dim_person            p  ON o.assignee_person_key = p.person_key
                                  AND p.is_current = 1
LEFT JOIN dim_date              da ON o.assigned_date_key   = da.date_key
LEFT JOIN dim_date              dd ON o.due_date_key        = dd.date_key
LEFT JOIN dim_date              dc ON o.completed_date_key  = dc.date_key;
GO


-- How many days did each person take to complete tasks?
CREATE OR ALTER VIEW vw_person_completion_time AS
SELECT
    CONCAT(p.first_name, ' ', p.last_name)          AS assignee_name,
    p.department,
    td.task_title,
    td.cadence,
    COUNT(*)                                         AS completed_count,
    MIN(o.days_from_assignment)                      AS fastest_days,
    CAST(AVG(CAST(o.days_from_assignment AS DECIMAL(10,1)))
         AS DECIMAL(10,1))                           AS avg_days_from_assignment,
    MAX(o.days_from_assignment)                      AS slowest_days,
    CAST(AVG(CAST(o.days_to_complete AS DECIMAL(10,1)))
         AS DECIMAL(10,1))                           AS avg_days_vs_due_date,
    SUM(CASE WHEN o.is_overdue = 1 THEN 1 ELSE 0 END) AS overdue_count
FROM  fact_task_occurrence      o
JOIN  dim_task_definition       td ON o.task_definition_key = td.task_definition_key
JOIN  dim_occurrence_status     s  ON o.status_key          = s.status_key
JOIN  dim_person                p  ON o.assignee_person_key = p.person_key
                                  AND p.is_current = 1
WHERE s.status_code = 'completed'
GROUP BY
    p.first_name, p.last_name, p.department,
    td.task_title, td.cadence;
GO


-- Task completion summary
CREATE OR ALTER VIEW vw_task_summary AS
SELECT
    td.task_code,
    td.task_title,
    td.cadence,
    td.priority,
    td.max_occurrences,
    COUNT(o.occurrence_key)                                                 AS total_occurrences,
    SUM(CASE WHEN s.status_code = 'completed'   THEN 1 ELSE 0 END)        AS completed,
    SUM(CASE WHEN s.status_code = 'in_progress' THEN 1 ELSE 0 END)        AS in_progress,
    SUM(CASE WHEN s.status_code = 'not_started' THEN 1 ELSE 0 END)        AS not_started,
    CAST(
        100.0 * SUM(CASE WHEN s.status_code = 'completed' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(o.occurrence_key), 0)
    AS DECIMAL(5,1))                                                        AS pct_complete,
    SUM(CASE WHEN o.is_overdue = 1 THEN 1 ELSE 0 END)                      AS overdue_count,
    CAST(AVG(CAST(o.days_from_assignment AS DECIMAL(10,1)))
         AS DECIMAL(10,1))                                                  AS avg_days_to_complete
FROM  dim_task_definition       td
LEFT JOIN fact_task_occurrence  o  ON td.task_definition_key = o.task_definition_key
LEFT JOIN dim_occurrence_status s  ON o.status_key           = s.status_key
GROUP BY
    td.task_code, td.task_title, td.cadence,
    td.priority, td.max_occurrences;
GO


-- Status change audit trail
CREATE OR ALTER VIEW vw_status_audit_trail AS
SELECT
    fsc.changed_at,
    CONCAT(p.first_name, ' ', p.last_name)  AS changed_by,
    td.task_title,
    o.occurrence_id,
    from_s.status_label                     AS from_status,
    to_s.status_label                       AS to_status,
    fsc.change_reason,
    d.full_date                             AS change_date
FROM  fact_status_change        fsc
JOIN  fact_task_occurrence      o      ON fsc.occurrence_key       = o.occurrence_key
JOIN  dim_task_definition       td     ON fsc.task_definition_key  = td.task_definition_key
JOIN  dim_occurrence_status     to_s   ON fsc.to_status_key        = to_s.status_key
LEFT JOIN dim_occurrence_status from_s ON fsc.from_status_key      = from_s.status_key
LEFT JOIN dim_person            p      ON fsc.changed_by_person_key= p.person_key
                                      AND p.is_current = 1
LEFT JOIN dim_date              d      ON fsc.change_date_key      = d.date_key;
GO