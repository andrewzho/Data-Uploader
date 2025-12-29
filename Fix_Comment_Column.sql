-- Fix Comment column size in DataCleanup.dbo.Ref table
-- This script alters the Comment column to allow longer text values

USE DataCleanup;
GO

-- Alter the Comment column to NVARCHAR(MAX) to accommodate longer comments
ALTER TABLE [DataCleanup].[dbo].[Ref]
ALTER COLUMN [Comment] NVARCHAR(MAX);
GO

PRINT 'Comment column has been updated to NVARCHAR(MAX)';
GO

