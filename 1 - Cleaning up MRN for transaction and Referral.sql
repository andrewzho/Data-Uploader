/*
================================================================================
SCRIPT 1: Clean up MRN for Transactions and Referrals
================================================================================

PURPOSE:
  This script creates two cleaned data tables from raw import data:
  1. DailyTransactions - Financial transaction data from billing system
  2. Ref (Referrals) - Patient referral and admission data
  
It standardizes patient identifiers (MRNs), calculates financial metrics,
and creates normalized tables ready for analysis.

EXECUTION ORDER:
  - Run this script FIRST as it creates the base tables
  - Then run scripts 2-5 for additional data transformations

WHAT THIS DOES:
  1. Drops existing tables to ensure fresh data
  2. Creates DailyTransactions table with financial columns
  3. Populates it from TransactionsRaw, computing balance calculations
  4. Standardizes MRN format (removes dashes, fixes prefixes)
  5. Creates Ref table from ReferralRaw data
  6. Cleans MRN values in Ref table to match DailyTransactions
  7. Adds VisitNumber and TransMRN columns for tracking

================================================================================
*/

-- Step 1a: Drop existing tables to ensure fresh data (if they already exist)
--          This allows the script to be run multiple times without errors
DROP TABLE IF EXISTS [DataCleanup].[dbo].[DailyTransactions];
GO

DROP TABLE IF EXISTS [DataCleanup].[dbo].[Ref];
GO

-- Step 1b: Create the DailyTransactions table
--          This table contains financial transaction records from the billing system
--          Columns include payment amounts, adjustments, and calculated balance fields
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

-- Step 2: Insert data from TransactionsRaw and calculate financial metrics
--         This populates the new DailyTransactions table with:
--         - All raw financial data from TransactionsRaw
--         - Calculated fields: Allowed, TotalPayments, TotalAdjustments, RemainingBalance
--         - CharityAdjs, OtherAdjs, InternationalAdjs, PatientDirective, PayerDirective
--         - Excludes test/dummy patient records (those with specific test MRNs)
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

-- Step 3: Recalculate RemainingBalance with correct formula
--         Formula: Allowed - TotalPayments - Refunds - TotalAdjustments
--         This represents the outstanding patient/insurance balance
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET RemainingBalance = 
    (Allowed - TotalPayments - Refunds -TotalAdjustments);
GO

-- Step 4: Standardize MRN values in DailyTransactions
--         MRNs are patient identifiers that may have different formats
--         We normalize them so they match across different data sources

-- Step 4a: Fix specific MRN values that were incorrectly recorded
--          These are hard-coded mappings for known patient identifier errors
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

-- Step 4b: Remove dashes from MRN values to standardize format
--          Some systems include dashes (e.g., "SYN-1234"), we'll remove them temporarily
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET PatientNumberUpdated = REPLACE(PatientNumberUpdated, '-', '')
WHERE PatientNumberUpdated LIKE '%-%';

-- Step 4c: Fix misspelled "SNY" to correct "SYN"
--          This handles data entry errors in the patient identifier system
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET PatientNumberUpdated = REPLACE(PatientNumberUpdated, 'SNY', 'SYN')
WHERE PatientNumberUpdated LIKE '%SNY%';

-- Step 4d: Remove the 86 or 85 prefix from MRNs
--          The billing system prepends "86" or "85" to all MRNs, we extract the true MRN
--          Example: "86" + "1234" becomes "1234"
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET PatientNumberUpdated = SUBSTRING(PatientNumberUpdated, 3, LEN(PatientNumberUpdated) - 2)
WHERE (PatientNumberUpdated LIKE '86%' OR PatientNumberUpdated LIKE '85%');

-- Step 4e: Re-add the dash to SYN patient identifiers to match referral system format
--          SYN patients use a special format: "SYN-" prefix
--          Example: "SYN1234" becomes "SYN-1234"
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET PatientNumberUpdated = CONCAT('SYN-', SUBSTRING(PatientNumberUpdated, 4, LEN(PatientNumberUpdated) - 3))
WHERE PatientNumberUpdated LIKE 'S%';

-- Step 4f: Fix additional MRN mappings discovered through manual review
--          These corrections were validated by comparing data across systems
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


-- Step 5: Create the Ref (Referral) table
--         This table contains referral and admission information for patients
--         It includes clinical approvals, insurance authorizations, treatment dates
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
    [Comment] NVARCHAR(MAX),
    [On-Hold] BIT,
    [FBR] BIT,
    [Consult Date] DATETIME,
    [MultiPlan] BIT,
    [ICD 10 verified] BIT,
    [ICD 10] VARCHAR(255)

);
GO

-- Step 6: Populate Ref table from ReferralRaw data
--         Copy all referral data from the raw import, maintaining all date fields
--         and approval status information for tracking patient progress
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
    [Inquiry Source], [Funding Type], [Treatment], [Sim], [Consult],
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
    [Inquiry Source], [Funding Type], [Treatment], [Sim], [Consult],
    [Referred Back], [Sim Date], [1st Treatment], [Final Treatment], [Comment] ,
    [On-Hold] ,[FBR] ,[Consult Date] ,[MultiPlan] ,[ICD 10 verified] , [ICD 10]
FROM [DataCleanup].[dbo].[ReferralRaw];
GO

-- Step 7: Clean up MRN values in Ref table to match DailyTransactions format
--         Following the same standardization process as DailyTransactions

-- Step 7a: Remove dashes from all Patient IDs
UPDATE [DataCleanup].[dbo].[Ref]
SET [Patient ID] = REPLACE([Patient ID], '-', '');

-- Step 7b: Fix "SNY" misspellings to "SYN"
UPDATE [DataCleanup].[dbo].[Ref]
SET [Patient ID] = REPLACE([Patient ID], 'SNY', 'SYN')
WHERE [Patient ID] LIKE '%SNY%';

-- Step 7c: Re-add dash to SYN patient identifiers for consistency
UPDATE [DataCleanup].[dbo].[Ref]
SET [Patient ID] = CONCAT('SYN-', SUBSTRING([Patient ID], 4, LEN([Patient ID])))
WHERE [Patient ID] LIKE '%S%';

-- Step 8: Create Visit tracking columns
--         These columns track patient visits and create a unique identifier linking
--         transactions to referrals

-- Step 8a: Drop and recreate [Visit Number] column
--          This ensures a clean column state for the numbering operation
ALTER TABLE [DataCleanup].[dbo].[Ref]
DROP COLUMN [Visit Number]
GO

ALTER TABLE [DataCleanup].[dbo].[Ref]
ADD [Visit Number] NVARCHAR(255);;
GO

-- Step 8b: Assign sequential visit numbers to each patient
--          Visit 1 = first referral date, Visit 2 = second referral date, etc.
--          This helps identify multiple referrals for the same patient
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

-- Step 9: Create TransMRN column for linking transactions to referrals
--         TransMRN = PatientID + '-' + VisitNumber
--         This unique combination allows matching transaction records to specific referral visits

-- Step 9a: Drop and recreate TransMRN column
ALTER TABLE [DataCleanup].[dbo].[Ref]
DROP COLUMN TransMRN
GO

ALTER TABLE [DataCleanup].[dbo].[Ref]
ADD TransMRN NVARCHAR(255);
GO

-- Step 9b: Populate TransMRN with PatientID-VisitNumber format
--          Example: "1234-1" means patient 1234's first visit
UPDATE r
SET r.TransMRN = r.[Patient ID] + '-' + r.[Visit Number]
FROM DataCleanup.dbo.Ref r ;

-- End of Script 1
-- Next: Run "2 - Isolating First, Last, Middle - Transactions.sql"