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
