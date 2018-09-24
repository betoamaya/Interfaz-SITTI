SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================  
-- Responsable:				Roberto Amaya  
-- Fecha de Modificación:	04/04/2018
-- Descripción:				Búsqueda de Solicitudes de Gastos a comprobar
-- =============================================  
CREATE PROCEDURE [dbo].[Interfaz_SolicitudGastoBuscar]
 -- Add the parameters for the stored procedure here
    @Solicitud AS VARCHAR(20) ,
    @SolicitudID AS CHAR(10) ,
    @Usuario AS CHAR(10)
AS
    SET NOCOUNT ON
    SET DATEFORMAT YMD

 -- *************************************************************************
 -- Variables
 -- *************************************************************************

    DECLARE @LogParametrosXml AS XML;
    SET @LogParametrosXml = ( SELECT    @Solicitud AS 'Solicitud' ,
                                        @SolicitudID AS 'SolicitudID' ,
                                        @Usuario AS 'Usuario'
                            FOR
                              XML PATH('Parametros')
                            );
    EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_SolicitudGastoBuscar', -- varchar(255)
        @Tipo = 'Inserción', -- varchar(255)
        @DetalleError = '', -- varchar(max)
        @Usuario = @Usuario, -- varchar(10)
        @Parametros = @LogParametrosXml; -- xml

    DECLARE @sError AS VARCHAR(MAX) ,
        @Origen AS INT;
  
 -- *************************************************************************        
 -- Validaciones        
 -- *************************************************************************        
         
    IF ( RTRIM(ISNULL(@Usuario, '')) = '' )
        BEGIN        
            SET @sError = 'Usuario no indicado. Por favor, indique un Usuario.';
            EXEC Interfaz_LogsInsertar 'Interfaz_SolicitudGastoBuscar', 'Error de Validación', @sError, @Usuario,
                @LogParametrosXml;
            RAISERROR(@sError,16,1);
            RETURN;
        END
          
    IF NOT EXISTS ( SELECT  u.Usuario
                    FROM    dbo.Usuario AS u
                    WHERE   RTRIM(LTRIM(u.Usuario)) = RTRIM(LTRIM(@Usuario)) )
        BEGIN
            SET @sError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';
            EXEC Interfaz_LogsInsertar 'Interfaz_gastoInsertar', 'Error de Validación', @sError, @Usuario,
                @LogParametrosXml;
            RAISERROR(@sError,16,1);
            RETURN;
        END

	IF (RTRIM(ISNULL(@Solicitud,'')) <> 'Solicitud Gto a Comp')
	BEGIN
		SET @sError = 'Solicitud invalida. Por favor, indique una Solicitud valida.';
            EXEC Interfaz_LogsInsertar 'Interfaz_gastoInsertar', 'Error de Validación', @sError, @Usuario,
                @LogParametrosXml;
            RAISERROR(@sError,16,1);
            RETURN;
	END

	IF (RTRIM(ISNULL(@SolicitudID,'')) = '')
	BEGIN
		SET @sError = 'SolicitudID no indicado. Por favor, indique un SolicitudId.';
            EXEC Interfaz_LogsInsertar 'Interfaz_gastoInsertar', 'Error de Validación', @sError, @Usuario,
                @LogParametrosXml;
            RAISERROR(@sError,16,1);
            RETURN;
	END

 -- *************************************************************************        
 -- Información de Retorno        
 -- *************************************************************************       

    SET @Origen = CAST(@SolicitudID AS INT);

    SELECT  mf.DID AS 'ID' ,
            mf.DMov AS 'Mov' ,
            mf.DMovID AS 'MovID' ,
            g.Usuario AS 'Usuario' ,
            g.Importe AS 'Importe'
    FROM    dbo.Gasto AS g
            INNER JOIN dbo.MovFlujo AS mf ON mf.OID = g.ID
    WHERE   mf.OID = @Origen
            AND mf.OModulo = 'GAS';
GO
GRANT EXECUTE ON  [dbo].[Interfaz_SolicitudGastoBuscar] TO [Linked_Svam_Pruebas]
GO
