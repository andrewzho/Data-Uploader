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
ORDER BY FirstNameTransaction ASC;
