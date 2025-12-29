/*
================================================================================
SCRIPT 2: Extract First, Last, and Middle Names from Full Names
================================================================================

PURPOSE:
  This script parses full patient names into separate components for
  better data organization and reporting. Names are converted to uppercase
  and whitespace is trimmed.

EXECUTION ORDER:
  - Run after Script 1
  - Run before Scripts 3-5

WHAT THIS DOES:
  1. Splits DailyTransactions.PatientFullName into:
     - LastName, FirstName, MiddleName (from "LastName, FirstName MiddleName" format)
  2. Extracts FirstName from Ref.PatientName for referral tracking
  3. Normalizes all names to UPPERCASE and trims whitespace

ASSUMPTIONS:
  - Input format: "LastName, FirstName MiddleName" (from PatientFullName)
  - Alternative format: "FirstName LastName" (from PatientName in Ref)

================================================================================
*/

-- Step 1: Remove and recreate name columns in DailyTransactions
--         These columns will hold parsed names extracted from PatientFullName
--         Format of PatientFullName: "LastName, FirstName MiddleName"
ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
DROP COLUMN LastName, FirstName, MiddleName;
GO
ALTER TABLE [DataCleanup].[dbo].[DailyTransactions]
ADD LastName nvarchar(255),
FirstName nvarchar(255),
MiddleName nvarchar(255);
GO

-- Step 2: Extract LastName from PatientFullName
--         Logic: Take everything before the comma, uppercase it, and trim spaces
--         Example: "Smith, John Michael" -> "SMITH"
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET LastName = UPPER(LTRIM(RTRIM(LEFT(PatientFullName, CHARINDEX(',', PatientFullName) - 1))))
WHERE CHARINDEX(',', PatientFullName) > 0;

-- Step 3: Extract FirstName and MiddleName from PatientFullName
--         Logic: After the comma, first word is FirstName, remaining is MiddleName
--         Example: "Smith, John Michael" -> FirstName="JOHN", MiddleName="MICHAEL"
UPDATE [DataCleanup].[dbo].[DailyTransactions]
SET FirstName = UPPER(LTRIM(RTRIM(SUBSTRING(PatientFullName, CHARINDEX(',', PatientFullName) + 2, 
                           CHARINDEX(' ', LTRIM(RTRIM(SUBSTRING(PatientFullName, CHARINDEX(',', PatientFullName) + 2, LEN(PatientFullName)))) + ' ') - 1)))),
    MiddleName = UPPER(LTRIM(RTRIM(SUBSTRING(LTRIM(RTRIM(SUBSTRING(PatientFullName, CHARINDEX(',', PatientFullName) + 2, LEN(PatientFullName)))), 
                           CHARINDEX(' ', LTRIM(RTRIM(SUBSTRING(PatientFullName, CHARINDEX(',', PatientFullName) + 2, LEN(PatientFullName)))) + ' ') + 1, LEN(PatientFullName)))))
WHERE CHARINDEX(',', PatientFullName) > 0 AND CHARINDEX(' ', LTRIM(RTRIM(SUBSTRING(PatientFullName, CHARINDEX(',', PatientFullName) + 2, LEN(PatientFullName)))) + ' ') > 0;
GO

-- Step 4: Extract FirstName for Referral list (Ref table)
--         The Ref table has a different name format: "FirstName LastName"
--         We extract just the first word
ALTER TABLE [DataCleanup].[dbo].[Ref]
DROP COLUMN FirstName;
GO
ALTER TABLE [DataCleanup].[dbo].[Ref]
ADD FirstName NVARCHAR(255);
GO

-- Step 5: Populate FirstName in Ref table
--         Logic: Take the first word before the space, convert to uppercase
--         Example: "John Smith" -> "JOHN"
UPDATE [DataCleanup].[dbo].[Ref]
SET [FirstName] = UPPER(LTRIM(RTRIM(SUBSTRING([Patient Name], 1, CHARINDEX(' ', [Patient Name] + ' ') - 1))));

-- End of Script 2
-- Next: Run "3 - Getting RemainingBalance Ref.sql"

