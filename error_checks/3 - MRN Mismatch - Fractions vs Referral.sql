-- Tests for mismatched MRN'S between fraction and referral tables

SELECT 
    f.[Patient ID1],
    f.[Patient Name],
    t2.[Patient ID],
    t2.[Patient Name]
FROM 
   DataCleanup.dbo.Fractions f
LEFT JOIN 
    DataCleanup.dbo.Ref t2 
ON 
    f.[Patient ID1] = t2.[Patient ID]
WHERE 
    t2.[Patient ID] IS NULL
ORDER BY f.[Patient ID1] ASC;
