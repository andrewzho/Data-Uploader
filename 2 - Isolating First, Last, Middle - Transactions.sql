-- Removing/Adding Last, First and Middle name Column 
ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
DROP COLUMN LastName, FirstName, MiddleName;
GO
ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
ADD LastName nvarchar(255),
FirstName nvarchar(255),
MiddleName nvarchar(255);
GO
-- Split FullName into LastName and convert to uppercase, trimming whitespace
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET LastName = UPPER(LTRIM(RTRIM(LEFT(PatientFullName, CHARINDEX(',', PatientFullName) - 1))))
WHERE CHARINDEX(',', PatientFullName) > 0;

-- Split the remaining FullName into FirstName and MiddleName and convert to uppercase, trimming whitespace
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET FirstName = UPPER(LTRIM(RTRIM(SUBSTRING(PatientFullName, CHARINDEX(',', PatientFullName) + 2, 
                           CHARINDEX(' ', LTRIM(RTRIM(SUBSTRING(PatientFullName, CHARINDEX(',', PatientFullName) + 2, LEN(PatientFullName)))) + ' ') - 1)))),
    MiddleName = UPPER(LTRIM(RTRIM(SUBSTRING(LTRIM(RTRIM(SUBSTRING(PatientFullName, CHARINDEX(',', PatientFullName) + 2, LEN(PatientFullName)))), 
                           CHARINDEX(' ', LTRIM(RTRIM(SUBSTRING(PatientFullName, CHARINDEX(',', PatientFullName) + 2, LEN(PatientFullName)))) + ' ') + 1, LEN(PatientFullName)))))
WHERE CHARINDEX(',', PatientFullName) > 0 AND CHARINDEX(' ', LTRIM(RTRIM(SUBSTRING(PatientFullName, CHARINDEX(',', PatientFullName) + 2, LEN(PatientFullName)))) + ' ') > 0;
GO

-- Isolating First Name for Referral List
ALTER TABLE [DataCleanup].[dbo].[Ref]
DROP COLUMN FirstName;
GO
ALTER TABLE [DataCleanup].[dbo].[Ref]
ADD FirstName NVARCHAR(255);
GO
-- Update FirstName with the first name in uppercase and trim whitespace
UPDATE [DataCleanup].[dbo].[Ref]
SET [FirstName] = UPPER(LTRIM(RTRIM(SUBSTRING([Patient Name], 1, CHARINDEX(' ', [Patient Name] + ' ') - 1))));

