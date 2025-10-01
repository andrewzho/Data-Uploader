-- Add UpdatedPrimary and UpdatedSecondary columns to the Ref table if they don't already exist
ALTER TABLE [DataCleanup].[dbo].[Ref]
DROP COLUMN UpdatedPrimary, UpdatedSecondary;
GO

ALTER TABLE [DataCleanup].[dbo].[Ref]
ADD UpdatedPrimary NVARCHAR(255), 
	UpdatedSecondary NVARCHAR(255);
GO

ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
DROP COLUMN PrimaryInsurance, SecondaryInsurance;
GO

ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
ADD PrimaryInsurance NVARCHAR(255), 
	SecondaryInsurance NVARCHAR(255);
GO

ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
DROP COLUMN VisitNumber;
GO

ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
ADD VisitNumber NVARCHAR(255);
GO

ALTER TABLE [DataCleanup].[dbo].DenialData
DROP COLUMN VisitNumber;
GO

ALTER TABLE [DataCleanup].[dbo].DenialData
ADD VisitNumber NVARCHAR(255);
GO


-- Create a CTE to assign a row number to each referral for the same patient based on the Referral Date
WITH NumberedReferrals AS (
    SELECT
        rs.[Patient ID],
        rs.[Referral Date],
        ROW_NUMBER() OVER (PARTITION BY rs.[Patient ID] ORDER BY rs.[Referral Date]) AS ReferralOrder
    FROM 
        [DataCleanup].[dbo].[Ref] rs
)

-- Create a CTE to calculate the total units for each insurance used during the referral period
-- Gets the Sum of the totalunits per referral as well as a count of the number of times the insurance name was mentioned.
-- Ranks the data based upon Units First followed by Count 
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
        dt.[FromDOS] < ISNULL(
            (SELECT MIN(nr2.[Referral Date])
             FROM NumberedReferrals nr2
             WHERE nr2.[Patient ID] = nr.[Patient ID]
             AND nr2.[ReferralOrder] > nr.[ReferralOrder]), 
             '9999-12-31') -- Use a distant future date as the default end date
    GROUP BY
        nr.[Patient ID],
        nr.[Referral Date],
        dt.[InsuranceName]
)

-- Pivot the insurance units to get the top 2 insurances for each referral based on total units
, TopInsurances AS (
    SELECT
        iu.[Patient ID],
        iu.[Referral Date],
        COALESCE(MAX(CASE WHEN iu.InsuranceRank = 1 THEN iu.[InsuranceName] END), 'Self-Pay') AS UpdatedPrimary, -- ensure that the rank is 1 or the highest priority, and if there's none we set it to "Self-Pay"
        MIN(CASE WHEN iu.InsuranceRank >= 2 AND iu.InsuranceName IS NOT NULL THEN iu.[InsuranceName] END) AS UpdatedSecondary -- ensure the rank is 2 or greater ( in case of NULL being 2nd ) and make sure insurance name is not NULL.
    FROM 
        InsuranceUnits iu
    GROUP BY
        iu.[Patient ID],
        iu.[Referral Date]
)

-- Update the Ref table with the calculated insurances
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


ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
DROP COLUMN TransMRN
GO

ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
ADD TransMRN NVARCHAR(255);
GO

UPDATE dt
SET dt.TransMRN = dt.[PatientNumberUpdated] + '-' + dt.VisitNumber
FROM DataCleanup.dbo.[DailyTransactions] dt ;

ALTER TABLE DataCleanup.dbo.Ref
DROP COLUMN Primary_InsuranceAbv, Primary_InsuranceCat, Primary_PayerRollUp,
	Secondary_InsuranceAbv, Secondary_InsuranceCat, Secondary_PayerRollUp
GO

ALTER TABLE DataCleanup.dbo.Ref
ADD Primary_InsuranceAbv NVARCHAR(255), Primary_InsuranceCat NVARCHAR(255), Primary_PayerRollUp NVARCHAR(255),
	Secondary_InsuranceAbv NVARCHAR(255), Secondary_InsuranceCat NVARCHAR(255), Secondary_PayerRollUp NVARCHAR(255);
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

ALTER TABLE DataCleanup.dbo.DailyTransactions
DROP COLUMN InsuranceAbv, InsuranceCat, PayerRollUp;
GO

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

