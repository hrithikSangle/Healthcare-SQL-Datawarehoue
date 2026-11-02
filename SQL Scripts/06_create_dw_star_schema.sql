USE MediCoreDW;
GO

DROP TABLE IF EXISTS dw.FactPrescription;
DROP TABLE IF EXISTS dw.FactLabResult;
DROP TABLE IF EXISTS dw.FactBilling;
DROP TABLE IF EXISTS dw.FactAppointment;
DROP TABLE IF EXISTS dw.DimMedicine;
DROP TABLE IF EXISTS dw.DimLabTest;
DROP TABLE IF EXISTS dw.DimInsurer;
DROP TABLE IF EXISTS dw.DimBranch;
DROP TABLE IF EXISTS dw.DimDepartment;
DROP TABLE IF EXISTS dw.DimDoctor;
DROP TABLE IF EXISTS dw.DimPatient;
DROP TABLE IF EXISTS dw.DimPaymentMode;
DROP TABLE IF EXISTS dw.DimDate;
GO

/* ===== DIMENSIONS ===== */

-- role-playing: joined as appointment, booking, bill and result date
CREATE TABLE dw.DimDate (
    DateKey         INT           NOT NULL,   -- smart key yyyymmdd
    FullDate        DATE          NOT NULL,
    DayOfMonth      TINYINT       NOT NULL,
    DayName         VARCHAR(10)   NOT NULL,
    DayOfWeek       TINYINT       NOT NULL,
    IsWeekend       BIT           NOT NULL,
    WeekOfYear      TINYINT       NOT NULL,
    MonthNumber     TINYINT       NOT NULL,
    MonthName       VARCHAR(10)   NOT NULL,
    MonthYear       VARCHAR(10)   NOT NULL,
    QuarterNumber   TINYINT       NOT NULL,
    QuarterName     VARCHAR(2)    NOT NULL,
    CalendarYear    SMALLINT      NOT NULL,
    FiscalYear      VARCHAR(10)   NOT NULL,   -- Indian FY: Apr-Mar
    FiscalQuarter   VARCHAR(2)    NOT NULL,
    FiscalMonthNo   TINYINT       NOT NULL,
    CONSTRAINT PK_DimDate PRIMARY KEY (DateKey),
    CONSTRAINT UQ_DimDate_FullDate UNIQUE (FullDate)
);
GO

-- SCD TYPE 2: address and city changes open a new row
CREATE TABLE dw.DimPatient (
    PatientSK       INT IDENTITY(1,1) NOT NULL,   -- SURROGATE KEY
    PatientID       VARCHAR(20)   NOT NULL,       -- NATURAL KEY
    PatientName     VARCHAR(200)  NOT NULL,
    DateOfBirth     DATE          NULL,
    AgeBand         VARCHAR(20)   NULL,
    Gender          VARCHAR(10)   NULL,
    BloodGroup      VARCHAR(5)    NULL,
    City            VARCHAR(100)  NULL,
    AddressLine     VARCHAR(500)  NULL,
    HasAllergies    BIT           NULL,
    EffectiveFrom   DATE          NOT NULL,
    EffectiveTo     DATE          NOT NULL DEFAULT '9999-12-31',
    IsCurrent       BIT           NOT NULL DEFAULT 1,
    RowHash         BINARY(32)    NULL,           -- change detection
    LoadID          INT           NULL,
    CONSTRAINT PK_DimPatient PRIMARY KEY (PatientSK),
    CONSTRAINT CK_DimPatient_Dates CHECK (EffectiveTo >= EffectiveFrom)
);
GO
CREATE UNIQUE NONCLUSTERED INDEX UX_DimPatient_Current
    ON dw.DimPatient (PatientID) WHERE IsCurrent = 1;
CREATE NONCLUSTERED INDEX IX_DimPatient_NK ON dw.DimPatient (PatientID, EffectiveFrom);
GO

-- SCD TYPE 1: fee overwritten, no history
CREATE TABLE dw.DimDoctor (
    DoctorSK            INT IDENTITY(1,1) NOT NULL,
    DoctorID            VARCHAR(10)   NOT NULL,
    DoctorName          VARCHAR(200)  NOT NULL,
    Specialization      VARCHAR(100)  NULL,
    DepartmentName      VARCHAR(100)  NULL,
    StandardConsultFee  DECIMAL(10,2) NULL,
    LoadID              INT           NULL,
    CONSTRAINT PK_DimDoctor PRIMARY KEY (DoctorSK),
    CONSTRAINT UQ_DimDoctor_NK UNIQUE (DoctorID)
);
GO

CREATE TABLE dw.DimDepartment (
    DepartmentSK    INT IDENTITY(1,1) NOT NULL,
    DepartmentID    INT           NOT NULL,
    DepartmentName  VARCHAR(100)  NOT NULL,
    LoadID          INT           NULL,
    CONSTRAINT PK_DimDepartment PRIMARY KEY (DepartmentSK),
    CONSTRAINT UQ_DimDepartment_NK UNIQUE (DepartmentID)
);
GO

CREATE TABLE dw.DimBranch (
    BranchSK        INT IDENTITY(1,1) NOT NULL,
    BranchCode      VARCHAR(10)   NOT NULL,
    BranchName      VARCHAR(100)  NULL,
    City            VARCHAR(100)  NULL,
    LoadID          INT           NULL,
    CONSTRAINT PK_DimBranch PRIMARY KEY (BranchSK),
    CONSTRAINT UQ_DimBranch_NK UNIQUE (BranchCode)
);
GO

CREATE TABLE dw.DimInsurer (
    InsurerSK       INT IDENTITY(1,1) NOT NULL,
    InsurerName     VARCHAR(200)  NOT NULL,
    IsSelfPay       BIT           NOT NULL DEFAULT 0,
    LoadID          INT           NULL,
    CONSTRAINT PK_DimInsurer PRIMARY KEY (InsurerSK),
    CONSTRAINT UQ_DimInsurer_NK UNIQUE (InsurerName)
);
GO

-- junk dimension: low-cardinality flag combinations
CREATE TABLE dw.DimPaymentMode (
    PaymentModeSK   INT IDENTITY(1,1) NOT NULL,
    PaymentMode     VARCHAR(30)   NOT NULL,
    PaymentStatus   VARCHAR(20)   NOT NULL,
    IsDigital       BIT           NOT NULL,
    IsSettled       BIT           NOT NULL,
    CONSTRAINT PK_DimPaymentMode PRIMARY KEY (PaymentModeSK),
    CONSTRAINT UQ_DimPaymentMode UNIQUE (PaymentMode, PaymentStatus)
);
GO

CREATE TABLE dw.DimLabTest (
    LabTestSK       INT IDENTITY(1,1) NOT NULL,
    TestName        VARCHAR(200)  NOT NULL,
    TestCategory    VARCHAR(100)  NULL,
    LoadID          INT           NULL,
    CONSTRAINT PK_DimLabTest PRIMARY KEY (LabTestSK),
    CONSTRAINT UQ_DimLabTest_NK UNIQUE (TestName)
);
GO

CREATE TABLE dw.DimMedicine (
    MedicineSK      INT IDENTITY(1,1) NOT NULL,
    MedicineName    VARCHAR(200)  NOT NULL,
    Strength        VARCHAR(50)   NULL,
    LoadID          INT           NULL,
    CONSTRAINT PK_DimMedicine PRIMARY KEY (MedicineSK),
    CONSTRAINT UQ_DimMedicine_NK UNIQUE (MedicineName)
);
GO

/* ===== FACTS ===== */

-- GRAIN: one row per appointment
CREATE TABLE dw.FactAppointment (
    AppointmentSK       BIGINT IDENTITY(1,1) NOT NULL,
    AppointmentDateKey  INT           NOT NULL,   -- role-playing
    BookingDateKey      INT           NULL,       -- role-playing
    FollowUpDateKey     INT           NULL,       -- role-playing
    PatientSK           INT           NOT NULL,
    DoctorSK            INT           NOT NULL,
    DepartmentSK        INT           NOT NULL,
    BranchSK            INT           NULL,
    AppointmentID       VARCHAR(20)   NOT NULL,   -- degenerate dimension
    ERPTransactionID    VARCHAR(50)   NULL,       -- degenerate dimension
    AppointmentTime     TIME(0)       NULL,
    AppointmentStatus   VARCHAR(20)   NOT NULL,
    ChiefComplaint      VARCHAR(500)  NULL,
    Diagnosis           VARCHAR(500)  NULL,
    ConsultationFee     DECIMAL(10,2) NULL,
    IsCompleted         BIT           NOT NULL,
    IsNoShow            BIT           NOT NULL,
    IsCancelled         BIT           NOT NULL,
    AppointmentCount    AS CAST(1 AS TINYINT) PERSISTED,
    LoadID              INT           NULL,
    CONSTRAINT PK_FactAppointment PRIMARY KEY (AppointmentSK),
    CONSTRAINT UQ_FactAppointment_DD UNIQUE (AppointmentID),
    CONSTRAINT FK_FactAppt_ApptDate   FOREIGN KEY (AppointmentDateKey) REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactAppt_BookDate   FOREIGN KEY (BookingDateKey)     REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactAppt_FollowDate FOREIGN KEY (FollowUpDateKey)    REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactAppt_Patient    FOREIGN KEY (PatientSK)    REFERENCES dw.DimPatient(PatientSK),
    CONSTRAINT FK_FactAppt_Doctor     FOREIGN KEY (DoctorSK)     REFERENCES dw.DimDoctor(DoctorSK),
    CONSTRAINT FK_FactAppt_Department FOREIGN KEY (DepartmentSK) REFERENCES dw.DimDepartment(DepartmentSK),
    CONSTRAINT FK_FactAppt_Branch     FOREIGN KEY (BranchSK)     REFERENCES dw.DimBranch(BranchSK)
);
GO
CREATE NONCLUSTERED INDEX IX_FactAppt_Date    ON dw.FactAppointment (AppointmentDateKey);
CREATE NONCLUSTERED INDEX IX_FactAppt_Patient ON dw.FactAppointment (PatientSK);
CREATE NONCLUSTERED INDEX IX_FactAppt_Doctor  ON dw.FactAppointment (DoctorSK);
GO

-- GRAIN: one row per bill
CREATE TABLE dw.FactBilling (
    BillingSK           BIGINT IDENTITY(1,1) NOT NULL,
    BillDateKey         INT           NOT NULL,
    AppointmentDateKey  INT           NOT NULL,
    PatientSK           INT           NOT NULL,
    DoctorSK            INT           NOT NULL,
    DepartmentSK        INT           NOT NULL,
    BranchSK            INT           NULL,
    InsurerSK           INT           NULL,
    PaymentModeSK       INT           NULL,
    AppointmentID       VARCHAR(20)   NOT NULL,
    ConsultationFee     DECIMAL(10,2) NOT NULL DEFAULT 0,
    LabCharge           DECIMAL(10,2) NOT NULL DEFAULT 0,
    MedicineCharge      DECIMAL(10,2) NOT NULL DEFAULT 0,
    Subtotal            DECIMAL(12,2) NOT NULL,
    Discount            DECIMAL(12,2) NOT NULL DEFAULT 0,
    GSTAmount           DECIMAL(12,2) NOT NULL DEFAULT 0,
    TotalAmount         DECIMAL(12,2) NOT NULL,
    NetRevenue          AS (Subtotal - Discount) PERSISTED,
    BillIsValid         BIT           NOT NULL,   -- the defect, as a measure
    TotalVariance       DECIMAL(12,2) NULL,
    LoadID              INT           NULL,
    CONSTRAINT PK_FactBilling PRIMARY KEY (BillingSK),
    CONSTRAINT UQ_FactBilling_DD UNIQUE (AppointmentID),
    CONSTRAINT FK_FactBill_BillDate   FOREIGN KEY (BillDateKey)        REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactBill_ApptDate   FOREIGN KEY (AppointmentDateKey) REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactBill_Patient    FOREIGN KEY (PatientSK)     REFERENCES dw.DimPatient(PatientSK),
    CONSTRAINT FK_FactBill_Doctor     FOREIGN KEY (DoctorSK)      REFERENCES dw.DimDoctor(DoctorSK),
    CONSTRAINT FK_FactBill_Department FOREIGN KEY (DepartmentSK)  REFERENCES dw.DimDepartment(DepartmentSK),
    CONSTRAINT FK_FactBill_Branch     FOREIGN KEY (BranchSK)      REFERENCES dw.DimBranch(BranchSK),
    CONSTRAINT FK_FactBill_Insurer    FOREIGN KEY (InsurerSK)     REFERENCES dw.DimInsurer(InsurerSK),
    CONSTRAINT FK_FactBill_PayMode    FOREIGN KEY (PaymentModeSK) REFERENCES dw.DimPaymentMode(PaymentModeSK)
);
GO
CREATE NONCLUSTERED INDEX IX_FactBill_Date ON dw.FactBilling (BillDateKey)
    INCLUDE (TotalAmount, NetRevenue);
GO

-- GRAIN: one row per test per appointment (finer than FactAppointment)
CREATE TABLE dw.FactLabResult (
    LabResultSK         BIGINT IDENTITY(1,1) NOT NULL,
    AppointmentDateKey  INT           NOT NULL,
    ResultDateKey       INT           NULL,
    PatientSK           INT           NOT NULL,
    DoctorSK            INT           NOT NULL,
    LabTestSK           INT           NOT NULL,
    BranchSK            INT           NULL,
    AppointmentID       VARCHAR(20)   NOT NULL,
    ResultValue         VARCHAR(200)  NULL,
    ReferenceRange      VARCHAR(200)  NULL,
    IsAbnormal          BIT           NULL,
    LabCharge           DECIMAL(10,2) NULL,
    TestCount           AS CAST(1 AS TINYINT) PERSISTED,
    LoadID              INT           NULL,
    CONSTRAINT PK_FactLabResult PRIMARY KEY (LabResultSK),
    CONSTRAINT FK_FactLab_ApptDate   FOREIGN KEY (AppointmentDateKey) REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactLab_ResultDate FOREIGN KEY (ResultDateKey)      REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactLab_Patient FOREIGN KEY (PatientSK) REFERENCES dw.DimPatient(PatientSK),
    CONSTRAINT FK_FactLab_Doctor  FOREIGN KEY (DoctorSK)  REFERENCES dw.DimDoctor(DoctorSK),
    CONSTRAINT FK_FactLab_Test    FOREIGN KEY (LabTestSK) REFERENCES dw.DimLabTest(LabTestSK),
    CONSTRAINT FK_FactLab_Branch  FOREIGN KEY (BranchSK)  REFERENCES dw.DimBranch(BranchSK)
);
GO

-- GRAIN: one row per medicine per appointment
CREATE TABLE dw.FactPrescription (
    PrescriptionSK      BIGINT IDENTITY(1,1) NOT NULL,
    AppointmentDateKey  INT           NOT NULL,
    PatientSK           INT           NOT NULL,
    DoctorSK            INT           NOT NULL,
    MedicineSK          INT           NOT NULL,
    BranchSK            INT           NULL,
    AppointmentID       VARCHAR(20)   NOT NULL,
    Dosage              VARCHAR(100)  NULL,
    Frequency           VARCHAR(100)  NULL,
    DurationDays        SMALLINT      NULL,
    MedicineCharge      DECIMAL(10,2) NULL,
    LineCount           AS CAST(1 AS TINYINT) PERSISTED,
    LoadID              INT           NULL,
    CONSTRAINT PK_FactPrescription PRIMARY KEY (PrescriptionSK),
    CONSTRAINT FK_FactRx_ApptDate FOREIGN KEY (AppointmentDateKey) REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactRx_Patient  FOREIGN KEY (PatientSK)  REFERENCES dw.DimPatient(PatientSK),
    CONSTRAINT FK_FactRx_Doctor   FOREIGN KEY (DoctorSK)   REFERENCES dw.DimDoctor(DoctorSK),
    CONSTRAINT FK_FactRx_Medicine FOREIGN KEY (MedicineSK) REFERENCES dw.DimMedicine(MedicineSK),
    CONSTRAINT FK_FactRx_Branch   FOREIGN KEY (BranchSK)   REFERENCES dw.DimBranch(BranchSK)
);
GO

SELECT t.name AS TableName,
       CASE WHEN t.name LIKE 'Dim%' THEN 'DIMENSION' ELSE 'FACT' END AS Type
FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = 'dw' ORDER BY Type, t.name;