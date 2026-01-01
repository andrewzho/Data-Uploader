-- Payer Checker Based on Insurance Name

SELECT DISTINCT
    f.InsuranceAbv,
    f.PrimaryInsurance,
    t2.InsuranceCatAbv,
    t2.[Insurance Product Detail]
FROM 
   DataCleanup.dbo.[DailyTransactions] f
LEFT JOIN 
    DataCleanup.dbo.[Payer Crosswalk] t2 
ON 
    f.PrimaryInsurance = t2.[Insurance Product Detail]
WHERE 
    t2.[Insurance Product Detail] IS NULL AND
	f.PrimaryInsurance != 'Self-Pay'
ORDER BY f.InsuranceAbv ASC;

-- Payer Checker Based on Insurance Abv

SELECT DISTINCT
    f.InsuranceAbv,
    f.PrimaryInsurance,
    t2.InsuranceCatAbv,
    t2.[Insurance Product Detail]
FROM 
   DataCleanup.dbo.[DailyTransactions] f
LEFT JOIN 
    DataCleanup.dbo.[Payer Crosswalk] t2 
ON 
    f.InsuranceAbv = t2.InsuranceCatAbv
WHERE 
    t2.InsuranceCatAbv IS NULL AND
	f.PrimaryInsurance != 'Self-Pay'
ORDER BY f.InsuranceAbv ASC;