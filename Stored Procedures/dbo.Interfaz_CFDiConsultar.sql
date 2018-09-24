SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Responsable:		Roberto Amaya
-- Ultimo Cambio:	18/05/2018
-- Descripción:		Consultar CFDi
-- =============================================
CREATE PROCEDURE [dbo].[Interfaz_CFDiConsultar]
    @Empresa CHAR(5) ,
    @MovID CHAR(20) ,
    @Usuario CHAR(10)
AS
    BEGIN
        SET NOCOUNT ON
-- *************************************************************************
--	Variables
-- *************************************************************************
	
        DECLARE @LogParametrosXml AS XML ,
            @sError AS VARCHAR(MAX) ,
            @iError AS INT;
        SET @LogParametrosXml = ( SELECT    @Empresa AS 'Empresa' ,
                                            @MovID AS 'MovID' ,
                                            @Usuario AS 'Usuario'
                                FOR
                                  XML PATH('Parametros')
                                );
	
        EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CFDiConsultar', @Tipo = 'Ejecución', @DetalleError = '',
            @Usuario = @Usuario, @Parametros = @LogParametrosXml;

-- *************************************************************************
--	Consulta
-- *************************************************************************
        IF RTRIM(@Usuario) IN ( 'SITTI' )
            BEGIN
                SELECT  c.ModuloID AS ID ,
                        c.MovID ,
                        CASE WHEN c.Modulo = 'VTAS' THEN ( SELECT   v.Estatus
                                                           FROM     dbo.Venta AS v
                                                           WHERE    v.ID = c.ModuloID
                                                         )
                             WHEN c.Modulo = 'CXC' THEN ( SELECT    c2.Estatus
                                                          FROM      dbo.Cxc c2
                                                          WHERE     c2.ID = c.ModuloID
                                                        )
                        END AS 'Estatus' ,
                        CASE WHEN c.Modulo = 'VTAS' THEN ( SELECT   v1.CFDFlexEstatus
                                                           FROM     dbo.Venta AS v1
                                                           WHERE    v1.ID = c.ModuloID
                                                         )
                             WHEN c.Modulo = 'CXC' THEN ( SELECT    c3.CFDFlexEstatus
                                                          FROM      dbo.Cxc c3
                                                          WHERE     c3.ID = c.ModuloID
                                                        )
                        END AS 'CFDFlexEstatus' ,
                        CAST(c.Documento AS VARCHAR(MAX)) AS CFDXML ,
                        c.noCertificado ,
                        c.Sello ,
                        c.SelloSAT ,
                        c.TFDCadenaOriginal ,
                        c.UUID ,
                        c.FechaTimbrado ,
                        c.noCertificadoSAT
                FROM    dbo.CFD AS c
                WHERE   c.Empresa = @Empresa
                        AND c.MovID = @MovID;
            END
        ELSE
            BEGIN
                SET @sError = 'Usuario Invalido. Ingrese Usuario valido'
                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_CFDiConsultar', @Tipo = 'Error', @DetalleError = @sError,
                    @Usuario = @Usuario, @Parametros = @LogParametrosXml; 
                RAISERROR(@sError,16,1);
                RETURN;
            END
    END
GO
