SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[Interfaz_DepositosCancelar]
	@IDDeposito AS int,
	@Usuario AS char(10)
AS
BEGIN
	Declare @Error AS int,
		@mensaje AS varchar(512),
		@MensajeCompleto AS varchar(MAX);
	Declare @LogParametrosXml Xml;
	Set @LogParametrosXml =
		(SELECT
			 @IDDeposito AS 'IDDeposito',
			 @Usuario AS 'Usuario'
		For Xml Path('Parametros'));

	Exec Interfaz_LogsInsertar 'Interfaz_DepositosCancelar','Ejecución', '' , @Usuario, @LogParametrosXml;

	BEGIN TRY
    	EXEC spAfectar 'DIN', @IdDeposito, 'CANCELAR', 'Todo', NULL, @Usuario, NULL, 1, @Error OUTPUT, @Mensaje OUTPUT;
    END TRY
    BEGIN CATCH
    	SELECT @Error  = ERROR_NUMBER(),
			@Mensaje = '(sp ' + Isnull(ERROR_PROCEDURE(),'') + ', ln ' + Isnull(Cast(ERROR_LINE() as varchar),'') + ') ' + Isnull(ERROR_MESSAGE(),'');
    END CATCH
	
	IF (SELECT d.Estatus FROM dbo.Dinero d WHERE d.ID = @IDDeposito) <> 'CANCELADO'
		BEGIN
			SET @MensajeCompleto = 'Error al cancelar el movimiento de depósito de Intelisis: ' +
				'Error = ' + Cast(IsNull(@Error,-1) as varchar(255)) + ', Mensaje = ' + IsNull(@Mensaje, '');
			Exec Interfaz_LogsInsertar 'Interfaz_DepositosCancelar', 'Error',@MensajeCompleto, @Usuario, @LogParametrosXml;
			RAISERROR(@MensajeCompleto, 16, 1);
			RETURN;
		END
END
GO
GRANT EXECUTE ON  [dbo].[Interfaz_DepositosCancelar] TO [Linked_Svam_Pruebas]
GO
