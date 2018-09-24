SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE Procedure [dbo].[Interfaz_ProvedorPorID] --'SITTI'
	@Usuario AS CHAR(10),
	@Proveedor AS CHAR(10)
AS

-- *************************************************************************
-- Variables
-- *************************************************************************

	DECLARE @LogParametrosXml XML;
	SET @LogParametrosXml =
		(
		SELECT
			@Usuario AS 'Usuario',
			@Proveedor AS 'Proveedor'
		FOR XML PATH('Parametros')
		);
	
	EXEC Interfaz_LogsInsertar 'Interfaz_ProvedorPorID', 'Consulta', '', @Usuario, @LogParametrosXml;
	
	DECLARE @MensajeError VARCHAR(MAX);
	
-- *************************************************************************
--		Validaciones
-- *************************************************************************

	IF (@Usuario IS NULL OR RTRIM(LTRIM(@Usuario)) = '')
		BEGIN
			SET @MensajeError = 'Usuario no indicado. Por favor, indique un Usuario.';
			EXEC Interfaz_LogsInsertar 'Interfaz_ProvedorPorID', 'Error de Validación', '', @Usuario, @LogParametrosXml;
			RAISERROR(@MensajeError,16,1);
			RETURN;
		END
	
	IF NOT EXISTS( SELECT * FROM Usuario WHERE RTRIM(LTRIM(Usuario)) = RTRIM(LTRIM(@Usuario)) )
		BEGIN
			SET @MensajeError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';
			EXEC Interfaz_LogsInsertar 'Interfaz_ProvedorPorID', 'Error de Validación', '', @Usuario, @LogParametrosXml;
			RAISERROR(@MensajeError,16,1);
			RETURN;
		END
		
-- *************************************************************************
--		Proceso
-- *************************************************************************

-- *************************************************************************
--		Información de Retorno
-- *************************************************************************
	
	SELECT
		A.Proveedor,
		A.Rama,
		A.Nombre,
		A.Estatus
	FROM
		prov AS A
	WHERE
		A.Proveedor = @Proveedor AND A.Estatus = 'Alta'
	ORDER BY
		A.Nombre;
GO
GRANT EXECUTE ON  [dbo].[Interfaz_ProvedorPorID] TO [Linked_Svam_Pruebas]
GO
