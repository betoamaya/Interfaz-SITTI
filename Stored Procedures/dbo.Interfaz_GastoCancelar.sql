SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[Interfaz_GastoCancelar]
	@Usuario char(10),
	@Id int,
	@NumErr int = NULL OUTPUT,
	@Descripcion varchar(255) = NULL OUTPUT
AS
	SET NOCOUNT ON
	SET DATEFORMAT ymd

	-- ******************************************************
	--		VARIABLES
	-- ******************************************************

	DECLARE @LogParametrosXML xml;
	SET @LogParametrosXML =
		(
		SELECT
			@Usuario AS 'Usuario',
			@Id AS 'Id'
		FOR XML PATH('Parametros')
		);

	EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCancelar', 'Ejecución', '', @Usuario, @LogParametrosXML;

	DECLARE @MensajeError AS varchar(MAX),
		@Error AS int,
		@Mensaje AS varchar(512),
		@PathComprueba varchar(255);

	-- ******************************************************
	--		VALIDACIONES
	-- ******************************************************

	IF @Usuario <> 'SITTI'
		BEGIN
			SET @MensajeError = 'Usuario no valido. Por favor, indique un Usuario valido para la ejecución de este proceso.';
			SELECT @NumErr = 0, @Descripcion = @MensajeError;
			EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCancelar', 'Error de Validación', @MensajeError, @Usuario, @LogParametrosXML;
			RAISERROR(@MensajeError, 16, 1);
			RETURN;
		END

	IF @Id IS NULL OR @Id = 0
		BEGIN
			SET @MensajeError = 'Id de movimiento nulo o igual a cero. Por favor, indique un Id de movimiento valido para la ejecución de este proceso.';
			SELECT @NumErr = 0, @Descripcion = @MensajeError;
			EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCancelar', 'Error de Validación', @MensajeError, @Usuario, @LogParametrosXML;
			RAISERROR(@MensajeError, 16, 1);
			RETURN;
		END

	IF NOT EXISTS (SELECT * FROM dbo.Gasto g WHERE g.ID = @Id)
		BEGIN
			SET @MensajeError = 'El Id de movimiento indicado no es valido. El Id ' + RTRIM(CONVERT(varchar,@Id)) + ' no existe en Gasto, por favor indique Id valido.';
			SELECT @NumErr = 0, @Descripcion = @MensajeError;
			EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCancelar', 'Error de Validación', @MensajeError, @Usuario, @LogParametrosXML;
			RAISERROR(@MensajeError, 16, 1);
			RETURN;
		END

	
	-- ******************************************************
	--		Proceso
	-- ******************************************************

	BEGIN TRY
		EXEC dbo.spAfectar
			@Modulo = 'GAS',
			@ID = @Id,
			@Accion = 'CANCELAR',
			@Base = 'Todo',
			@GenerarMov = NULL,
			@Usuario = @Usuario,
			@SincroFinal = NULL,
			@EnSilencio = 1,
			@Ok = @Error OUTPUT,
			@OkRef = @Mensaje OUTPUT;
	END TRY

	BEGIN CATCH
		SELECT 
			@Error = ERROR_NUMBER(), 
			@Mensaje = RTRIM(CONVERT(varchar(20), @Id)) + '/' + '(SP ' + ISNULL(ERROR_MESSAGE(), '') + ', ln ' + ISNULL(CAST(ERROR_LINE() AS varchar),'') + ') ' + ISNULL(ERROR_MESSAGE(), '');
	END CATCH

	IF (SELECT g.Estatus FROM dbo.Gasto g WHERE g.ID = @ID) <> 'CANCELADO'
		BEGIN
			SET @MensajeError = 'Ocurrio un error al cancelar el movimiento / Error = ' + RTRIM(CAST(ISNULL(@Error, -1) AS varchar(255))) + ', Mensaje = ' + RTRIM(ISNULL(@Mensaje, ''));
			SELECT @NumErr = 0, @Descripcion = @MensajeError;
			EXEC dbo.Interfaz_LogsInsertar 'Interfaz_GastoCancelar', 'Error', @MensajeError, @Usuario, @LogParametrosXML;
			RAISERROR(@MensajeError, 16, 1);
			RETURN;
		END

	-- ******************************************************
	--		Parametros de Retorno
	-- ******************************************************

	SELECT @NumErr = 1, @Descripcion = 'El movimiento fue cancelado.';

	SELECT @NumErr AS 'NumErr', @Descripcion AS 'Descripcion';
GO
GRANT EXECUTE ON  [dbo].[Interfaz_GastoCancelar] TO [Linked_Svam_Pruebas]
GO
