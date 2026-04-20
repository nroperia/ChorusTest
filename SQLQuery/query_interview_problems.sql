/*Beginner Level (1-3)*/


/*
1. Retrieve all active patients
Write a query to return all patients who are active.
*/
SELECT	*
FROM	Patient
WHERE	active = TRUE;

/*
2. Find encounters for a specific patient
Given a patient_id, retrieve all encounters for that patient, including the status and encounter date.
###NOT ORDER IN ANY PARTICULAR ORDER*/
SELECT	patient_id, Status, encounter_date
FROM	Encounter
WHERE	patient_id = ?

/*
3. List all observations recorded for a patient
Write a query to fetch all observations for a given patient_id, showing the observation type, value, unit, and recorded date.
###NOT ORDER IN ANY PARTICULAR ORDER*/
SELECT	patient_id, type as observation_type, value, unit, recorded_at as recorded_date
FROM	Observation
WHERE	patient_id = ?


/*Intermediate Level (4-7)*/


/*
4. Find the most recent encounter for each patient
Retrieve each patient’s most recent encounter (based on encounter_date). Return the patient_id, encounter_date, and status.*/
;WITH most_recent_encounter AS(
	SELECT	patient_id, 
			encounter_date, 
			status,
			RN = ROW_NUMBER() OVER(PARTITION BY patient_id ORDER BY encounter_date DESC)
	FROM	Encounter
)

SELECT	patient_id, 
		encounter_date, 
		status
FROM	most_recent_encounter
WHERE	RN = 1

/*
5. Find patients who have had encounters with more than one practitioner
Write a query to return a list of patient IDs who have had encounters with more than one distinct practitioner.*/
SELECT	patient_id
FROM	Encounter
WHERE	practitioner_id IS NOT NULL
GROUP BY patient_id
HAVING COUNT(DISTINCT practitioner_id) > 1

/*
6. Find the top 3 most prescribed medications
Write a query to find the three most commonly prescribed medications from the MedicationRequest table, sorted by the number of prescriptions.
#### NOT SURE if you want to see the total count with each medication name as well. */
SELECT	TOP 3 medication_name
FROM	MedicationRequest
GROUP BY medication_name
ORDER BY COUNT(medication_name) DESC

/*
7. Get practitioners who have never prescribed any medication
Write a query to find all practitioners who do not appear in the MedicationRequest table as a prescribing practitioner.*/
SELECT	*
FROM	Practitioner P
		LEFT OUTER JOIN MedicationRequest R OM R.practitioner_id = P.practitioner_id
WHERE	R.practitioner_id IS NULL


/*Advanced Level (8-10)*/


/*
8. Find the average number of encounters per patient
Calculate the average number of encounters per patient, rounded to two decimal places.*/
;WITH encounter_counts_by_patient AS(
	SELECT	patient_id, COUNT(1) As TotalEnc
	FROM	Encounter
	GROUP BY patient_id
)
SELECT	ROUNT(AVG(TotalEnc), 2) as average_num_encounter
FROM	encounter_counts_by_patient

/*
9. Identify patients who have never had an encounter but have a medication request
Write a query to find patients who have a record in the MedicationRequest table but no associated encounters in the Encounter table.*/
SELECT	*
FROM	Patient p
		LEFT OUTER JOIN MedicationRequest MR ON p.patient_id = MR.patient_id
		LEFT OUTER JOIN Encounter E on E.patient_id = p.patient_id
WHERE	MR.patient_id IS NOT NULL
		AND E.patient_id IS NULL

/*
10. Determine patient retention by cohort
Write a query to count how many patients had their first encounter in each month (YYYY-MM format) and still had at least one encounter in the following six months.
### NOT ORDERED*/
WITH first_encounter AS (
	SELECT	patient_id,
			MIN(encounter_date) AS first_encounter_date,
	FROM	Encounter
	GROUP BY patient_id
),
next_six_month_encounter AS(
	SELECT	DISTINCT
			patient_id,
			FORMAT(first_encounter_date, 'yyyy-MM') AS [first_encounter_date_month]
	FROM	Encounter E
			JOIN first_encounter FE on FE.patient_id = E.patient_id
	WHERE	E.encounter_date <= DATEADD(mm, 6, FE.first_encounter_date)
			AND E.encounter_date > FE.first_encounter_date
)
SELECT	first_encounter_date_month,
		COUNT(DISTINCT patient_id) as continuous_visitor_patients
FROM	next_six_month_encounter
GROUP BY first_encounter_date_month
/*************************************EOF**************************************/