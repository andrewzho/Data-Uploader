/*
================================================================================
RECREATE TRANSACTIONSRAW TABLE
================================================================================

PURPOSE:
  This script recreates the DataCleanup.dbo.TransactionsRaw table with the NEW
  structure that matches the current Excel file format.

EXECUTION:
  Run this script in SQL Server Management Studio (SSMS) or via your SQL execution tool
  before uploading TransactionsRaw data files.

WHAT THIS DOES:
  1. Drops the existing TransactionsRaw table (if it exists)
  2. Creates a new TransactionsRaw table with the NEW simplified structure
  3. Matches the Excel file format with consolidated Payments/Adjustments columns

IMPORTANT:
  After running this, you'll need to update Script 1 to handle the new structure
  since it expects individual adjustment columns that no longer exist.

================================================================================
*/

USE DataCleanup;
GO

-- Step 1: Drop existing TransactionsRaw table if it exists
IF OBJECT_ID('DataCleanup.dbo.TransactionsRaw', 'U') IS NOT NULL
BEGIN
    DROP TABLE [DataCleanup].[dbo].[TransactionsRaw];
    PRINT 'Existing TransactionsRaw table dropped.';
END
GO

-- Step 2: Create TransactionsRaw table with the NEW structure
--         This matches the current Excel file format
CREATE TABLE [DataCleanup].[dbo].[TransactionsRaw] (
    PaymentDateUpdated DATE,
    PaymentDateVoided DATE,
    VoucherDateUpdated DATE,
    VoucherDateVoided DATE,
    PracticeCompanyNumber FLOAT,
    DepartmentAbv NVARCHAR(255),
    AccountType NVARCHAR(255),
    InsuranceAbv NVARCHAR(255),
    InsuranceName NVARCHAR(255),
    PatientNumber NVARCHAR(255),
    PatientFullName NVARCHAR(255),
    FromDOS DATE,
    Voucher INT,
    BillDate DATE,
    ReBillDate DATE,
    BillingProvider NVARCHAR(255),
    NPI FLOAT,
    PatientSubscriberID NVARCHAR(255),
    ProcedureCode NVARCHAR(255),
    ProcedureDescription NVARCHAR(255),
    Modifier NVARCHAR(255),
    DiagnosisCode NVARCHAR(255),
    WorkRVU FLOAT,
    PERVU FLOAT,
    MPRVU FLOAT,
    Units FLOAT,
    Charges MONEY,
    Payments MONEY,                    -- NEW: Consolidated payments column
    Adjustments MONEY,                 -- NEW: Consolidated adjustments column
    Refunds MONEY,
    PersonalPayments MONEY,
    InsurancePayments MONEY,
    IntlPayments MONEY,
    AppealsExhaustedNotMedNecessary MONEY,
    Charity MONEY,
    CharityWriteOff MONEY,
    ContractualAdjustment MONEY,
    DeceasedPatient MONEY,
    FinancialHardship MONEY,
    IntlAdjustment MONEY,
    NoAuthorizationObtained MONEY,
    NoncoveredService MONEY,
    NoTransferAgreementInpat MONEY,
    OtherAdjustments MONEY,            -- NEW: Consolidated other adjustments
    OutofNetwork MONEY,
    PatientBalanceDeemedUncollectible MONEY,
    PromptPayAdjustment MONEY,
    RefundExceedsRecoupPeriod MONEY,
    DateRan DATE
);
GO

PRINT 'TransactionsRaw table created successfully with the NEW structure.';
PRINT '';
PRINT 'IMPORTANT: The table structure has changed significantly.';
PRINT 'The new file uses consolidated columns (Payments, Adjustments, OtherAdjustments)';
PRINT 'instead of individual adjustment columns.';
PRINT '';
PRINT 'You will need to update Script 1 to handle this new structure.';
PRINT 'You can now upload TransactionsRaw Excel files.';
GO

