SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[Interfaz_ValesInsertar]
	@Empresa CHAR(5),
	@FechaEmision SMALLDATETIME,
	@Usuario CHAR(10),
	@FechaOrigen SMALLDATETIME,
	@Observaciones VARCHAR(100),
	@Partidas VARCHAR(MAX) = NULL
AS
	SET NOCOUNT ON

-- *************************************************************************
--		Variables
-- *************************************************************************
	
	DECLARE @LogParametrosXml XML;
	SET @LogParametrosXml = 
		(
		SELECT
			@Empresa AS 'Empresa',
			@FechaEmision AS 'FechaEmision',
			@Usuario AS 'Usuario',
			@FechaOrigen AS 'FechaOrigen',
			@Observaciones AS 'Observaciones',
			@Partidas AS 'Partidas'
		FOR XML PATH('Parametros')
		);
	
	EXEC Interfaz_LogsInsertar 'Interfaz_ValesInsertar','Inserción','',@Usuario,@LogParametrosXml;
	
	DECLARE @mensajeError AS VARCHAR(MAX),
			@MensajeCompleto AS VARCHAR(MAX);
	
	DECLARE @RegresoID AS INT,
			@RegresoMovID AS VARCHAR(20);
	
	DECLARE @Error AS INT,
			@Cdigo AS INT,
			@Mensaje AS VARCHAR(512);
	
	DECLARE @Personal AS CHAR(10),
			@Importe AS MONEY,
			@Cantidad AS INT,
			@Referencia AS VARCHAR(50),
			@Beneficiario AS VARCHAR(100),
			@MovID AS CHAR(10);
	
	DECLARE @X_PARTIDAS AS TABLE
		(
		ID INT IDENTITY(1,1) NOT NULL,
		Personal CHAR(10),
		Importe MONEY,
		Cantidad INT,
		Referencia VARCHAR(20),
		Beneficiario VARCHAR(100)
		);
	
	DECLARE @XML XML;
	SET @XML = CAST(@Partidas AS XML);
	IF NOT @Partidas IS NULL
		BEGIN
			INSERT INTO @X_PARTIDAS
				SELECT
					T.Loc.value('@Personal','CHAR(10)') AS Personal,
					T.Loc.value('@Importe', 'MONEY') AS Importe,
					T.Loc.value('@Cantidad', 'INT') AS Cantidad,
					T.Loc.value('@Referencia', 'VARCHAR(50)') AS Referencia,
					T.Loc.value('@Beneficiario', 'VARCHAR(100)') AS Beneficiario
				FROM
					@XML.nodes('//row/fila') AS T(Loc);
		END


-- *************************************************************************
--		Validaciones
-- *************************************************************************
	
	IF (@Empresa IS NULL OR RTRIM(LTRIM(@Empresa)) = '')
		BEGIN
			SET @MensajeError = 'Empresa no indicada. Por favor, indique una Empresa.';
			EXEC Interfaz_LogsInsertar 'Interfaz_ValesInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                      
			RAISERROR(@MensajeError,16,1);                      
			RETURN; 
		END
	
	IF (@FechaEmision IS NULL)
		BEGIN
			SET @MensajeError = 'Fecha de emisión no indicada. Por favor, indique una Fecha de emisión.';
			EXEC Interfaz_LogsInsertar 'Interfaz_ValesInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                      
			RAISERROR(@MensajeError,16,1);                      
			RETURN; 
		END
	
	IF (@Usuario IS NULL OR RTRIM(LTRIM(@Usuario)) = '')
		BEGIN
			SET @MensajeError = 'Usuario no indicado. Por favor, indique un Usuario.';
			EXEC Interfaz_LogsInsertar 'Interfaz_ValesInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                      
			RAISERROR(@MensajeError,16,1);                      
			RETURN; 
		END
	
	IF NOT EXISTS(SELECT * FROM Usuario WHERE RTRIM(LTRIM(Usuario)) = RTRIM(LTRIM(@Usuario)))
		BEGIN
			SET @MensajeError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';
			EXEC Interfaz_LogsInsertar 'Interfaz_ValesInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                      
			RAISERROR(@MensajeError,16,1);                      
			RETURN; 
		END
	
	IF (@FechaOrigen IS NULL)
		BEGIN
			SET @MensajeError = 'Fecha Origen no indicada. Por favor, indique una fecha de origen.';
			EXEC Interfaz_LogsInsertar 'Interfaz_ValesInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                      
			RAISERROR(@MensajeError,16,1);                      
			RETURN; 
		END
	                     
-- *************************************************************************
--	Proceso
-- *************************************************************************
	INSERT INTO NOMINA
		(
		Empresa,
		Mov,
		FechaEmision,
		UltimoCambio,
		Concepto,
		Moneda,
		TipoCambio,
		Usuario,
		Observaciones,
		Estatus,
		Condicion,
		FechaOrigen 
		)
	VALUES
		(
		@Empresa,
		'Prestamo Inmediato',
		dbo.Fn_QuitarHrsMin(@FechaEmision),
		GETDATE(),
		'GASTOS NO COMPROBADOS',
		'Pesos',
		1,
		@Usuario,
		@Observaciones,
		'SINAFECTAR',
		'Prorratear',
		@FechaOrigen
		);
	
	SET @RegresoID = SCOPE_IDENTITY();
    
    INSERT INTO NOMINAD
		(
		ID,
		Renglon,
		Personal,
		Cuenta,
		Importe,
		Cantidad,
		Referencia,
		Beneficiario
		)
	SELECT
		ID = @RegresoID,
		Renglon  = 2048 * P.ID,
		Personal = P.Personal,
		'BANAMEX-51',
		Importe = P.Importe,
		Cantidad = P.Cantidad,
		Referencia = P.Referencia,
		Beneficiario = P.Beneficiario
	FROM
		@X_PARTIDAS AS P;

-- *************************************************************************
--	DATOS DE RETORNO
-- *************************************************************************
	
	SELECT
		ID = @RegresoID,
		MovID =(SELECT MovID FROM Nomina WHERE ID=@RegresoID)
		
	
GO
GRANT EXECUTE ON  [dbo].[Interfaz_ValesInsertar] TO [Linked_Svam_Pruebas]
GO
