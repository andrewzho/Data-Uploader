/*
================================================================================
SCRIPT 3: Calculate Outstanding Balances for Each Referral Period
================================================================================

PURPOSE:
  This script associates transaction balances with referral records by:
  - Matching each referral to transactions within its period
  - Calculating the total outstanding balance per referral
  - Storing the result in the Ref table

EXECUTION ORDER:
  - Run after Scripts 1-2
  - Run before Scripts 4-5

KEY CONCEPT:
  Each patient may have multiple referrals over time. For each referral,
  we sum up all financial balances from transactions that occurred:
  - On or after the referral date (FromDOS >= Referral Date)
  - Before the next referral's date (or indefinitely if no next referral)
  
  This shows the outstanding financial obligations for each clinical episode.

================================================================================
*/

-- Step 1: Initialize the RemainingBalance column in Ref table
--         This column will hold the total balance for each referral period
ALTER TABLE [DataCleanup].[dbo].[Ref]
DROP COLUMN RemainingBalance;
GO

ALTER TABLE [DataCleanup].[dbo].[Ref]
ADD RemainingBalance MONEY;
GO

-- Step 2: Create a Common Table Expression (CTE) to number referrals per patient
--         This allows us to identify which referral comes first, second, etc.
--         for each patient
-- IMPORTANT: This ordering is based on Referral Date
WITH NumberedReferrals AS (
    SELECT
        rs.[Patient ID],
        rs.[Referral Date],
        ROW_NUMBER() OVER (PARTITION BY rs.[Patient ID] ORDER BY rs.[Referral Date]) AS ReferralOrder
    FROM 
        [DataCleanup].[dbo].[Ref] rs
)

-- Step 3: Calculate the total remaining balance for each referral
--         Logic:
--           1. For each referral, find all transactions where:
--              - The Patient ID matches (rs.[Patient ID] = dt.[PatientNumberUpdated])
--              - The transaction date is ON or AFTER the referral date
--              - The transaction date is BEFORE the next referral (or indefinitely)
--           2. Sum the RemainingBalance from all matching transactions
--           3. Use ISNULL to return 0 if no transactions are found
, CalculatedBalances AS (
    SELECT
        nr.[Patient ID],
        nr.[Referral Date],
        nr.[ReferralOrder],
        ISNULL(SUM(dt.RemainingBalance), 0) AS TotalRemainingBalance
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
            -- Subquery: Find the date of the NEXT referral for this patient
            -- If there is no next referral, use '9999-12-31' (a distant future date)
            (SELECT MIN(nr2.[Referral Date])
             FROM NumberedReferrals nr2
             WHERE nr2.[Patient ID] = nr.[Patient ID]
             AND nr2.[ReferralOrder] > nr.[ReferralOrder]), 
             '9999-12-31')
    GROUP BY
        nr.[Patient ID],
        nr.[Referral Date],
        nr.[ReferralOrder]
)

-- Step 4: Update the Ref table with calculated balances
--         Match each referral record to its calculated balance and store the result
UPDATE rs
SET rs.RemainingBalance = cb.TotalRemainingBalance
FROM 
    [DataCleanup].[dbo].[Ref] rs
JOIN 
    CalculatedBalances cb
ON 
    rs.[Patient ID] = cb.[Patient ID]
AND 
    rs.[Referral Date] = cb.[Referral Date];
GO

-- End of Script 3
-- Next: Run "4 - Primary Secondary Insurance-NYPC-L1484.sql"
