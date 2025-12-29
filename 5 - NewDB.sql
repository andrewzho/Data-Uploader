/*
================================================================================
SCRIPT 5: Create Data Warehouse Tables (DWFinance database)
================================================================================

PURPOSE:
  This is the FINAL script. It creates clean, denormalized fact and dimension
  tables in the DWFinance database for reporting and analysis.
  
  These tables are optimized for BI tools (Power BI, Tableau, etc.) and
  provide a clean interface to the cleaned DataCleanup data.

EXECUTION ORDER:
  - Run LAST (after Scripts 1-4)
  - Only run this after all other scripts complete successfully

KEY OUTPUTS:
  1. Fractions - Radiation therapy treatment records
  2. ICD_Crosswalk - ICD-10 diagnosis code lookup table
  3. Referral_Masterlist - Complete referral data
  4. Payer_Crosswalk - Insurance/payer lookup
  5. RCB_Billing - Billing and financial transactions (fact table)
  6. AriaData - Patient demographics and flags

NOTES:
  - This recreates all tables, dropping existing data
  - Use this for reporting databases or data marts
  - Source data comes from the cleaned DataCleanup tables

================================================================================
*/

-- Step 1: Drop existing tables to ensure fresh start
--         This allows the script to be run multiple times
DROP TABLE IF EXISTS DWFinance.dbo.Fractions;
DROP TABLE IF EXISTS DWFinance.dbo.ICD_Crosswalk;
DROP TABLE IF EXISTS DWFinance.dbo.Referral_Masterlist;
DROP TABLE IF EXISTS DWFinance.dbo.Payer_Crosswalk;
DROP TABLE IF EXISTS DWFinance.dbo.RCB_Billing;
DROP TABLE IF EXISTS DWFinance.dbo.AriaData;

-- Step 2: Create Fractions Table
--         Contains radiation therapy treatment records with diagnostic codes
--         Source: DataCleanup.dbo.Fractions
CREATE TABLE DWFinance.dbo.Fractions (
	[Fraction ID] INT PRIMARY KEY IDENTITY (1,1),
	[Patient ID] NVARCHAR(255),
	[Activity Name] NVARCHAR(255),
	[Activity Start Date] DATE,
	[Treatment Status] NVARCHAR(255),
	[ICD 10 Diagnosis] NVARCHAR(255),
	[Resource] NVARCHAR(255),
	[Primary Oncologist] NVARCHAR(255)
)

-- Step 2a: Populate Fractions from cleaned data
--          Maps cleaned column names to reporting-friendly names
INSERT INTO DWFinance.dbo.Fractions (
    [Patient ID],
    [Activity Name],
    [Activity Start Date],
    [Treatment Status],
    [ICD 10 Diagnosis],
    [Resource],
    [Primary Oncologist]
)
SELECT
    [Patient ID1] AS [Patient ID],
    [Activity Name],
    [Start Date] AS [Activity Start Date],
    Status AS [Treatment Status],
    [ICD 10] AS [ICD 10 Diagnosis],
    [Staff/Resource(s)] AS [Resource],
    [Prim# Oncologist] AS [Primary Oncologist]
FROM DataCleanup.dbo.Fractions;
GO


-- Step 3: Create ICD Crosswalk (Lookup Table)
--         Maps ICD-10 diagnosis codes to readable categories
--         Used for classifying and grouping diagnoses in reports
CREATE TABLE DWFinance.dbo.ICD_Crosswalk (
	[ICD ID] INT PRIMARY KEY IDENTITY (1,1),
	Prefix NVARCHAR(10),
	[ICD 10 Code] NVARCHAR(255),
	Description NVARCHAR(255),
	[ICD 10 Diagosis Category] NVARCHAR(255),
	[ICD 10 Sub-Category] NVARCHAR(255)
)

-- Step 3a: Populate ICD Crosswalk
--          Maps ICD-10 codes to their categories and descriptions
INSERT INTO DWFinance.dbo.ICD_Crosswalk (
	Prefix,
    [ICD 10 Code],
	Description,
    [ICD 10 Diagosis Category],
    [ICD 10 Sub-Category]
)
SELECT
	Prefix,
    [Latest dx] AS [ICD 10 Code],
	Descr,
    [Roll Up - High Level] AS [ICD 10 Diagosis Category],
    [ICD_Second Level] AS [ICD 10 Sub-Category]
FROM DataCleanup.dbo.ICD_Crosswalk;
GO

-- Step 4: Create Referral_Masterlist (Dimension Table)
--         Contains cleaned referral information for each patient visit
--         Includes approval status, dates, and insurance information
CREATE TABLE DWFinance.dbo.Referral_Masterlist (
	[Referral ID] INT PRIMARY KEY IDENTITY(1,1),
	[Patient Name] NVARCHAR(255),
	[Patient MRN] NVARCHAR(255),
	Age INT,
	[Visit NUmber] INT,
	[Referral date] DATE,
	State NVARCHAR(25),
	[Disease Site] NVARCHAR(255),
	[Referring Hospital] NVARCHAR(255),
	[Referring Physician] NVARCHAR(255),
	[Attending Physician] NVARCHAR(255),
	[Primary Insurance] NVARCHAR(255),
	[Secondary Insruance] NVARCHAR(255),
	[Insurance Approval] NVARCHAR(255),
	[Final Approval] NVARCHAR(255),
	[Reason Code] NVARCHAR(255),
	[Consult Date] DATE,
	[Sim Date] DATE,
	[Intake Acceptance Date] DATE,
	[Decision Date] DATE,
	[Insurance Decision Date] DATE,
	[Inquiry source] NVARCHAR(255)
)

-- Step 4a: Populate Referral_Masterlist
--          Includes computed age field based on date of birth
INSERT INTO DWFinance.dbo.Referral_Masterlist (
    [Patient Name],
    [Patient MRN],
    Age,
    [Visit NUmber],
    [Referral date],
    State,
	[Disease Site],
	[Referring Hospital],
    [Referring Physician],
    [Attending Physician],
    [Primary Insurance],
    [Secondary Insruance],
    [Insurance Approval],
    [Final Approval],
    [Reason Code],
    [Consult Date],
    [Sim Date],
    [Intake Acceptance Date],
    [Decision Date],
    [Insurance Decision Date],
    [Inquiry source]
)
SELECT
    [Patient Name],
    [Patient ID] AS [Patient MRN],
    -- Compute age from DOB; adjust the formula as needed for your business rules.
    -- Formula: DATEDIFF(YEAR, DOB, TODAY) minus 1 if birthday hasn't occurred this year
    DATEDIFF(YEAR, DOB, GETDATE()) - 
       CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, DOB, GETDATE()), DOB) > GETDATE() THEN 1 ELSE 0 END AS Age,
    [Visit Number] AS [Visit NUmber],
    [Referral Date],
    State,
	[Disease Site],
	[Referring Hospital],
    [Referring Physician],
    [Attending Physician],
    UpdatedPrimary,
    UpdatedSecondary,
    [Insurance Approval],
    [Final Approval],
    Reason AS [Reason Code],
    [Consult Date],
    [Sim Date],
    [Intake Acceptance Date],
    [Decision Date],
    [Insurance decision date (For at risk patients)] AS [Insurance Decision Date],
    [Inquiry Source]
FROM DataCleanup.dbo.Ref;
GO


-- Step 5: Create Payer_Crosswalk (Lookup Table)
--         Maps insurance company names to standardized categories
--         Used for insurance analysis and grouping
CREATE TABLE DWFinance.dbo.Payer_Crosswalk (
	[Insurance Name] NVARCHAR(255),
	[Insurance Category Abv] NVARCHAR(255),
	[Insurance Category] NVARCHAR(255),
	[Insurance Roll Up] NVARCHAR(255)
)

-- Step 5a: Populate Payer_Crosswalk from cleaned lookup table
INSERT INTO DWFinance.dbo.Payer_Crosswalk (
	[Insurance Category Abv],
    [Insurance Name],
    [Insurance Category],
    [Insurance Roll Up]
)
SELECT
	[InsuranceCatAbv] AS [Insurance Category Abv],
    [Insurance Product Detail] AS [Insurance Name],
    [Category - Type] AS [Insurance Category],
    [Payer Roll-Up] AS [Insurance Roll Up]
FROM DataCleanup.dbo.[Payer Crosswalk];
GO

-- Step 6: Create RCB_Billing (Main Fact Table)
--         This is the primary billing/financial transaction table
--         Used for financial analysis, revenue reporting, A/R aging
--         Contains detailed transaction-level data with all adjustments
CREATE TABLE DWFinance.dbo.RCB_Billing (
    RCB_ID INT PRIMARY KEY IDENTITY(1,1),
    PaymentDateUpdated DATE,
    PaymentDateVoided DATE,
    VoucherDateUpdated DATE,
    VoucherDateVoided DATE,
	AccountType NVARCHAR(255),
	InsuranceAbv NVARCHAR(255),
	InsuranceName NVARCHAR(255),
	PatientNumber NVARCHAR(25),
	PatientFullName NVARCHAR(255),
    DOS DATE, -- DOS stored directly as raw date
	Voucher INT,
    BillDate DATE,
    ReBillDate DATE,
	BillingProvider NVARCHAR(255),
    NPI FLOAT,
	PatientSubscriberID NVARCHAR(255),
	ProcedureCode NVARCHAR(255),
	ProcedureDescription NVARCHAR(255),
	Modifier NVARCHAR(255),
	[Diagnosis Code] NVARCHAR(255),
    Units INT,
    Charges DECIMAL(12, 2),
    PersonalPayments DECIMAL(12, 2),
    InsurancePayments DECIMAL(12, 2),
    IntlPayments DECIMAL(12, 2),
	[Contractual Adjustments] DECIMAL(12,2),
	Charity DECIMAL(12,2),
    Refund_Amounts DECIMAL(12,2),
	Allowed DECIMAL(12,2),
	Total_Payments DECIMAL(12,2),
	Total_Adjustments DECIMAL(12,2),
    BalTransFromTiger DECIMAL(12,2),
	IntlAdjustment DECIMAL(12,2),
	Bankruptcy DECIMAL(12,2),
	PatientBalanceDeemedUncollectible DECIMAL(12,2),
	CharityWriteOff DECIMAL(12,2),
	IndigentCharity DECIMAL(12,2),
	BundledNCCIEdit DECIMAL(12,2),
	ChargeError DECIMAL(12,2),
	GlobalPeriodNotBillable DECIMAL(12,2),
	AppealsExhaustedNotMedNecessary DECIMAL(12,2),
	ChargesNotReceivedfromSiteTimely DECIMAL(12,2),
	DeceasedPatient DECIMAL(12,2),
	FinancialHardship DECIMAL(12,2),
	G6017NotCovered DECIMAL(12,2),
	MUEMaxUnitsExceeded DECIMAL(12,2),
	NoAuthorizationObtained DECIMAL(12,2),
	NoncoveredService DECIMAL(12,2),
	NoTransferAgreementInpat DECIMAL(12,2),
	OutofNetwork DECIMAL(12,2),
	PromptPayAdjustment DECIMAL(12,2),
	SmallBalanceAdjustment DECIMAL(12,2),
	CollectionAgencyPayments DECIMAL(12,2),
	CollectionAgencyRefunds DECIMAL(12,2),
	CollectionAgencyTransfers DECIMAL(12,2),
	CollectionAgencyAdjustment DECIMAL(12,2),
	CollectionAgencyFeeAdjustment DECIMAL(12,2),
	[All Other Adjustments] DECIMAL(12,2),
    RemainingBalance DECIMAL(12, 2),
	[Date Uploaded] DATE
);

-- Step 6a: Populate RCB_Billing from cleaned transactions
--          Includes all financial columns and calculated fields
INSERT INTO DWFinance.dbo.RCB_Billing (
    PaymentDateUpdated,
    PaymentDateVoided,
    VoucherDateUpdated,
    VoucherDateVoided,
    AccountType,
    InsuranceAbv,
    InsuranceName,
    PatientNumber,
    PatientFullName,
    DOS,
    Voucher,
    BillDate,
    ReBillDate,
    BillingProvider,
    NPI,
    PatientSubscriberID,
    ProcedureCode,
    ProcedureDescription,
    Modifier,
	[Diagnosis Code],
    Units,
    Charges,
    PersonalPayments,
    InsurancePayments,
    IntlPayments,
    [Contractual Adjustments],
    Charity,
    Refund_Amounts,
    Allowed,
    Total_Payments,
	Total_Adjustments,
    BalTransFromTiger,
    IntlAdjustment,
    Bankruptcy,
    PatientBalanceDeemedUncollectible,
    CharityWriteOff,
    IndigentCharity,
    BundledNCCIEdit,
    ChargeError,
    GlobalPeriodNotBillable,
    AppealsExhaustedNotMedNecessary,
    ChargesNotReceivedfromSiteTimely,
    DeceasedPatient,
    FinancialHardship,
    G6017NotCovered,
    MUEMaxUnitsExceeded,
    NoAuthorizationObtained,
    NoncoveredService,
    NoTransferAgreementInpat,
    OutofNetwork,
    PromptPayAdjustment,
    SmallBalanceAdjustment,
    CollectionAgencyPayments,
    CollectionAgencyRefunds,
    CollectionAgencyTransfers,
    CollectionAgencyAdjustment,
    CollectionAgencyFeeAdjustment,
    [All Other Adjustments],
    RemainingBalance,
    [Date Uploaded]
)
SELECT
    PaymentDateUpdated,
    PaymentDateVoided,
    VoucherDateUpdated,
    VoucherDateVoided,
    AccountType,
    InsuranceAbv,
    InsuranceName,
    PatientNumberUpdated,
    PatientFullName,
    FromDOS AS DOS,
    Voucher,
    BillDate,
    ReBillDate,
    BillingProvider,
    NPI,
    PatientSubscriberID,
    ProcedureCode,
    ProcedureDescription,
    Modifier,
	DiagnosisCode,
    CAST(Units AS INT) AS Units,
    Charges,
    PersonalPayments,
    InsurancePayments,
    IntlPayments,
    ContractualAdjustment AS [Contractual Adjustments],
    Charity,
    Refunds AS Refund_Amounts,
    Allowed,
    TotalPayments,
	TotalAdjustments,
    BalTransFromTiger,
    IntlAdjustment,
    Bankruptcy,
    PatientBalanceDeemedUncollectible,
    CharityWriteOff,
    IndigentCharity,
    BundledNCCIEdit,
    ChargeError,
    GlobalPeriodNotBillable,
    AppealsExhaustedNotMedNecessary,
    ChargesNotReceivedfromSiteTimely,
    DeceasedPatient,
    FinancialHardship,
    G6017NotCovered,
    MUEMaxUnitsExceeded,
    NoAuthorizationObtained,
    NoncoveredService,
    NoTransferAgreementInpat,
    OutofNetwork,
    PromptPayAdjustment,
    SmallBalanceAdjustment,
    CollectionAgencyPayments,
    CollectionAgencyRefunds,
    CollectionAgencyTransfers,
    CollectionAgencyAdjustment,
    CollectionAgencyFeeAdjustment,
    OtherAdjs AS [All Other Adjustments],
    RemainingBalance,
    [Date Uploaded]
FROM [DataCleanup].[dbo].[DailyTransactions];
GO


-- Step 7: Create AriaData Table (Dimension Table)
--         Contains patient demographics and status flags
--         Integrates data from multiple source tables
CREATE TABLE DWFinance.dbo.AriaData (
    AriaID INT PRIMARY KEY IDENTITY(1,1),
    [Patient ID] NVARCHAR(255),
    [Patient DOB] DATE,
    [At Risk] NVARCHAR(255),
    [Research Patient Flag] NVARCHAR(255),
    [Active Insurance] NVARCHAR(255),
    PrimaryFlag NVARCHAR(255)
);

-- Step 7a: Populate AriaData using UNION to combine all unique patients
--          This creates a master patient list from multiple source tables
--          LEFT JOINs ensure all patients are included even if missing from some sources
WITH AllPatients AS (
    -- Combine unique patient IDs from all source tables
    SELECT PatientId FROM DataCleanup.dbo.ActiveInsurance
    UNION
    SELECT PatientId FROM DataCleanup.dbo.PatientDOB
    UNION
    SELECT PatientId FROM DataCleanup.dbo.[ResearchPatient]
    UNION
    SELECT PatientId FROM DataCleanup.dbo.AtRisk
)
INSERT INTO DWFinance.dbo.AriaData ([Patient ID], [Patient DOB], [At Risk], [Research Patient Flag], [Active Insurance], PrimaryFlag)
SELECT 
    AP.PatientId,
    P.DateOfBirth,
    AR.StatusIcon,             -- From AtRisk table: flags high-risk patients
    RP.StatusIcon,             -- From Research Patient table: research program flags
    AI.CompanyName,            -- From ActiveInsurance table: current insurance company
    AI.PrimaryFlag             -- From ActiveInsurance table: primary vs secondary insurance
FROM AllPatients AP
LEFT JOIN DataCleanup.dbo.PatientDOB P ON AP.PatientId = P.PatientId
LEFT JOIN DataCleanup.dbo.[ResearchPatient] RP ON AP.PatientId = RP.PatientId
LEFT JOIN DataCleanup.dbo.AtRisk AR ON AP.PatientId = AR.PatientId
LEFT JOIN DataCleanup.dbo.ActiveInsurance AI ON AP.PatientId = AI.PatientId;

-- End of Script 5
-- All scripts complete! Data warehouse is ready for reporting and analysis.
