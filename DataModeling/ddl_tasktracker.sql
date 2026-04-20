/**
NOTE: I have added the PROMPT I used to generate this schema in the 
Claude AI Model
**/

-- ─────────────────────────────────────────────────────────────
-- DIMENSION TABLES
-- ─────────────────────────────────────────────────────────────

-- DIM_PERSON
-- Slowly Changing Dimension Type 2.
-- Any human assignable to a task (employee, contractor, user).
-- SCD2: attribute changes create a new row. History preserved
-- via effective_date / expiry_date / is_current.
CREATE TABLE dim_person (
    person_key          INT             NOT NULL IDENTITY(1,1),
    person_id           NVARCHAR(64)    NOT NULL,               -- natural / business key
    first_name          NVARCHAR(100)   NOT NULL,
    last_name           NVARCHAR(100)   NOT NULL,
    email               NVARCHAR(150)   NULL,
    department          NVARCHAR(100)   NULL,
    role_title          NVARCHAR(100)   NULL,
    -- ENUM replaced with CHECK constraint (T-SQL has no native ENUM type)
    person_status       NVARCHAR(20)    NOT NULL DEFAULT 'active'
                            CONSTRAINT chk_person_status
                            CHECK (person_status IN ('active','inactive','suspended')),
    -- SCD Type 2 versioning
    effective_date      DATE            NOT NULL,
    expiry_date         DATE            NOT NULL DEFAULT '9999-12-31',
    is_current          BIT             NOT NULL DEFAULT 1,
    -- Audit
    created_on          DATETIME2(3)    NOT NULL DEFAULT GETDATE(),
    updated_on          DATETIME2(3)    NOT NULL DEFAULT GETDATE(),
    -- Keys
    CONSTRAINT pk_dim_person          PRIMARY KEY (person_key),
    CONSTRAINT uq_person_version      UNIQUE      (person_id, effective_date)
);
GO

-- Extended properties replace PostgreSQL COMMENT ON
EXEC sp_addextendedproperty
    'MS_Description', 'SCD Type 2: preserves full history of person attribute changes over time.',
    'SCHEMA', 'dbo', 'TABLE', 'dim_person';
EXEC sp_addextendedproperty
    'MS_Description', 'Business/natural key — stable across SCD versions.',
    'SCHEMA', 'dbo', 'TABLE', 'dim_person', 'COLUMN', 'person_id';
EXEC sp_addextendedproperty
    'MS_Description', 'Surrogate key — changes with each SCD Type 2 version row.',
    'SCHEMA', 'dbo', 'TABLE', 'dim_person', 'COLUMN', 'person_key';
EXEC sp_addextendedproperty
    'MS_Description', '9999-12-31 = currently active version.',
    'SCHEMA', 'dbo', 'TABLE', 'dim_person', 'COLUMN', 'expiry_date';
GO


-- DIM_TASK_DEFINITION
-- Task template. Defines WHAT the task is and HOW it recurs.
-- SCD Type 1: updated in-place. History lives in occurrences.
CREATE TABLE dim_task_definition (
    task_definition_key INT             NOT NULL IDENTITY(1,1),
    task_code           NVARCHAR(100)   NOT NULL,               -- human-readable business key
    task_title          NVARCHAR(255)   NOT NULL,
    task_description    NVARCHAR(MAX)   NULL,
    cadence             NVARCHAR(20)    NOT NULL
                            CONSTRAINT chk_task_cadence
                            CHECK (cadence IN ('once','daily','weekly','monthly')),
    max_occurrences     INT             NOT NULL
							CONSTRAINT chk_max_occ CHECK (max_occurrences > 0),
    [priority]          NVARCHAR(20)    NOT NULL DEFAULT 'normal'
                            CONSTRAINT chk_task_priority
                            CHECK (priority IN ('low','normal','high','critical')),
    is_active           BIT             NOT NULL DEFAULT 1,
    -- Audit
    created_on          DATETIME2(3)    NOT NULL DEFAULT GETDATE(),
    updated_on          DATETIME2(3)    NOT NULL DEFAULT GETDATE(),
    -- Keys
    CONSTRAINT pk_dim_task_definition  PRIMARY KEY (task_definition_key),
    CONSTRAINT uq_task_code            UNIQUE      (task_code)
);
GO

EXEC sp_addextendedproperty
    'MS_Description', 'Task template. Cadence + max_occurrences govern how many fact rows are generated.',
    'SCHEMA', 'dbo', 'TABLE', 'dim_task_definition';
EXEC sp_addextendedproperty
    'MS_Description', 'Stable business key used in ETL and API references.',
    'SCHEMA', 'dbo', 'TABLE', 'dim_task_definition', 'COLUMN', 'task_code';
EXEC sp_addextendedproperty
    'MS_Description', 'Recurrence pattern: once | daily | weekly | monthly.',
    'SCHEMA', 'dbo', 'TABLE', 'dim_task_definition', 'COLUMN', 'cadence';
GO


-- DIM_OCCURRENCE_STATUS
-- Conformed status dimension. Factored out to satisfy 3NF:
-- status_label / status_category depend on status_code, not on
-- the occurrence PK.
CREATE TABLE dim_occurrence_status (
    status_key          INT             NOT NULL IDENTITY(1,1),
    status_code         NVARCHAR(50)    NOT NULL
                            CONSTRAINT chk_status_code
                            CHECK (status_code IN ('not_started','in_progress','completed')),
    status_label        NVARCHAR(100)   NOT NULL,
    status_category     NVARCHAR(50)    NOT NULL CONSTRAINT chk_status_category CHECK (status_category IN ('active','terminal')),
    is_terminal         BIT             NOT NULL DEFAULT 0,
    sort_order          SMALLINT        NOT NULL,
    is_active           BIT             NOT NULL DEFAULT 0,
    -- Audit
    created_on          DATETIME2(3)    NOT NULL DEFAULT GETDATE(),
    updated_on          DATETIME2(3)    NOT NULL DEFAULT GETDATE(),
    -- Keys
    CONSTRAINT pk_dim_occurrence_status PRIMARY KEY (status_key),
    CONSTRAINT uq_status_code           UNIQUE      (status_code)
);
GO

EXEC sp_addextendedproperty
    'MS_Description', 'Conformed dimension. Status labels/categories are not repeated in fact tables (3NF).',
    'SCHEMA', 'dbo', 'TABLE', 'dim_occurrence_status';
EXEC sp_addextendedproperty
    'MS_Description', '1 = occurrence cannot transition further (e.g. completed).',
    'SCHEMA', 'dbo', 'TABLE', 'dim_occurrence_status', 'COLUMN', 'is_terminal';
GO


-- DIM_DATE
-- Referenced 3 times in fact_task_occurrence
-- as assigned_date_key, due_date_key, completed_date_key.
CREATE TABLE dim_date (
    date_key            INT             NOT NULL,               -- YYYYMMDD
    full_date           DATE            NOT NULL,
    day_of_week         SMALLINT        NOT NULL,               -- 1=Sunday … 7=Saturday
    day_name            NVARCHAR(10)    NOT NULL,
    day_of_month        SMALLINT        NOT NULL,
    day_of_year         SMALLINT        NOT NULL,
    week_of_year        SMALLINT        NOT NULL,
    month_number        SMALLINT        NOT NULL,
    month_name          NVARCHAR(10)    NOT NULL,
    quarter             SMALLINT        NOT NULL CONSTRAINT chk_quarter CHECK (quarter BETWEEN 1 AND 4),
    year                SMALLINT        NOT NULL,
    is_weekend          BIT             NOT NULL,
    is_holiday          BIT             NOT NULL DEFAULT 0,
    fiscal_year         SMALLINT        NULL,
    fiscal_quarter      SMALLINT        NULL,
    -- Audit
    created_on          DATETIME2(3)    NOT NULL DEFAULT GETDATE(),
    updated_on          DATETIME2(3)    NOT NULL DEFAULT GETDATE(),
    -- Keys
    CONSTRAINT pk_dim_date   PRIMARY KEY (date_key),
    CONSTRAINT uq_full_date  UNIQUE      (full_date)
);
GO

EXEC sp_addextendedproperty
    'MS_Description', 'Date spine pre-populated for the full analytical range. Role-played 3x in fact_task_occurrence.',
    'SCHEMA', 'dbo', 'TABLE', 'dim_date';
EXEC sp_addextendedproperty
    'MS_Description', 'Integer YYYYMMDD. Enables fast range scans.',
    'SCHEMA', 'dbo', 'TABLE', 'dim_date', 'COLUMN', 'date_key';
GO


-- ─────────────────────────────────────────────────────────────
-- FACT TABLES
-- ─────────────────────────────────────────────────────────────

-- FACT_TASK_OCCURRENCE
-- Grain: ONE ROW per scheduled occurrence of a recurring task.
-- Central fact in the star schema.
--
-- Dimension FKs:
--   task_definition_key → dim_task_definition  (M:1)
--   assignee_person_key → dim_person           (M:1)
--   status_key          → dim_occurrence_status(M:1)
--   assigned_date_key   → dim_date             (M:1, role: assignment)
--   due_date_key        → dim_date             (M:1, role: deadline)
--   completed_date_key  → dim_date             (M:1, role: completion)
CREATE TABLE fact_task_occurrence (
    occurrence_key          BIGINT          NOT NULL IDENTITY(1,1),

    -- ── Dimension Foreign Keys ──────────────────────────────
    task_definition_key     INT             NOT NULL,
    assignee_person_key     INT             NULL,           -- nullable: may be unassigned
    status_key              INT             NOT NULL,
    assigned_date_key       INT             NULL,           -- when person was assigned
    due_date_key            INT             NULL,           -- scheduled deadline
    completed_date_key      INT             NULL,           -- actual completion (NULL until done)

    -- ── Degenerate Dimensions ───────────────────────────────
    occurrence_id           NVARCHAR(100)   NOT NULL,       -- business key e.g. "TASK-001-OCC-03"
    occurrence_index        SMALLINT        NOT NULL CONSTRAINT chk_occ_index CHECK (occurrence_index >= 1),

    -- ── Measures added as default measure ────────────────────────────────────────────
    days_to_complete        INT             NULL            -- completed_date - due_date  (SLA)
                                CONSTRAINT chk_days_complete CHECK (days_to_complete >= 0),
    days_from_assignment    INT             NULL            -- completed_date - assigned_date (effort)
                                CONSTRAINT chk_days_assign  CHECK (days_from_assignment >= 0),
    is_overdue              BIT             NOT NULL DEFAULT 0,

    -- ── Audit ───────────────────────────────────────────────
    created_on              DATETIME2(3)    NOT NULL DEFAULT GETDATE(),
    updated_on              DATETIME2(3)    NOT NULL DEFAULT GETDATE(),

    -- ── Keys & Constraints ──────────────────────────────────
    CONSTRAINT pk_fact_task_occurrence  PRIMARY KEY (occurrence_key),
    CONSTRAINT uq_occurrence_id         UNIQUE      (occurrence_id),
    CONSTRAINT fk_fto_task_definition   FOREIGN KEY (task_definition_key)
        REFERENCES dim_task_definition(task_definition_key),
    CONSTRAINT fk_fto_assignee          FOREIGN KEY (assignee_person_key)
        REFERENCES dim_person(person_key),
    CONSTRAINT fk_fto_status            FOREIGN KEY (status_key)
        REFERENCES dim_occurrence_status(status_key),
    CONSTRAINT fk_fto_assigned_date     FOREIGN KEY (assigned_date_key)
        REFERENCES dim_date(date_key),
    CONSTRAINT fk_fto_due_date          FOREIGN KEY (due_date_key)
        REFERENCES dim_date(date_key),
    CONSTRAINT fk_fto_completed_date    FOREIGN KEY (completed_date_key)
        REFERENCES dim_date(date_key)
);
GO

EXEC sp_addextendedproperty
    'MS_Description', 'Central star fact. Grain = one scheduled occurrence of a task.',
    'SCHEMA', 'dbo', 'TABLE', 'fact_task_occurrence';
EXEC sp_addextendedproperty
    'MS_Description', 'SLA metric: elapsed days from due_date to completion. Positive = late.',
    'SCHEMA', 'dbo', 'TABLE', 'fact_task_occurrence', 'COLUMN', 'days_to_complete';
EXEC sp_addextendedproperty
    'MS_Description', 'Effort metric: elapsed days from assignment to completion. Answers "how long did [person] take?"',
    'SCHEMA', 'dbo', 'TABLE', 'fact_task_occurrence', 'COLUMN', 'days_from_assignment';
GO


-- ── FACT_STATUS_CHANGE ───────────────────────────────────────
-- Grain: ONE ROW per status transition on a task occurrence.
-- Append-only audit log. Never updated after insert.
CREATE TABLE fact_status_change (
    change_key              BIGINT          NOT NULL IDENTITY(1,1),

    -- ── Dimension Foreign Keys ──────────────────────────────
    occurrence_key          BIGINT          NOT NULL,
    task_definition_key     INT             NOT NULL,       -- denormalized FK for direct audit queries
    changed_by_person_key   INT             NULL,
    from_status_key         INT             NULL,           -- NULL on initial status assignment
    to_status_key           INT             NOT NULL,
    change_date_key         INT             NULL,

    -- ── Degenerate Dimension ────────────────────────────────
    changed_at              DATETIME2(3)    NOT NULL DEFAULT GETDATE(),

    -- ── Descriptive ─────────────────────────────────────────
    change_reason           NVARCHAR(MAX)   NULL,

    -- ── Audit ───────────────────────────────────────────────
    created_on              DATETIME2(3)    NOT NULL DEFAULT GETDATE(),
    updated_on              DATETIME2(3)    NOT NULL DEFAULT GETDATE(),

    -- ── Keys & Constraints ──────────────────────────────────
    CONSTRAINT pk_fact_status_change    PRIMARY KEY (change_key),
    CONSTRAINT chk_status_differs       CHECK (from_status_key IS NULL
                                            OR from_status_key <> to_status_key),
    CONSTRAINT fk_fsc_occurrence        FOREIGN KEY (occurrence_key)
        REFERENCES fact_task_occurrence(occurrence_key),
    CONSTRAINT fk_fsc_task_definition   FOREIGN KEY (task_definition_key)
        REFERENCES dim_task_definition(task_definition_key),
    CONSTRAINT fk_fsc_changed_by        FOREIGN KEY (changed_by_person_key)
        REFERENCES dim_person(person_key),
    CONSTRAINT fk_fsc_from_status       FOREIGN KEY (from_status_key)
        REFERENCES dim_occurrence_status(status_key),
    CONSTRAINT fk_fsc_to_status         FOREIGN KEY (to_status_key)
        REFERENCES dim_occurrence_status(status_key),
    CONSTRAINT fk_fsc_change_date       FOREIGN KEY (change_date_key)
        REFERENCES dim_date(date_key)
);
GO

EXEC sp_addextendedproperty
    'MS_Description', 'Audit fact. Grain = one status transition. Immutable append-only log.',
    'SCHEMA', 'dbo', 'TABLE', 'fact_status_change';
EXEC sp_addextendedproperty
    'MS_Description', 'NULL = initial status assignment (no prior state existed).',
    'SCHEMA', 'dbo', 'TABLE', 'fact_status_change', 'COLUMN', 'from_status_key';
EXEC sp_addextendedproperty
    'MS_Description', 'Denormalized FK enables task-level audit queries without extra JOIN.',
    'SCHEMA', 'dbo', 'TABLE', 'fact_status_change', 'COLUMN', 'task_definition_key';
GO