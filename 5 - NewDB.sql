-- Create Fact and Dimension Tables for Data Warehouse
DROP TABLE IF EXISTS DWFinance.dbo.Fractions;
DROP TABLE IF EXISTS DWFinance.dbo.ICD_Crosswalk;
DROP TABLE IF EXISTS DWFinance.dbo.Referral_Masterlist;
DROP TABLE IF EXISTS DWFinance.dbo.Payer_Crosswalk;
DROP TABLE IF EXISTS DWFinance.dbo.RCB_Billing;
DROP TABLE IF EXISTS DWFinance.dbo.AriaData;

-- Creating Fractions Table
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


-- ICD Crosswalk
CREATE TABLE DWFinance.dbo.ICD_Crosswalk (
	[ICD ID] INT PRIMARY KEY IDENTITY (1,1),
	Prefix NVARCHAR(10),
	[ICD 10 Code] NVARCHAR(255),
	Description NVARCHAR(255),
	[ICD 10 Diagosis Category] NVARCHAR(255),
	[ICD 10 Sub-Category] NVARCHAR(255)
)

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

-- Referral 
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


-- Payer Crosswalk
CREATE TABLE DWFinance.dbo.Payer_Crosswalk (
	[Insurance Name] NVARCHAR(255),
	[Insurance Category Abv] NVARCHAR(255),
	[Insurance Category] NVARCHAR(255),
	[Insurance Roll Up] NVARCHAR(255)
)

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

-- Billing Data
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


-- AriaDataTable
CREATE TABLE DWFinance.dbo.AriaData (
    AriaID INT PRIMARY KEY IDENTITY(1,1),
    [Patient ID] NVARCHAR(255),
    [Patient DOB] DATE,
    [At Risk] NVARCHAR(255),
    [Research Patient Flag] NVARCHAR(255),
    [Active Insurance] NVARCHAR(255),
    PrimaryFlag NVARCHAR(255)
);

WITH AllPatients AS (
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
    AR.StatusIcon,             -- From AtRisk table
    RP.StatusIcon,             -- From Research Patient table
    AI.CompanyName,            -- From ActiveInsurance table
    AI.PrimaryFlag             -- From ActiveInsurance table
FROM AllPatients AP
LEFT JOIN DataCleanup.dbo.PatientDOB P ON AP.PatientId = P.PatientId
LEFT JOIN DataCleanup.dbo.[ResearchPatient] RP ON AP.PatientId = RP.PatientId
LEFT JOIN DataCleanup.dbo.AtRisk AR ON AP.PatientId = AR.PatientId
LEFT JOIN DataCleanup.dbo.ActiveInsurance AI ON AP.PatientId = AI.PatientId;
