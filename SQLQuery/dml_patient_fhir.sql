-------------------------------------------------------------------------------------------
/*
NOTE: THIS SCRIPT IS CONVERSION OF CHORUS's main.py conversion to load SEED Data into tables
*/
-------------------------------------------------------------------------------------------

SET NOCOUNT ON;

DECLARE @NUM_PATIENTS INT = 10;
DECLARE @NUM_PRACTITIONERS INT = 5;
DECLARE @NUM_ENCOUNTERS INT = 15;
DECLARE @NUM_OBSERVATIONS INT = 20;
DECLARE @NUM_MEDICATIONS INT = 10;

-- Temp tables to store generated IDs
DECLARE @Patients TABLE (id UNIQUEIDENTIFIER);
DECLARE @Practitioners TABLE (id UNIQUEIDENTIFIER);
DECLARE @Encounters TABLE (id UNIQUEIDENTIFIER);

-------------------------------------
-- Insert Patients
-------------------------------------
DECLARE @i INT = 0;

WHILE @i < @NUM_PATIENTS
BEGIN
    DECLARE @pid UNIQUEIDENTIFIER = NEWID();
	--SELECT * FROM Patient
    INSERT INTO Patient (id, identifier, name, gender, birth_date, address, telecom, active, created_at)
    VALUES (
        @pid,
        NEWID(),
        CONCAT('Patient ', @i),
        CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1, 'Male', 'Female', 'Other'),
        DATEADD(YEAR, - (20 + ABS(CHECKSUM(NEWID())) % 60), GETDATE()),
        CONCAT('Address ', @i),
        CONCAT('patient', @i, '@example.com'),
        1,
        SYSDATETIME()
    );

    INSERT INTO @Patients VALUES (@pid);

    SET @i += 1;
END

-------------------------------------
-- Insert Practitioners
-------------------------------------
SET @i = 0;

WHILE @i < @NUM_PRACTITIONERS
BEGIN
    DECLARE @prid UNIQUEIDENTIFIER = NEWID();
	--SELECT * FROM Practitioner
    INSERT INTO Practitioner (id, identifier, name, specialty, telecom, active, created_at)
    VALUES (
        @prid,
        NEWID(),
        CONCAT('Practitioner ', @i),
        CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1, 'Cardiology', 'Dermatology', 'Neurology', 'General'),
        CONCAT('practitioner', @i, '@example.com'),
        1,
        SYSDATETIME()
    );

    INSERT INTO @Practitioners VALUES (@prid);

    SET @i += 1;
END

-------------------------------------
-- Insert Encounters
-------------------------------------
SET @i = 0;

WHILE @i < @NUM_ENCOUNTERS
BEGIN
    DECLARE @eid UNIQUEIDENTIFIER = NEWID();
	--SELECT * FROM Encounter
    INSERT INTO Encounter (id, patient_id, practitioner_id, [status], encounter_date, reason, created_at)
    SELECT
        @eid,
        (SELECT TOP 1 id FROM @Patients ORDER BY NEWID()),
        (SELECT TOP 1 id FROM @Practitioners ORDER BY NEWID()),
        CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1, 'planned', 'in-progress', 'finished', 'cancelled'),
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 30, SYSDATETIME()),
        CONCAT('Reason ', @i),
        SYSDATETIME();

    INSERT INTO @Encounters VALUES (@eid);

    SET @i += 1;
END

-------------------------------------
-- Insert Observations
-------------------------------------
SET @i = 0;

WHILE @i < @NUM_OBSERVATIONS
BEGIN
    DECLARE @type VARCHAR(50) =
        CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1,
               'Blood Pressure', 'Heart Rate', 'Temperature');
	--SELECT * FROM Observation
    INSERT INTO Observation (id, patient_id, encounter_id, type, value, unit, recorded_at)
    SELECT
        NEWID(),
        (SELECT TOP 1 id FROM @Patients ORDER BY NEWID()),
        (SELECT TOP 1 id FROM @Encounters ORDER BY NEWID()),
        @type,
        CASE 
            WHEN @type = 'Temperature'
                THEN CAST(ROUND(36 + RAND(CHECKSUM(NEWID())) * 3, 1) AS VARCHAR)
            ELSE CAST(90 + ABS(CHECKSUM(NEWID())) % 50 AS VARCHAR)
        END,
        CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1, 'mmHg', 'bpm', '°C'),
        SYSDATETIME();

    SET @i += 1;
END

-------------------------------------
-- Insert Medication Requests
-------------------------------------
SET @i = 0;

WHILE @i < @NUM_MEDICATIONS
BEGIN
--SELECT * FROM MedicationRequest
    INSERT INTO MedicationRequest (id, patient_id, practitioner_id, medication_name, dosage, status, created_at)
    SELECT
        NEWID(),
        (SELECT TOP 1 id FROM @Patients ORDER BY NEWID()),
        (SELECT TOP 1 id FROM @Practitioners ORDER BY NEWID()),
        CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1, 'Aspirin', 'Metformin', 'Lisinopril', 'Ibuprofen'),
        CONCAT(
            5 + ABS(CHECKSUM(NEWID())) % 500,
            'mg ',
            CHOOSE(ABS(CHECKSUM(NEWID())) % 2 + 1, 'once daily', 'twice daily')
        ),
        CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1, 'active', 'completed', 'cancelled'),
        SYSDATETIME();

    SET @i += 1;
END

PRINT '✅ Test data inserted successfully!';