CREATE TABLE Patient (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    identifier VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    gender VARCHAR(10),
    birth_date DATE,
    address NVARCHAR(MAX),
    telecom VARCHAR(255),
    active BIT DEFAULT 1,
    created_at DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE Practitioner (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    identifier VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    specialty VARCHAR(255),
    telecom VARCHAR(255),
    active BIT DEFAULT 1,
    created_at DATETIME2 DEFAULT SYSDATETIME()
);

CREATE TABLE Encounter (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    patient_id UNIQUEIDENTIFIER NOT NULL,
    practitioner_id UNIQUEIDENTIFIER,
    status VARCHAR(50) NOT NULL,
    encounter_date DATETIME2 DEFAULT SYSDATETIME(),
    reason NVARCHAR(MAX),
    created_at DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Encounter_Patient FOREIGN KEY (patient_id) REFERENCES Patient(id),
    CONSTRAINT FK_Encounter_Practitioner FOREIGN KEY (practitioner_id) REFERENCES Practitioner(id)
);

CREATE TABLE Observation (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    patient_id UNIQUEIDENTIFIER NOT NULL,
    encounter_id UNIQUEIDENTIFIER,
    type VARCHAR(255) NOT NULL,
    value VARCHAR(255) NOT NULL,
    unit VARCHAR(50),
    recorded_at DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Observation_Patient FOREIGN KEY (patient_id) REFERENCES Patient(id),
    CONSTRAINT FK_Observation_Encounter FOREIGN KEY (encounter_id) REFERENCES Encounter(id)
);

CREATE TABLE MedicationRequest (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    patient_id UNIQUEIDENTIFIER NOT NULL,
    practitioner_id UNIQUEIDENTIFIER NOT NULL,
    medication_name VARCHAR(255) NOT NULL,
    dosage VARCHAR(255),
    status VARCHAR(50) NOT NULL,
    created_at DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_MedicationRequest_Patient FOREIGN KEY (patient_id) REFERENCES Patient(id),
    CONSTRAINT FK_MedicationRequest_Practitioner FOREIGN KEY (practitioner_id) REFERENCES Practitioner(id)
);