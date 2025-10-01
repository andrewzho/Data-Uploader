-- Add the RemainingBalance column to the Ref table if it doesn't already exist
ALTER TABLE [DataCleanup].[dbo].[Ref]
DROP COLUMN RemainingBalance;
GO

ALTER TABLE [DataCleanup].[dbo].[Ref]
ADD RemainingBalance MONEY;
GO

-- Create a CTE to assign a row number to each referral for the same patient based on the Referral Date
-- Gets the Patient ID and Referral Date an orders by Referral Date.
WITH NumberedReferrals AS (
    SELECT
        rs.[Patient ID],
        rs.[Referral Date],
        ROW_NUMBER() OVER (PARTITION BY rs.[Patient ID] ORDER BY rs.[Referral Date]) AS ReferralOrder
    FROM 
        [DataCleanup].[dbo].[Ref] rs
)

-- Calculate the remaining balance for each referral period considering the referral date
-- Creates a new table by doing a Left Join on DailyTransactions and NumberedReferals. 
-- Creates a new Column of the sum of the remaining balances from Transactions
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
            (SELECT MIN(nr2.[Referral Date])
             FROM NumberedReferrals nr2
             WHERE nr2.[Patient ID] = nr.[Patient ID]
             AND nr2.[ReferralOrder] > nr.[ReferralOrder]), 
             '9999-12-31') -- Use a distant future date as the default end date
    GROUP BY
        nr.[Patient ID],
        nr.[Referral Date],
        nr.[ReferralOrder]
)

-- Update the Ref table with the calculated remaining balances
-- Uses the values from Calculated Balances and stores inot RemainingBalance in Referral.
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
