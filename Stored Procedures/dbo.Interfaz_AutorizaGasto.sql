SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Responsable:		Roberto Amaya
-- Ultimo Cambio:	12/04/2018
-- Descripción:		Autoriza los movimientos de Gasto que no fueron afectados.
-- =============================================
CREATE PROCEDURE [dbo].[Interfaz_AutorizaGasto]
    @ID AS INT ,
    @USUARIO AS VARCHAR(20)
AS
    BEGIN        
        SET NOCOUNT ON        
 -- *************************************************************************        
 -- Variables        
 -- *************************************************************************                
     
        DECLARE @sMov AS VARCHAR(20) ,
            @sEstatus AS VARCHAR(15) ,
            @iError AS INT ,
            @sError AS VARCHAR(MAX);
        DECLARE @LogParametrosXml AS XML;        
        SET @LogParametrosXml = ( SELECT @ID AS 'ID', @USUARIO AS 'Usuario'
                                FOR
                                  XML PATH('Parametros')
                                );        

        EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_AutorizaGasto', @Tipo = 'Ejecución', @DetalleError = '',
            @Usuario = @Usuario, @Parametros = @LogParametrosXml; 
		

 -- *************************************************************************        
 -- Validaciones        
 -- ************************************************************************* 
        SELECT  @sMov = RTRIM(g.Mov) ,
                @sEstatus = RTRIM(g.Estatus)
        FROM    dbo.Gasto AS g
        WHERE   g.ID = @ID;
        PRINT 'El gasto ' + RTRIM(@ID) + ' ' + RTRIM(@sMov) + ' tiene estatus ' + RTRIM(@sEstatus);
        IF EXISTS ( SELECT  1
                    FROM    Gasto
                    WHERE   ID = @ID
                            AND Estatus IN ( 'SINAFECTAR' )
                            AND Mov IN ( 'SOLICITUD GASTO', 'Solicitud SIVE', 'Comprobante' ) )
            BEGIN        
     --VALIDAR USUARIO PARA AUTORIZAR
                IF EXISTS ( SELECT  1
                            FROM    MovSituacionUsuario
                            WHERE   ID = 9
                                    AND Usuario = @USUARIO )
                    AND @USUARIO <> 'SITTI'
                    BEGIN        
                        PRINT 'El Usuario que autoriza el gasto ' + RTRIM(@ID) + ' ' + RTRIM(@sMov) + ' es '
                            + RTRIM(@USUARIO);
                        BEGIN TRY
                            EXEC dbo.spAfectar @Modulo = 'GAS', @ID = @Id, @Accion = 'AUTORIZAR', @Base = 'Todo',
                                @GenerarMov = NULL, @Usuario = @USUARIO, @SincroFinal = NULL, @EnSilencio = 1,
                                @Ok = @iError OUTPUT, @OkRef = @sError OUTPUT;
                            SELECT  @sMov = RTRIM(g.Mov) ,
                                    @sEstatus = RTRIM(g.Estatus)
                            FROM    dbo.Gasto AS g
                            WHERE   g.ID = @ID;
                        END TRY
                        BEGIN CATCH
                            SELECT  @iError = ERROR_NUMBER() ,
                                    @sError = RTRIM(CONVERT(VARCHAR(20), @ID)) + '/' + '(SP ' + ISNULL(ERROR_MESSAGE(),
                                                                                                       '') + ', ln '
                                    + ISNULL(CAST(ERROR_LINE() AS VARCHAR), '') + ') ' + ISNULL(ERROR_MESSAGE(), '');

                            PRINT 'CATCH: ERROR_NUMBER ' + RTRIM(@iError) + ' ERROR_LINE ' + RTRIM(@sError);
                        END CATCH
                        IF ( SELECT RTRIM(g.Estatus)
                             FROM   dbo.Gasto g
                             WHERE  g.ID = @ID
                           ) = 'SINAFECTAR'
                            BEGIN
                                SET @sError = 'Ocurrio un error al aplicar el movimiento ' + RTRIM(CONVERT(VARCHAR, @ID))
                                    + ' / Error = ' + RTRIM(CAST(ISNULL(@iError, -1) AS VARCHAR(255))) + ', Mensaje = '
                                    + RTRIM(ISNULL(@sError, ''));
                                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_AutorizaGasto', 'Error', @sError, @Usuario,
                                    @LogParametrosXml;
                                RAISERROR(@sError, 16, 1);
                                RETURN;
                            END
                        IF ( SELECT RTRIM(ISNULL(g.Situacion, ''))
                             FROM   dbo.Gasto g
                             WHERE  g.ID = @ID
                           ) <> 'Autorizado'
                            BEGIN
                                PRINT 'El Gasto ' + RTRIM(@ID) + ' tiene situación diferente a Autorizado';
                                IF ( SELECT RTRIM(g.Estatus)
                                     FROM   dbo.Gasto g
                                     WHERE  g.ID = @ID
                                            AND g.Mov = 'Comprobante'
                                   ) = 'BORRADOR'
                                    BEGIN
                                        BEGIN TRY
                                            PRINT 'Cambiando situación de Gasto ' + RTRIM(@ID) + ' a Autorizado';	
                                            EXEC dbo.spCambiarSituacion @Modulo = 'GAS', @ID = @Id,
                                                @Situacion = 'Autorizado', @SituacionFecha = NULL, @Usuario = 'EYCRUZ',
                                                @SituacionUsuario = 'EYCRUZ', @SituacionNota = NULL;
                                        END TRY
                                        BEGIN CATCH
                                            SELECT  @iError = ERROR_NUMBER() ,
                                                    @sError = RTRIM(CONVERT(VARCHAR(20), @ID)) + '/' + '(SP '
                                                    + ISNULL(ERROR_MESSAGE(), '') + ', ln '
                                                    + ISNULL(CAST(ERROR_LINE() AS VARCHAR), '') + ') '
                                                    + ISNULL(ERROR_MESSAGE(), '');
                                            PRINT 'CATCH: ERROR_NUMBER ' + RTRIM(@iError) + ' ERROR_LINE '
                                                + RTRIM(@sError);
                                        END CATCH
                                        IF ( SELECT RTRIM(g.Situacion)
                                             FROM   dbo.Gasto g
                                             WHERE  g.ID = @ID
                                           ) <> 'Autorizado'
                                            BEGIN
                                                SET @sError = 'Ocurrio un error al cambiar la situación del movimiento '
                                                    + RTRIM(CONVERT(VARCHAR, @ID)) + ' / Error = '
                                                    + RTRIM(CAST(ISNULL(@iError, -1) AS VARCHAR(255))) + ', Mensaje = '
                                                    + RTRIM(ISNULL(@sError, ''));
                                                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_AutorizaGasto', 'Error', @sError,
                                                    @Usuario, @LogParametrosXml;
                                                RAISERROR(@sError, 16, 1);
                                                RETURN;
                                            END
                                    END

                                IF ( SELECT g.Estatus
                                     FROM   dbo.Gasto g
                                     WHERE  g.ID = @ID
                                            AND g.Mov <> 'Comprobante'
                                   ) = 'PENDIENTE'
                                    BEGIN
                                        BEGIN TRY
                                            PRINT 'Cambiando situación de Gasto ' + RTRIM(@ID) + ' a Autorizado';	
                                            EXEC dbo.spCambiarSituacion @Modulo = 'GAS', @ID = @Id,
                                                @Situacion = 'Autorizado', @SituacionFecha = NULL, @Usuario = 'EYCRUZ',
                                                @SituacionUsuario = 'EYCRUZ', @SituacionNota = NULL;
                                        END TRY
                                        BEGIN CATCH
                                            SELECT  @iError = ERROR_NUMBER() ,
                                                    @sError = RTRIM(CONVERT(VARCHAR(20), @ID)) + '/' + '(SP '
                                                    + ISNULL(ERROR_MESSAGE(), '') + ', ln '
                                                    + ISNULL(CAST(ERROR_LINE() AS VARCHAR), '') + ') '
                                                    + ISNULL(ERROR_MESSAGE(), '');
                                            PRINT 'CATCH: ERROR_NUMBER ' + RTRIM(@iError) + ' ERROR_LINE '
                                                + RTRIM(@sError);
                                        END CATCH
                                        IF ( SELECT RTRIM(g.Situacion)
                                             FROM   dbo.Gasto g
                                             WHERE  g.ID = @ID
                                           ) <> 'Autorizado'
                                            BEGIN
                                                SET @sError = 'Ocurrio un error al cambiar la situación del movimiento '
                                                    + RTRIM(CONVERT(VARCHAR, @ID)) + ' / Error = '
                                                    + RTRIM(CAST(ISNULL(@iError, -1) AS VARCHAR(255))) + ', Mensaje = '
                                                    + RTRIM(ISNULL(@sError, ''));
                                                
                                                EXEC dbo.Interfaz_LogsInsertar 'Interfaz_AutorizaGasto', 'Error', @sError,
                                                    @Usuario, @LogParametrosXml;
                                                RAISERROR(@sError, 16, 1);
                                                RETURN;
                                            END
                                    END
                            END
                    END        
                ELSE
                    BEGIN        
                        SET @sError = 'El usuario:' + @USUARIO
                            + ' no tiene los privilegios para autorizar el gasto'; 
                        EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_AutorizaGasto', -- varchar(255)
                            @Tipo = 'Error de Validación', -- varchar(255)
                            @DetalleError = @sError, -- varchar(max)
                            @Usuario = @Usuario, -- varchar(10)
                            @Parametros = @LogParametrosXml; -- xml       
                        RAISERROR(@sError,16,1);        
                        RETURN;        
                    END         
            END        
        ELSE
            BEGIN 
                SET @sError = 'El Movimiento ' + RTRIM(@sMov)
                    + ' está en un estatus diferente a SINAFECTAR, por favor verifique el estatus del movimiento';        
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_AutorizaGasto', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sError, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXml; -- xml         
                RAISERROR(@sError,16,1);        
                RETURN;        
            END        
 -- *************************************************************************        
 -- Información de Retorno        
 -- *************************************************************************           
  --    
        SELECT  g.ID ,
                g.Estatus
        FROM    dbo.Gasto g
        WHERE   g.ID = @ID;
    END
GO
GRANT EXECUTE ON  [dbo].[Interfaz_AutorizaGasto] TO [Linked_Svam_Pruebas]
GO
