-- Shows all matches between Fractions and Referral tables

WITH Matches AS (
    SELECT DISTINCT
        f.[Patient ID1],
        f.[Patient Name]
    FROM 
        DataCleanup.dbo.Fractions f
    WHERE 
        f.[Patient ID1] IN (
            SELECT 
                r.[Patient ID]
            FROM 
                DataCleanup.dbo.Ref r
        )
)
SELECT DISTINCT
    r.[Patient ID],
    r.[Patient Name],
    m.[Patient ID1],
    m.[Patient Name] AS MatchPatientName
FROM 
    DataCleanup.dbo.Ref r
RIGHT JOIN 
    Matches m
ON 
    r.[Patient ID] = m.[Patient ID1];
