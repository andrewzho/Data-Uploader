-- Tests for Mismatched MRN's between Transaction and Referral
-- Should only list the 40, 460, 6336 and SYN-100001 as the mismatched
-- If there's more do a manual check

SELECT 
	t1.PatientNumber,
    t1.PatientNumberUpdated,
	t1.AccountType,
    t1.InsuranceAbv,
    t1.InsuranceName,
    t1.PatientFullName,
    t2.[Patient ID],
    t2.[Patient Name],
    t2.State,
    t2.DOB,
    t2.[Primary Insurance],
    t2.[Secondary Insurance],
    t2.[Insurance Category]
FROM 
    DataCleanup.dbo.DailyTransactions t1
LEFT JOIN 
    DataCleanup.dbo.Ref t2 
ON 
    t1.PatientNumberUpdated = t2.[Patient ID]
WHERE 
    t2.[Patient ID] IS NULL
ORDER BY t1.PatientNumberUpdated ASC;

-- Tests for mismatches when MRN matches but first name doesn't
SELECT DISTINCT 
	p1.PatientNumberUpdated, 
	p1.FirstName AS FirstNameTransaction, 
	p1.PatientFullName AS FullNameTransaction,
	p2.FirstName AS FirstNameReferral,
	p2.[Patient Name] AS FullNameReferral
FROM DataCleanup.dbo.DailyTransactions p1
JOIN DataCleanup.dbo.Ref p2 ON p1.PatientNumberUpdated = p2.[Patient ID]
WHERE p1.FirstName != p2.FirstName
ORDER BY FirstNameTransaction ASC; -- Ensures each pair is considered only once


-- Tests for mismatched MRN'S betwen fraction and referral tables
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


-- Shows all matches
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

