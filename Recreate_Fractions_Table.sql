/*
================================================================================
RECREATE FRACTIONS TABLE
================================================================================

PURPOSE:
  This script recreates the DataCleanup.dbo.Fractions table with the correct
  structure to match the Excel file format being uploaded.

EXECUTION:
  Run this script in SQL Server Management Studio (SSMS) or via your SQL execution tool
  before uploading Fractions data files.

WHAT THIS DOES:
  1. Drops the existing Fractions table (if it exists)
  2. Creates a new Fractions table with all required columns matching the Excel format
  3. Sets appropriate data types for each column

================================================================================
*/

USE DataCleanup;
GO

-- Step 1: Drop existing Fractions table if it exists
IF OBJECT_ID('DataCleanup.dbo.Fractions', 'U') IS NOT NULL
BEGIN
    DROP TABLE [DataCleanup].[dbo].[Fractions];
    PRINT 'Existing Fractions table dropped.';
END
GO

-- Step 2: Create Fractions table with the correct structure
--         This matches the Excel file format exactly
CREATE TABLE [DataCleanup].[dbo].[Fractions] (
    [ICD 10] NVARCHAR(255),
    [Activity Name] NVARCHAR(255),
    [Due Date] NVARCHAR(255),
    [Start Date] DATETIME,
    [Duration] NVARCHAR(255),
    [Note] NVARCHAR(MAX),
    [Status] NVARCHAR(255),
    [Prim# Oncologist] NVARCHAR(255),
    [Diagnosis] NVARCHAR(MAX),
    [Staff/Resource(s)] NVARCHAR(255),
    [Patient Name] NVARCHAR(255),
    [Patient ID1] NVARCHAR(255),
    [Created By] NVARCHAR(255),
    [Check-In] BIT,
    [Questionnaire] NVARCHAR(255),
    [Priority] NVARCHAR(255),
    [Checklist] NVARCHAR(255),
    [F1] NVARCHAR(255),
    [descr] NVARCHAR(255),
    [Cancer Flag] NVARCHAR(255),
    [ICD_High_level_Category] NVARCHAR(255),
    [ICD_Second_Level] NVARCHAR(255),
    [ICD_Detailed] NVARCHAR(255),
    [Start Date Only] DATE
);
GO

PRINT 'Fractions table created successfully with the correct structure.';
PRINT 'You can now upload Fractions Excel files.';
GO

