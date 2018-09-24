SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE Procedure [dbo].[Interfaz_proveedoresConsultar] --'SITTI'
	@Usuario AS CHAR(10),
	@Rama AS VARCHAR(30) = NULL
AS
	
-- *************************************************************************
--		Variables
-- *************************************************************************
	
	DECLARE @LogParametrosXml XML;
	SET @LogParametrosXml = 
		(
		SELECT
			@Usuario AS 'Usuario',
			ISNULL(@Rama,'') AS 'Rama'
		FOR XML PATH('Parametros')
		);
	
	--EXEC Interfaz_LogsInsertar 'Interfaz_ProveedoresConsultar', 'Consulta', '', @Usuario, @LogParametrosXml;
	
	DECLARE @MensajeError AS VARCHAR(MAX);

-- *************************************************************************
--		Validaciones
-- *************************************************************************

	IF (@Usuario IS NULL OR RTRIM(LTRIM(@Usuario)) = '')
		BEGIN
			SET @MensajeError = 'Usuario no indicado. Por favor, indique un Usuario.';
			EXEC Interfaz_LogsInsertar 'Interfaz_ProveedoresConsultar', 'Error de Validación', '', @Usuario, @LogParametrosXml;
			RAISERROR(@MensajeError,16,1);
			RETURN;
		END
	
	IF NOT EXISTS( SELECT * FROM Usuario WHERE RTRIM(LTRIM(Usuario)) = RTRIM(LTRIM(@Usuario)) )
		BEGIN
			SET @MensajeError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';
			EXEC Interfaz_LogsInsertar 'Interfaz_ProveedoresConsultar', 'Error de Validación', '', @Usuario, @LogParametrosXml;
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
		Prov AS A
	WHERE
		(@Rama IS NULL OR A.Rama = @Rama) AND A.Estatus = 'Alta'
	ORDER BY
		A.Nombre;
GO
GRANT EXECUTE ON  [dbo].[Interfaz_proveedoresConsultar] TO [Linked_Svam_Pruebas]
GO
