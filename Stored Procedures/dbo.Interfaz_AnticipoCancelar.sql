SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[Interfaz_AnticipoCancelar]                              

	@IDIntelisis AS INT,
	@MovIdIntelisis AS VARCHAR(20),
	@Usuario AS CHAR(10)

AS
	SET NOCOUNT ON
-- *************************************************************************
--	Variables
-- *************************************************************************
	
	DECLARE @LogParametrosXml Xml;
	SET @LogParametrosXml =
		(
		SELECT
			@IdIntelisis AS 'ID',
			@MovIdIntelisis AS 'MovID',
			@Usuario AS 'Usuario'
		FOR XML PATH('Parametros'));
	
	EXEC Interfaz_LogsInsertar 'Interfaz_AnticipoCancelar', 'Inserción', '', @Usuario, @LogParametrosXml;
	
	DECLARE @MensajeError AS VARCHAR(MAX),
			@MensajeCompleto AS VARCHAR(MAX),
			@Error AS INT,
			@mensaje AS VARCHAR(512),
			@Anticipo AS INT;
	                          
-- *************************************************************************
--	Validaciones
-- *************************************************************************
	
	IF (@Usuario IS NULL OR RTRIM(LTRIM(@Usuario)) = '')
		BEGIN
			SET @MensajeError = 'Usuario no indicado. Por favor, indique un Usuario.';
			EXEC Interfaz_LogsInsertar 'Interfaz_AnticipoCancelar','Error de Validación', @MensajeError, @Usuario, @LogParametrosXml;
			RAISERROR(@MensajeError,16,1);
			RETURN;            
		END
	
	IF NOT EXISTS(SELECT * FROM Usuario WHERE RTRIM(LTRIM(Usuario)) = RTRIM(LTRIM(@Usuario)))
		BEGIN
			SET @MensajeError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';
			EXEC Interfaz_LogsInsertar 'Interfaz_AnticipoCancelar','Error de Validación', @MensajeError, @Usuario, @LogParametrosXml;
			RAISERROR(@MensajeError,16,1);
			RETURN;            
		END
	
-- *************************************************************************
--	Validaciones
-- *************************************************************************
	
	BEGIN TRY
		EXEC spAfectar 'CXC', @Anticipo, 'CANCELAR', 'Todo', NULL, @Usuario, NULL, 1, @Error OUTPUT, @Mensaje OUTPUT
	END TRY
	
	BEGIN CATCH
		 SELECT                                                                               
			@Error = ERROR_NUMBER(),
			@Mensaje = '(sp ' + ERROR_PROCEDURE() + ', ln ' + CAST(ERROR_LINE() AS VARCHAR) + ') ' + ERROR_MESSAGE();
	END CATCH
	
	--SET @MensajeCompleto = 'Error al aplicar el movimiento de Intelisis: ' + 
	--					'Error = ' + CAST(ISNULL(@Error,-1) AS VARCHAR(255)) + ', Mensaje = ' + ISNULL(@Mensaje, '') + 
	--					', el movimiento fue cancelado. Intente nuevamente.';
	--EXEC Interfaz_LogsInsertar 'Interfaz_cxcInsertar','Error Cancelar',@MensajeCompleto,@Usuario,@LogParametrosXml;
	--RAISERROR(@MensajeCompleto,16,1);
	--RETURN;
	
-- *************************************************************************
--		INFORMACION DE RETORNO
-- *************************************************************************
   
	SELECT
		A.ID,
		A.MovID,
		A.Estatus,
		A.Importe
	FROM
		CXC AS A
	WHERE
		A.ID = @IDIntelisis
GO
GRANT EXECUTE ON  [dbo].[Interfaz_AnticipoCancelar] TO [Linked_Svam_Pruebas]
GO
