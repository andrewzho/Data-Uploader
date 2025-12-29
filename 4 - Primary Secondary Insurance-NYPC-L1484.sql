/*
================================================================================
SCRIPT 4: Identify Primary & Secondary Insurance and Link to Payer Data
================================================================================

PURPOSE:
  This script determines the primary and secondary insurance for each referral
  based on treatment units, then enriches the data with payer category information.

EXECUTION ORDER:
  - Run after Scripts 1-3
  - Run before Script 5

KEY CONCEPT:
  For each patient referral period:
  1. Sum up treatment units by insurance company used in transactions
  2. The insurance with the most units = Primary Insurance
  3. The insurance with 2nd most units = Secondary Insurance
  4. If no insurance found, default to "Self-Pay"
  5. Look up payer category info from the Payer Crosswalk table
  
  Result: All referrals and transactions have standardized insurance info.

================================================================================
*/

-- Step 1a: Add UpdatedPrimary/UpdatedSecondary columns to Ref table (if not exists)
--          These will hold the primary and secondary insurance names
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Ref' AND COLUMN_NAME='UpdatedPrimary')
BEGIN
    ALTER TABLE [DataCleanup].[dbo].[Ref]
    ADD UpdatedPrimary NVARCHAR(255);
END
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Ref' AND COLUMN_NAME='UpdatedSecondary')
BEGIN
    ALTER TABLE [DataCleanup].[dbo].[Ref]
    ADD UpdatedSecondary NVARCHAR(255);
END
GO

-- Step 1b: Add PrimaryInsurance/SecondaryInsurance columns to DailyTransactions (if not exists)
--          These will be populated from the Ref table based on referral period
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='DailyTransactions' AND COLUMN_NAME='PrimaryInsurance')
    ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
    DROP COLUMN PrimaryInsurance, SecondaryInsurance;
    
ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
ADD PrimaryInsurance NVARCHAR(255), 
	SecondaryInsurance NVARCHAR(255);
GO

-- Step 1c: Add VisitNumber column to DailyTransactions and DenialData
--          VisitNumber links transactions to specific referral visits
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='DailyTransactions' AND COLUMN_NAME='VisitNumber')
    ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
    DROP COLUMN VisitNumber;
    
ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
ADD VisitNumber NVARCHAR(255);
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='DenialData' AND COLUMN_NAME='VisitNumber')
    ALTER TABLE [DataCleanup].[dbo].DenialData
    DROP COLUMN VisitNumber;
    
ALTER TABLE [DataCleanup].[dbo].DenialData
ADD VisitNumber NVARCHAR(255);
GO


-- Step 2: Create a CTE to number referrals by patient
--         This identifies each referral's order (1st, 2nd, 3rd, etc.) for a patient
WITH NumberedReferrals AS (
    SELECT
        rs.[Patient ID],
        rs.[Referral Date],
        ROW_NUMBER() OVER (PARTITION BY rs.[Patient ID] ORDER BY rs.[Referral Date]) AS ReferralOrder
    FROM 
        [DataCleanup].[dbo].[Ref] rs
)

-- Step 3: Calculate insurance usage by units during each referral period
--         For each patient/referral combo:
--         - Sum up the total units associated with each insurance
--         - Count how many times each insurance appears
--         - Rank insurances by units (highest first), then by frequency
, InsuranceUnits AS (
    SELECT
        nr.[Patient ID],
        nr.[Referral Date],
        dt.[InsuranceName],
        SUM(dt.[Units]) AS TotalUnits,
		COUNT(dt.[InsuranceName]) AS InsuranceCount,
        ROW_NUMBER() OVER (PARTITION BY nr.[Patient ID], nr.[Referral Date] ORDER BY SUM(dt.[Units]) DESC, COUNT(dt.[InsuranceName])) AS InsuranceRank
    FROM 
        NumberedReferrals nr
    LEFT JOIN 
        [DataCleanup].[dbo].[DailyTransactions] dt
    ON 
        nr.[Patient ID] = dt.[PatientNumberUpdated]
    AND 
        dt.[FromDOS] >= nr.[Referral Date]
    AND 
        -- Include only transactions before the next referral
        dt.[FromDOS] < ISNULL(
            (SELECT MIN(nr2.[Referral Date])
             FROM NumberedReferrals nr2
             WHERE nr2.[Patient ID] = nr.[Patient ID]
             AND nr2.[ReferralOrder] > nr.[ReferralOrder]), 
             '9999-12-31')
    GROUP BY
        nr.[Patient ID],
        nr.[Referral Date],
        dt.[InsuranceName]
)

-- Step 4: Select top 2 insurances per referral
--         Insurance Rank 1 = Primary (most units)
--         Insurance Rank 2+ = Secondary (2nd most units)
--         If no insurance found, default Primary to "Self-Pay"
, TopInsurances AS (
    SELECT
        iu.[Patient ID],
        iu.[Referral Date],
        -- PRIMARY: Rank 1 or default to "Self-Pay" if no insurance transactions exist
        COALESCE(MAX(CASE WHEN iu.InsuranceRank = 1 THEN iu.[InsuranceName] END), 'Self-Pay') AS UpdatedPrimary,
        -- SECONDARY: Rank 2 or higher (skip NULLs which come from referrals with only 1 insurance)
        MIN(CASE WHEN iu.InsuranceRank >= 2 AND iu.InsuranceName IS NOT NULL THEN iu.[InsuranceName] END) AS UpdatedSecondary
    FROM 
        InsuranceUnits iu
    GROUP BY
        iu.[Patient ID],
        iu.[Referral Date]
)

-- Step 5: Update Ref table with calculated primary/secondary insurance
--         Only update records that have matching transaction data
UPDATE rs
SET rs.UpdatedPrimary = ti.UpdatedPrimary,
    rs.UpdatedSecondary = ti.UpdatedSecondary
FROM 
    [DataCleanup].[dbo].[Ref] rs
JOIN 
    TopInsurances ti
ON 
    rs.[Patient ID] = ti.[Patient ID]
AND 
    rs.[Referral Date] = ti.[Referral Date]
WHERE EXISTS ( 
    -- Ensure there are actual transactions for this patient
    SELECT 1
    FROM [DataCleanup].[dbo].[DailyTransactions] dt
    WHERE rs.[Patient ID] = dt.[PatientNumberUpdated]
);
GO

-- Step 6: Update DailyTransactions with insurance and visit info from Ref
--         This brings insurance and visit number data from Ref into every transaction
UPDATE dt
SET dt.PrimaryInsurance = rs.UpdatedPrimary,
    dt.SecondaryInsurance = rs.UpdatedSecondary,
	dt.VisitNumber = rs.[Visit Number]
FROM 
    [DataCleanup].[dbo].[DailyTransactions] dt
JOIN 
    [DataCleanup].[dbo].[Ref] rs
ON 
    dt.[PatientNumberUpdated] = rs.[Patient ID]
AND 
    dt.[FromDOS] >= rs.[Referral Date]
AND 
    -- Only match transactions within this referral period
    dt.[FromDOS] < ISNULL(
        (SELECT MIN(rs2.[Referral Date])
         FROM [DataCleanup].[dbo].[Ref] rs2
         WHERE rs2.[Patient ID] = rs.[Patient ID]
         AND rs2.[Referral Date] > rs.[Referral Date]), 
         '9999-12-31');
GO

-- Step 7: Update DenialData with visit number information
--         Denial records need to be linked to the correct referral visit
UPDATE dd
SET 
	dd.VisitNumber = rs.[Visit Number]
FROM 
    [DataCleanup].[dbo].DenialData dd
JOIN 
    [DataCleanup].[dbo].[Ref] rs
ON 
    dd.Patient_Account = rs.[Patient ID]
AND 
    dd.DOS >= rs.[Referral Date]
AND 
    dd.DOS < ISNULL(
        (SELECT MIN(rs2.[Referral Date])
         FROM [DataCleanup].[dbo].[Ref] rs2
         WHERE rs2.[Patient ID] = rs.[Patient ID]
         AND rs2.[Referral Date] > rs.[Referral Date]), 
         '9999-12-31');
GO


-- Step 8: Add TransMRN column to DailyTransactions
--         TransMRN = PatientID + '-' + VisitNumber (links transaction to referral visit)
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='DailyTransactions' AND COLUMN_NAME='TransMRN')
    ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
    DROP COLUMN TransMRN;
    
ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
ADD TransMRN NVARCHAR(255);
GO

UPDATE dt
SET dt.TransMRN = dt.[PatientNumberUpdated] + '-' + dt.VisitNumber
FROM DataCleanup.dbo.[DailyTransactions] dt ;

-- Step 9: Add payer category columns to Ref table
--         These columns will be populated from the Payer Crosswalk table
--         for both Primary and Secondary insurances
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Ref' AND COLUMN_NAME='Primary_InsuranceAbv')
    ALTER TABLE DataCleanup.dbo.Ref DROP COLUMN Primary_InsuranceAbv;
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Ref' AND COLUMN_NAME='Primary_InsuranceCat')
    ALTER TABLE DataCleanup.dbo.Ref DROP COLUMN Primary_InsuranceCat;
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Ref' AND COLUMN_NAME='Primary_PayerRollUp')
    ALTER TABLE DataCleanup.dbo.Ref DROP COLUMN Primary_PayerRollUp;
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Ref' AND COLUMN_NAME='Secondary_InsuranceAbv')
    ALTER TABLE DataCleanup.dbo.Ref DROP COLUMN Secondary_InsuranceAbv;
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Ref' AND COLUMN_NAME='Secondary_InsuranceCat')
    ALTER TABLE DataCleanup.dbo.Ref DROP COLUMN Secondary_InsuranceCat;
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Ref' AND COLUMN_NAME='Secondary_PayerRollUp')
    ALTER TABLE DataCleanup.dbo.Ref DROP COLUMN Secondary_PayerRollUp;
GO

-- Step 10: Create the new payer category columns
ALTER TABLE DataCleanup.dbo.Ref
ADD Primary_InsuranceAbv NVARCHAR(255), 
    Primary_InsuranceCat NVARCHAR(255), 
    Primary_PayerRollUp NVARCHAR(255),
	Secondary_InsuranceAbv NVARCHAR(255), 
    Secondary_InsuranceCat NVARCHAR(255), 
    Secondary_PayerRollUp NVARCHAR(255);
GO

-- Step 11: Populate Primary Insurance category info from Payer Crosswalk
--          Match UpdatedPrimary insurance to Payer Crosswalk table to get category details
UPDATE r
SET r.Primary_InsuranceCat = pc.[Category - Type],
    r.Primary_InsuranceAbv = pc.InsuranceCatAbv,
	r.Primary_PayerRollUp = pc.[Payer Roll-Up]
FROM [DataCleanup].[dbo].[Ref] r
JOIN [DataCleanup].[dbo].[Payer Crosswalk] pc ON r.UpdatedPrimary = pc.[Insurance Product Detail];
GO

-- Step 12: Populate Secondary Insurance category info from Payer Crosswalk
--          Match UpdatedSecondary insurance to Payer Crosswalk table to get category details
UPDATE r
SET r.Secondary_InsuranceCat = pc.[Category - Type],
    r.Secondary_InsuranceAbv = pc.InsuranceCatAbv,
	r.Secondary_PayerRollUp = pc.[Payer Roll-Up]
FROM [DataCleanup].[dbo].[Ref] r
JOIN [DataCleanup].[dbo].[Payer Crosswalk] pc ON r.UpdatedSecondary = pc.[Insurance Product Detail];
GO

-- Step 13: Add payer category columns to DailyTransactions
--          These will be populated from the same Payer Crosswalk data
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='DailyTransactions' AND COLUMN_NAME='InsuranceAbv')
    ALTER TABLE DataCleanup.dbo.DailyTransactions
    DROP COLUMN InsuranceAbv, InsuranceCat, PayerRollUp;
    
ALTER TABLE DataCleanup.dbo.DailyTransactions
ADD InsuranceAbv NVARCHAR(255), 
    InsuranceCat NVARCHAR(255),
    PayerRollUp NVARCHAR(255);
GO

-- Step 14: Populate DailyTransactions insurance categories from Payer Crosswalk
--          Match PrimaryInsurance to Payer Crosswalk for each transaction
UPDATE dt
SET dt.InsuranceCat = pc.[Category - Type],
    dt.InsuranceAbv = pc.InsuranceCatAbv,
	dt.PayerRollUp = pc.[Payer Roll-Up]
FROM DataCleanup.dbo.DailyTransactions dt
JOIN [DataCleanup].[dbo].[Payer Crosswalk] pc ON dt.PrimaryInsurance = pc.[Insurance Product Detail];
GO

-- End of Script 4
-- Next: Run "5 - NewDB.sql"
SET rs.UpdatedPrimary = ti.UpdatedPrimary,
    rs.UpdatedSecondary = ti.UpdatedSecondary
FROM 
    [DataCleanup].[dbo].[Ref] rs
JOIN 
    TopInsurances ti
ON 
    rs.[Patient ID] = ti.[Patient ID]
AND 
    rs.[Referral Date] = ti.[Referral Date]
-- ensures only those with a match in DailyTransactions will be updated in Referral
WHERE EXISTS ( 
    SELECT 1
    FROM [DataCleanup].[dbo].[DailyTransactions] dt
    WHERE rs.[Patient ID] = dt.[PatientNumberUpdated]
);
GO

-- Update the DailyTransactions table with the primary and secondary insurance information from the Ref table
UPDATE dt
SET dt.PrimaryInsurance = rs.UpdatedPrimary,
    dt.SecondaryInsurance = rs.UpdatedSecondary,
	dt.VisitNumber = rs.[Visit Number]
FROM 
    [DataCleanup].[dbo].[DailyTransactions] dt
JOIN 
    [DataCleanup].[dbo].[Ref] rs
ON 
    dt.[PatientNumberUpdated] = rs.[Patient ID]
AND 
    dt.[FromDOS] >= rs.[Referral Date]
AND 
    dt.[FromDOS] < ISNULL(
        (SELECT MIN(rs2.[Referral Date])
         FROM [DataCleanup].[dbo].[Ref] rs2
         WHERE rs2.[Patient ID] = rs.[Patient ID]
         AND rs2.[Referral Date] > rs.[Referral Date]), 
         '9999-12-31'); -- Use a distant future date as the default end date
GO

UPDATE dd
SET 
	dd.VisitNumber = rs.[Visit Number]
FROM 
    [DataCleanup].[dbo].DenialData dd
JOIN 
    [DataCleanup].[dbo].[Ref] rs
ON 
    dd.Patient_Account = rs.[Patient ID]
AND 
    dd.DOS >= rs.[Referral Date]
AND 
    dd.DOS < ISNULL(
        (SELECT MIN(rs2.[Referral Date])
         FROM [DataCleanup].[dbo].[Ref] rs2
         WHERE rs2.[Patient ID] = rs.[Patient ID]
         AND rs2.[Referral Date] > rs.[Referral Date]), 
         '9999-12-31'); -- Use a distant future date as the default end date
GO


-- Add/recreate TransMRN column in DailyTransactions if needed
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='DailyTransactions' AND COLUMN_NAME='TransMRN')
    ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
    DROP COLUMN TransMRN;
    
ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
ADD TransMRN NVARCHAR(255);
GO

UPDATE dt
SET dt.TransMRN = dt.[PatientNumberUpdated] + '-' + dt.VisitNumber
FROM DataCleanup.dbo.[DailyTransactions] dt ;

-- Drop columns if they exist
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Ref' AND COLUMN_NAME='Primary_InsuranceAbv')
    ALTER TABLE DataCleanup.dbo.Ref DROP COLUMN Primary_InsuranceAbv;
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Ref' AND COLUMN_NAME='Primary_InsuranceCat')
    ALTER TABLE DataCleanup.dbo.Ref DROP COLUMN Primary_InsuranceCat;
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Ref' AND COLUMN_NAME='Primary_PayerRollUp')
    ALTER TABLE DataCleanup.dbo.Ref DROP COLUMN Primary_PayerRollUp;
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Ref' AND COLUMN_NAME='Secondary_InsuranceAbv')
    ALTER TABLE DataCleanup.dbo.Ref DROP COLUMN Secondary_InsuranceAbv;
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Ref' AND COLUMN_NAME='Secondary_InsuranceCat')
    ALTER TABLE DataCleanup.dbo.Ref DROP COLUMN Secondary_InsuranceCat;
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Ref' AND COLUMN_NAME='Secondary_PayerRollUp')
    ALTER TABLE DataCleanup.dbo.Ref DROP COLUMN Secondary_PayerRollUp;
GO

-- Add columns
ALTER TABLE DataCleanup.dbo.Ref
ADD Primary_InsuranceAbv NVARCHAR(255), 
    Primary_InsuranceCat NVARCHAR(255), 
    Primary_PayerRollUp NVARCHAR(255),
	Secondary_InsuranceAbv NVARCHAR(255), 
    Secondary_InsuranceCat NVARCHAR(255), 
    Secondary_PayerRollUp NVARCHAR(255);
GO

-- Update Ref table with data from payer crosswalk
UPDATE r
SET r.Primary_InsuranceCat = pc.[Category - Type],
    r.Primary_InsuranceAbv = pc.InsuranceCatAbv,
	r.Primary_PayerRollUp = pc.[Payer Roll-Up]
FROM [DataCleanup].[dbo].[Ref] r
JOIN [DataCleanup].[dbo].[Payer Crosswalk] pc ON r.UpdatedPrimary = pc.[Insurance Product Detail];
GO

-- Update Ref table with data from payer crosswalk
UPDATE r
SET r.Secondary_InsuranceCat = pc.[Category - Type],
    r.Secondary_InsuranceAbv = pc.InsuranceCatAbv,
	r.Secondary_PayerRollUp = pc.[Payer Roll-Up]
FROM [DataCleanup].[dbo].[Ref] r
JOIN [DataCleanup].[dbo].[Payer Crosswalk] pc ON r.UpdatedSecondary = pc.[Insurance Product Detail];
GO

-- Add/recreate InsuranceAbv, InsuranceCat, PayerRollUp columns in DailyTransactions if needed
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='DailyTransactions' AND COLUMN_NAME='InsuranceAbv')
    ALTER TABLE DataCleanup.dbo.DailyTransactions
    DROP COLUMN InsuranceAbv, InsuranceCat, PayerRollUp;
    
ALTER TABLE DataCleanup.dbo.DailyTransactions
ADD InsuranceAbv NVARCHAR(255), 
    InsuranceCat NVARCHAR(255),
    PayerRollUp NVARCHAR(255);
GO

-- Update Ref table with data from payer crosswalk
UPDATE dt
SET dt.InsuranceCat = pc.[Category - Type],
    dt.InsuranceAbv = pc.InsuranceCatAbv,
	dt.PayerRollUp = pc.[Payer Roll-Up]
FROM DataCleanup.dbo.DailyTransactions dt
JOIN [DataCleanup].[dbo].[Payer Crosswalk] pc ON dt.PrimaryInsurance = pc.[Insurance Product Detail];
GO

