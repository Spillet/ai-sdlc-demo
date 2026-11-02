-- Syntetická DB fiktivního e-shopu „Kompas“. Vygenerováno generator/generate_synthetic_db.py (seed 20261031).
-- Žádná reálná data ani schéma skutečné firmy.

CREATE PROCEDURE dbo.usp_Audit_Write
    @AuditLogId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    UPDATE dbo.AuditLog SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE AuditLogId = @AuditLogId;
END
GO

CREATE PROCEDURE dbo.usp_Error_Log
    @ErrorLogId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    INSERT INTO dbo.ErrorLog (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
END
GO

CREATE PROCEDURE dbo.usp_SysParam_Get
    @SysParamId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.SysParam WHERE SysParamId = @SysParamId;
END
GO

CREATE PROCEDURE dbo.usp_Counter_Next
    @CounterId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    UPDATE dbo.Counter SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE CounterId = @CounterId;
END
GO

CREATE PROCEDURE dbo.usp_JobRun_Start
    @JobRunId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    UPDATE dbo.JobRun SET Status = ISNULL(@Status, Status), ModifiedAt = GETDATE() WHERE JobRunId = @JobRunId;
END
GO

CREATE PROCEDURE dbo.usp_JobRun_End
    @JobRunId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    UPDATE jr SET jr.ModifiedAt = GETDATE()
    FROM dbo.JobRun jr
    INNER JOIN dbo.JobRun jr2 ON jr2.JobRunId = jr.JobRunId
    WHERE jr.JobRunId = @JobRunId;
END
GO

CREATE PROCEDURE dbo.usp_User_CheckPermission
    @UserPermissionId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT up.*, u.UserId AS UsersKey
    FROM dbo.UserPermission AS up WITH (NOLOCK)
    JOIN dbo.Users u ON u.UserId = up.UserId
    WHERE up.Status = 1;
    SELECT @cnt = COUNT(*) FROM dbo.Users WHERE UserId = @UserPermissionId;
END
GO

CREATE PROCEDURE dbo.usp_Translation_Get
    @TranslationId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Translation WHERE TranslationId = @TranslationId;
END
GO

CREATE PROCEDURE dbo.usp_User_Get
    @UserId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.Users WHERE UserId = @UserId;
END
GO

CREATE PROCEDURE dbo.usp_User_Save
    @UserPermissionId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    INSERT INTO dbo.UserPermission (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO dbo.Users (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
END
GO

CREATE PROCEDURE dbo.usp_SysParam_Set
    @SysParamId INT = NULL,
    @UserId INT = NULL,
    @Status TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    UPDATE sp SET sp.ModifiedAt = GETDATE()
    FROM dbo.SysParam sp
    INNER JOIN dbo.SysParam sp2 ON sp2.SysParamId = sp.SysParamId
    WHERE sp.SysParamId = @SysParamId;
END
GO

CREATE PROCEDURE dbo.usp_AuditLog_Purge
    @AuditLogId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cnt INT, @val DECIMAL(12,2), @rc INT;
    SELECT @cnt = COUNT(*) FROM dbo.SysParam WHERE SysParamId = @AuditLogId;
    INSERT INTO dbo.AuditLog (Status, CreatedAt, CreatedBy) VALUES (1, GETDATE(), @UserId);
    INSERT INTO Archive.dbo.AuditLog_Archive SELECT * FROM dbo.AuditLog WHERE CreatedAt < DATEADD(MONTH, -24, GETDATE());
END
GO
