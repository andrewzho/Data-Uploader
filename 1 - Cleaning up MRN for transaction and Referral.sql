-- Checking if a table exists already, if so drop it so we can have a fresh set of data.
DROP TABLE IF EXISTS [DataCleanup].[dbo].[DailyTransactions];
GO

DROP TABLE IF EXISTS [DataCleanup].[dbo].[Ref];
GO

-- Creates a new Transaction Table with new columns
CREATE TABLE [DataCleanup].[dbo].[DailyTransactions] (
    PaymentDateUpdated           DATE,
    PaymentDateVoided            DATE,
    VoucherDateUpdated           DATE,
    VoucherDateVoided            DATE,
    DateRan                      DATE,
    PracticeCompanyNumber        FLOAT,
    PracticeName                 NVARCHAR(255),
    DepartmentAbv                NVARCHAR(255),
    AccountType                  NVARCHAR(255),
    InsuranceAbv                 NVARCHAR(255),
    InsuranceName                NVARCHAR(255),
    PatientNumber                NVARCHAR(255),
    PatientNumberUpdated         NVARCHAR(255),
    PatientFullName              NVARCHAR(255),
    LastName                     NVARCHAR(255),
    FirstName                    NVARCHAR(255),
    MiddleName                   NVARCHAR(255),
    FromDOS                      DATE,
    Voucher                      INT,
    BillDate                     DATE,
    ReBillDate                   DATE,
    BillingProvider              NVARCHAR(255),
    NPI                          FLOAT,
    ProcedureCode                NVARCHAR(255),
    ProcedureDescription         NVARCHAR(255),  -- New column for RCB_Billing
    Modifier                     NVARCHAR(255),
    DiagnosisCode                NVARCHAR(255),
    WorkRVU                      FLOAT,
    PERVU                        FLOAT,
    MPRVU                        FLOAT,
    Units                        FLOAT,
    Charges                      MONEY,
    PersonalPayments             MONEY,
    InsurancePayments            MONEY,
    IntlPayments                 MONEY,
    ContractualAdjustment        MONEY,
    Refunds                      MONEY,
    Allowed                      MONEY,          -- Computed: Charges - ContractualAdjustment
    TotalPayments                MONEY,          -- Computed: PersonalPayments + InsurancePayments + IntlPayments
    TotalAdjustments             MONEY,          -- Computed from the sum of all raw adjustment fields
    RemainingBalance             MONEY,         
    Charity                      MONEY,
    BalTransFromTiger            MONEY,
    IntlAdjustment               MONEY,
    Bankruptcy                   MONEY,
    PatientBalanceDeemedUncollectible MONEY,
    CharityWriteOff              MONEY,
    IndigentCharity              MONEY,
    BundledNCCIEdit              MONEY,
    ChargeError                  MONEY,
    GlobalPeriodNotBillable      MONEY,
    AppealsExhaustedNotMedNecessary MONEY,
    ChargesNotReceivedfromSiteTimely MONEY,
    DeceasedPatient              MONEY,
    FinancialHardship            MONEY,
    G6017NotCovered              MONEY,
    MUEMaxUnitsExceeded          MONEY,
    NoAuthorizationObtained      MONEY,
    NoncoveredService            MONEY,
    NoTransferAgreementInpat     MONEY,
    OutofNetwork                 MONEY,
    PromptPayAdjustment          MONEY,          -- Raw prompt pay adjustment
    SmallBalanceAdjustment       MONEY,
    CollectionAgencyPayments     MONEY,
    CollectionAgencyRefunds      MONEY,
    CollectionAgencyTransfers    MONEY,
    CollectionAgencyAdjustment   MONEY,
    CollectionAgencyFeeAdjustment MONEY,
    CharityAdjs                  MONEY,          -- = Charity + CharityWriteOff + IndigentCharity + FinancialHardship
    OtherAdjs                    MONEY,          
    InternationalAdjs            MONEY,          -- = IntlAdjustment
    PatientDirective             MONEY,          -- = PatientBalanceDeemedUncollectible + DeceasedPatient
    PayerDirective               MONEY,          
    PrimaryInsurance             NVARCHAR(255),
    SecondaryInsurance           NVARCHAR(255),
    VisitNumber                  NVARCHAR(255),
    TransMRN                     NVARCHAR(255),
    PayerRollUp                  NVARCHAR(255),
    InsuranceCat                 NVARCHAR(255),
    PatientSubscriberID          NVARCHAR(255),  -- New column (not available in raw, so will default to '')
    [Date Uploaded]              DATE
);
GO

-- Insert data into the new table
INSERT INTO [DataCleanup].[dbo].[DailyTransactions] (
    PaymentDateUpdated,
    PaymentDateVoided,
    VoucherDateUpdated,
    VoucherDateVoided,
    DateRan,
    PracticeCompanyNumber,
    PracticeName,
    DepartmentAbv,
    AccountType,
    InsuranceAbv,
    InsuranceName,
    PatientNumber,
    PatientNumberUpdated,
    PatientFullName,
    LastName,
    FirstName,
    MiddleName,
    FromDOS,
    Voucher,
    BillDate,
    ReBillDate,
    BillingProvider,
    NPI,
    ProcedureCode,
    ProcedureDescription,
    Modifier,
    DiagnosisCode,
    WorkRVU,
    PERVU,
    MPRVU,
    Units,
    Charges,
    PersonalPayments,
    InsurancePayments,
    IntlPayments,
    ContractualAdjustment,
    Refunds,
    Allowed,
    TotalPayments,
    TotalAdjustments,
    RemainingBalance,
    Charity,
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
    CharityAdjs,
    OtherAdjs,
    InternationalAdjs,
    PatientDirective,
    PayerDirective,
    PatientSubscriberID,
    [Date Uploaded]
)
SELECT
    PaymentDateUpdated,
    PaymentDateVoided,
    VoucherDateUpdated,
    VoucherDateVoided,
    DateRan,
    PracticeCompanyNumber,
    PracticeName,
    DepartmentAbv,
    AccountType,
    InsuranceAbv,
    InsuranceName,
    PatientNumber,
    PatientNumber AS PatientNumberUpdated,
    PatientFullName,
    '' AS LastName,
    '' AS FirstName,
    '' AS MiddleName,
    FromDOS,
    Voucher,
    BillDate,
    ReBillDate,
    BillingProvider,
    NPI,
    ProcedureCode,
    ProcedureDescription,
    Modifier,
    DiagnosisCode,
    WorkRVU,
    PERVU,
    MPRVU,
    Units,
    COALESCE(Charges,0)               AS Charges,
    COALESCE(PersonalPayments,0)      AS PersonalPayments,
    COALESCE(InsurancePayments,0)     AS InsurancePayments,
    COALESCE(IntlPayments,0)          AS IntlPayments,
    COALESCE(ContractualAdjustment,0) AS ContractualAdjustment,
    COALESCE(Refunds,0)               AS Refunds,
    COALESCE(Charges,0)
  - COALESCE(ContractualAdjustment,0) AS Allowed,
    COALESCE(PersonalPayments,0)
  + COALESCE(InsurancePayments,0)
  + COALESCE(IntlPayments,0)          AS TotalPayments,
    COALESCE(Charity,0)
  + COALESCE(BalTransFromTiger,0)
  + COALESCE(IntlAdjustment,0)
  + COALESCE(Bankruptcy,0)
  + COALESCE(PatientBalanceDeemedUncollectible,0)
  + COALESCE(CharityWriteOff,0)
  + COALESCE(IndigentCharity,0)
  + COALESCE(BundledNCCIEdit,0)
  + COALESCE(ChargeError,0)
  + COALESCE(GlobalPeriodNotBillable,0)
  + COALESCE(AppealsExhaustedNotMedNecessary,0)
  + COALESCE(ChargesNotReceivedfromSiteTimely,0)
  + COALESCE(DeceasedPatient,0)
  + COALESCE(FinancialHardship,0)
  + COALESCE(G6017NotCovered,0)
  + COALESCE(MUEMaxUnitsExceeded,0)
  + COALESCE(NoAuthorizationObtained,0)
  + COALESCE(NoncoveredService,0)
  + COALESCE(NoTransferAgreementInpat,0)
  + COALESCE(OutofNetwork,0)
  + COALESCE(PromptPayAdjustment,0)
  + COALESCE(SmallBalanceAdjustment,0)
  + COALESCE(CollectionAgencyPayments,0)
  + COALESCE(CollectionAgencyRefunds,0)
  + COALESCE(CollectionAgencyTransfers,0)
  + COALESCE(CollectionAgencyAdjustment,0)
  + COALESCE(CollectionAgencyFeeAdjustment,0) AS TotalAdjustments,
    (COALESCE(Charges,0) - COALESCE(ContractualAdjustment,0))
  - (COALESCE(PersonalPayments,0)
     + COALESCE(InsurancePayments,0)
     + COALESCE(IntlPayments,0))
  - (COALESCE(Charity,0)
    + COALESCE(BalTransFromTiger,0)
    + COALESCE(IntlAdjustment,0)
    + COALESCE(Bankruptcy,0)
    + COALESCE(PatientBalanceDeemedUncollectible,0)
    + COALESCE(CharityWriteOff,0)
    + COALESCE(IndigentCharity,0)
    + COALESCE(BundledNCCIEdit,0)
    + COALESCE(ChargeError,0)
    + COALESCE(GlobalPeriodNotBillable,0)
    + COALESCE(AppealsExhaustedNotMedNecessary,0)
    + COALESCE(ChargesNotReceivedfromSiteTimely,0)
    + COALESCE(DeceasedPatient,0)
    + COALESCE(FinancialHardship,0)
    + COALESCE(G6017NotCovered,0)
    + COALESCE(MUEMaxUnitsExceeded,0)
    + COALESCE(NoAuthorizationObtained,0)
    + COALESCE(NoncoveredService,0)
    + COALESCE(NoTransferAgreementInpat,0)
    + COALESCE(OutofNetwork,0)
    + COALESCE(PromptPayAdjustment,0)
    + COALESCE(SmallBalanceAdjustment,0)
    + COALESCE(CollectionAgencyPayments,0)
    + COALESCE(CollectionAgencyRefunds,0)
    + COALESCE(CollectionAgencyTransfers,0)
    + COALESCE(CollectionAgencyAdjustment,0)
    + COALESCE(CollectionAgencyFeeAdjustment,0)
    ) 
	- COALESCE(Refunds,0) AS RemainingBalance,
    Charity,
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
    (Charity + CharityWriteOff + IndigentCharity + FinancialHardship) AS CharityAdjs,
    (BalTransFromTiger + Bankruptcy + BundledNCCIEdit + ChargeError +
     GlobalPeriodNotBillable + ChargesNotReceivedfromSiteTimely + G6017NotCovered +
     CollectionAgencyAdjustment + CollectionAgencyFeeAdjustment +
     CollectionAgencyPayments + CollectionAgencyRefunds + CollectionAgencyTransfers) AS OtherAdjs,
    IntlAdjustment AS InternationalAdjs,
    (PatientBalanceDeemedUncollectible + DeceasedPatient) AS PatientDirective,
    (AppealsExhaustedNotMedNecessary + MUEMaxUnitsExceeded + NoAuthorizationObtained +
     NoncoveredService + NoTransferAgreementInpat + OutofNetwork + SmallBalanceAdjustment) AS PayerDirective,
    PatientSubscriberID,
    GETDATE() AS [Date Uploaded]
FROM [DataCleanup].[dbo].[TransactionsRaw]
WHERE PatientNumber NOT IN ('40','460', '866336', '86SYN-10001', '865301', '86zzrcbillingtest1', '86zztestapple');
GO

-- Update the RemainingBalance column with the correct calculation
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET RemainingBalance = 
    (Allowed - TotalPayments - Refunds -TotalAdjustments);
GO
-- Hard Coded MRN changes for those that don't have an 86 in front of their MRN.
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET PatientNumberUpdated = CASE
    WHEN PatientNumberUpdated = '86' THEN '391'
    WHEN PatientNumberUpdated = '90' THEN '492'
    WHEN PatientNumberUpdated = '210' THEN '463'
    WHEN PatientNumberUpdated = '120' THEN '493'
    WHEN PatientNumberUpdated = '100' THEN '474'
    WHEN PatientNumberUpdated = '110' THEN 'SYN-11102'
    WHEN PatientNumberUpdated = '220' THEN '589'
    WHEN PatientNumberUpdated = '240' THEN '611'
	ELSE PatientNumberUpdated
END;

-- Remove '-' to standardize the MRN's
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET PatientNumberUpdated = REPLACE(PatientNumberUpdated, '-', '')
WHERE PatientNumberUpdated LIKE '%-%';

-- Fix incorrect spelling of SNY
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET PatientNumberUpdated = REPLACE(PatientNumberUpdated, 'SNY', 'SYN')
WHERE PatientNumberUpdated LIKE '%SNY%';

-- Removing the 86 or 85 to get the TrueMRN for Transactions
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET PatientNumberUpdated = SUBSTRING(PatientNumberUpdated, 3, LEN(PatientNumberUpdated) - 2)
WHERE (PatientNumberUpdated LIKE '86%' OR PatientNumberUpdated LIKE '85%');

-- Readd the - to the SYN Patients to make MRN's match Referral's MRN
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET PatientNumberUpdated = CONCAT('SYN-', SUBSTRING(PatientNumberUpdated, 4, LEN(PatientNumberUpdated) - 3))
WHERE PatientNumberUpdated LIKE 'S%';

-- Hard Coded Patient MRN Transformations for post 86/85 Removal
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET PatientNumberUpdated = CASE
    WHEN PatientNumberUpdated = '62A' THEN '62'
	WHEN PatientNumberUpdated = '9732' THEN '9740' -- done through review
	WHEN PatientNumberUpdated = '9734' THEN '9732' -- done through review
    WHEN PatientNumberUpdated = '1918' THEN '2162'
    WHEN PatientNumberUpdated = '5112' THEN '5169'
    WHEN PatientNumberUpdated = '5546TC' THEN '5546'
    WHEN PatientNumberUpdated = '2621' THEN '5598'
    WHEN PatientNumberUpdated = '2421' THEN '6039'
    WHEN PatientNumberUpdated = '1469' THEN '7658'
    WHEN PatientNumberUpdated = '8896' THEN '8909'
	WHEN PatientNumberUpdated = '9739' THEN '9730' -- done through review
    WHEN PatientNumberUpdated = '0001' THEN '9739'
	WHEN PatientNumberUpdated = '8.6e+11' THEN '70' -- done through review
	WHEN PatientNumberUpdated = '11408' THEN '11446'
	WHEN PatientNumberUpdated = '12523' THEN '12602'
    ELSE PatientNumberUpdated -- This keeps the current value if no match is found
END;


CREATE TABLE DataCleanup.dbo.Ref (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    [Patient ID] NVARCHAR(255),
    [Patient Name] NVARCHAR(255),
    State NVARCHAR(255),
    [Referral Date] date,
    [Ref Month] date,
    [Self-referral Inquiry Date] date,
    DOB date,
    SBRT bit,
    [Prior RT] bit,
    [IV Contrast] bit,
    [Primary Insurance] NVARCHAR(255),
    [Secondary Insurance] NVARCHAR(255),
    [Insurance Category] NVARCHAR(255),
    [Disease Site] NVARCHAR(255),
    Anesthesia bit,
    [Referring Hospital] NVARCHAR(255),
    [Other Hosp Detail] NVARCHAR(255),
    [Referring Physician] NVARCHAR(255),
    [Attending Physician] NVARCHAR(255),
    [NYPC Clinical Approval] NVARCHAR(255),
    [Insurance Approval] NVARCHAR(255),
    [Final Approval] NVARCHAR(255),
    Reason NVARCHAR(255),
    [At Risk] bit,
    [Treatment Status] NVARCHAR(255),
    Trial NVARCHAR(255),
    [Fin Counselor] NVARCHAR(255),
    [ROI Date] date,
    [Intake Acceptance Date] date,
    [Decision Date] date,
    [Insurance decision date (For at risk patients)] date,
    [Auth Initiation Date] date,
    [IRO Submission Date] date,
    [1st Appeal Denial Date] date,
    [2nd Appeal Denial Date] date,
    [Peer to Peer Date] date,
    [LMN Date] date,
    [Comparison Sim Date] date,
    [Comparison Plan Requested Date] date,
    [Comparison Plan Completed Date] date,
    [FY Quarter] NVARCHAR(255),
    [Inquiry Source] NVARCHAR(255),
    [Visit Number] NVARCHAR(255), -- new
    TransMRN NVARCHAR(255),
    FirstName NVARCHAR(255),
    RemainingBalance MONEY,
    UpdatedPrimary NVARCHAR(255),
    UpdatedSecondary NVARCHAR(255),
    InsuranceAbv NVARCHAR(255),
    InsuranceCat NVARCHAR(255),
    [Funding Type] VARCHAR(255),
    Treatment bit,
    Sim bit,
    Consult bit,
    [Referred Back] NVARCHAR(255),
    [Sim Date] DATETIME,
    [1st Treatment] DATETIME,
    [Final Treatment] DATETIME,
    [Comment] VARCHAR(255),
    [On-Hold] BIT,
    [FBR] BIT,
    [Consult Date] DATETIME,
    [MultiPlan] BIT,
    [ICD 10 verified] BIT,
    [ICD 10] VARCHAR(255)

);
GO

-- Step 2: Copy Data from Existing Table to Temporary Table
INSERT INTO DataCleanup.dbo.Ref (
    [Patient ID], [Patient Name], State, [Referral Date], [Ref Month],
    [Self-referral Inquiry Date], DOB, SBRT, [Prior RT], [IV Contrast], 
    [Primary Insurance], [Secondary Insurance], [Insurance Category], [Disease Site], 
    Anesthesia, [Referring Hospital], [Other Hosp Detail], [Referring Physician], 
    [Attending Physician], [NYPC Clinical Approval], [Insurance Approval], 
    [Final Approval], Reason, [At Risk], [Treatment Status], Trial, [Fin Counselor], 
    [ROI Date], [Intake Acceptance Date], [Decision Date], 
    [Insurance decision date (For at risk patients)], [Auth Initiation Date], 
    [IRO Submission Date], [1st Appeal Denial Date], [2nd Appeal Denial Date], 
    [Peer to Peer Date], [LMN Date], [Comparison Sim Date], 
    [Comparison Plan Requested Date], [Comparison Plan Completed Date], 
    [FY Quarter], [Inquiry Source], [Funding Type], [Treatment], [Sim], [Consult],
    [Referred Back], [Sim Date], [1st Treatment], [Final Treatment], [Comment] ,
    [On-Hold] ,[FBR] ,[Consult Date] ,[MultiPlan] ,[ICD 10 verified] , [ICD 10]
)
SELECT
	[Patient ID], [Patient Name], State, [Referral Date], [Ref Month],
    [Self-referral Inquiry Date], DOB, SBRT, [Prior RT], [IV Contrast], 
    [Primary Insurance], [Secondary Insurance], [Insurance Category], [Disease Site], 
    Anesthesia, [Referring Hospital], [Other Hosp Detail], [Referring Physician], 
    [Attending Physician], [NYPC Clinical Approval], [Insurance Approval], 
    [Final Approval], Reason, [At Risk], [Treatment Status], Trial, [Fin Counselor], 
    [ROI Date], [Intake Acceptance Date], [Decision Date], 
    [Insurance decision date (For at risk patients)], [Auth Initiation Date], 
    [IRO Submission Date], [1st Appeal Denial Date], [2nd Appeal Denial Date], 
    [Peer to Peer Date], [LMN Date], [Comparison Sim Date], 
    [Comparison Plan Requested Date], [Comparison Plan Completed Date], 
    [FY Quarter], [Inquiry Source], [Funding Type], [Treatment], [Sim], [Consult],
    [Referred Back], [Sim Date], [1st Treatment], [Final Treatment], [Comment] ,
    [On-Hold] ,[FBR] ,[Consult Date] ,[MultiPlan] ,[ICD 10 verified] , [ICD 10]
FROM [DataCleanup].[dbo].[ReferralRaw];
GO


-- Removing '-' for Ref
UPDATE [DataCleanup].[dbo].[Ref]
SET [Patient ID] = REPLACE([Patient ID], '-', '');

-- Fix incorrect spelling of SNY
UPDATE [DataCleanup].[dbo].[Ref]
SET [Patient ID] = REPLACE([Patient ID], 'SNY', 'SYN')
WHERE [Patient ID] LIKE '%SNY%';

-- Readd the - to the SYN Patient
UPDATE [DataCleanup].[dbo].[Ref]
SET [Patient ID] = CONCAT('SYN-', SUBSTRING([Patient ID], 4, LEN([Patient ID])))
WHERE [Patient ID] LIKE '%S%';

-- Add the VisitNumber column
ALTER TABLE [DataCleanup].[dbo].[Ref]
DROP COLUMN [Visit Number]
GO

ALTER TABLE [DataCleanup].[dbo].[Ref]
ADD [Visit Number] NVARCHAR(255);;
GO

-- Update the VisitNumber column
WITH NumberedVisits AS (
    SELECT 
        [Patient ID], 
        [Referral Date], 
        ROW_NUMBER() OVER (PARTITION BY [Patient ID] ORDER BY [Referral Date]) AS [Visit Number]
    FROM [DataCleanup].[dbo].[Ref]
)
UPDATE r
SET r.[Visit Number] = nv.[Visit Number]
FROM [DataCleanup].[dbo].[Ref] r
JOIN NumberedVisits nv
ON r.[Patient ID] = nv.[Patient ID] 
AND r.[Referral Date] = nv.[Referral Date];

-- Add the TransMRN column
ALTER TABLE [DataCleanup].[dbo].[Ref]
DROP COLUMN TransMRN
GO

ALTER TABLE [DataCleanup].[dbo].[Ref]
ADD TransMRN NVARCHAR(255);
GO

UPDATE r
SET r.TransMRN = r.[Patient ID] + '-' + r.[Visit Number]
FROM DataCleanup.dbo.Ref r ;