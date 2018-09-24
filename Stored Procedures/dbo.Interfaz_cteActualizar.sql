SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Responsable:		Roberto Amaya
-- Ultimo Cambio:	11/01/2018
-- Descrición:		Actualización de Usuarios
-- =============================================
CREATE PROCEDURE [dbo].[Interfaz_cteActualizar]
    @Usuario VARCHAR(10) ,
    @Grupo VARCHAR(50) ,
    @Cliente AS VARCHAR(10) ,
    @Sucursal AS INT ,
    @Nombre VARCHAR(255) ,
    @Direccion VARCHAR(100) ,
    @DireccionNumero VARCHAR(20) ,
    @DireccionNumeroInt VARCHAR(20) ,
    @EntreCalles VARCHAR(100) ,
    @Colonia VARCHAR(100) ,
    @Poblacion VARCHAR(100) ,
    @Estado VARCHAR(30) ,
    @Pais VARCHAR(30) ,
    @CodigoPostal VARCHAR(15) ,
    @Telefonos VARCHAR(100) ,
    @Extencion VARCHAR(10) ,
    @Fax VARCHAR(50) ,
    @Contacto VARCHAR(50) ,
    @Email VARCHAR(50)
AS
    BEGIN
        SET NOCOUNT ON;
        SET DATEFORMAT DMY
-- =============================================
-- Variables
-- =============================================
        DECLARE @UltimoId AS INT ,
            @iError AS INT ,
            @sDescripcion AS VARCHAR(MAX) ,
            @LogParametrosXML AS XML;
        SET @LogParametrosXML = ( SELECT    @Usuario AS 'sUsuario' ,
                                            @Grupo AS 'sGrupo' ,
                                            @Cliente AS 'sCliente' ,
                                            @Sucursal AS 'iSucursal' ,
                                            @Nombre AS 'sNombre' ,
                                            @Direccion AS 'sDireccion' ,
                                            @DireccionNumero AS 'sDireccionNumero' ,
                                            @DireccionNumeroInt AS 'sDireccionNumeroInt' ,
                                            @EntreCalles AS 'sEntreCalles' ,
                                            @Colonia AS 'sColonia' ,
                                            @Poblacion AS 'sPoblacion' ,
                                            @Estado AS 'sEstado' ,
                                            @Pais AS 'sPais' ,
                                            @CodigoPostal AS 'sCodigoPostal' ,
                                            @Telefonos AS 'sTelefonos' ,
                                            @Extencion AS 'sExtencion' ,
                                            @Fax AS 'sFax' ,
                                            @Contacto AS 'sContacto' ,
                                            @Email AS 'sEmail'
                                FOR
                                  XML PATH('Parametros')
                                );
        EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
            @Tipo = 'Inserción', -- varchar(255)
            @DetalleError = '', -- varchar(max)
            @Usuario = @Usuario, -- varchar(10)
            @Parametros = @LogParametrosXML; -- xml
-- =============================================
-- Validaciones
-- =============================================
        IF NOT EXISTS ( SELECT  u.Usuario
                        FROM    dbo.Usuario u
                        WHERE   RTRIM(LTRIM(u.Usuario)) = RTRIM(LTRIM(@Usuario)) )
            BEGIN
                SET @sDescripcion = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF NOT EXISTS ( SELECT  c.Cliente
                        FROM    dbo.Cte c
                        WHERE   c.Cliente = @Cliente )
            BEGIN
                SET @sDescripcion = 'No se encontró el cliente indicado. Favor de verificarlo.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Sucursal IS NULL
             OR @Sucursal < 0
           )
            BEGIN
                SET @sDescripcion = 'Sucursal no indicada. Por favor, indique una Sucursal.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Nombre IS NULL
             OR RTRIM(LTRIM(@Nombre)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Nombre no indicado. Por favor, indique un Nombre.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( LEN(@Nombre) > 100 )
            BEGIN
                SET @sDescripcion = 'Se supero la cantidad maxima de caracteres para el parametro Nombre. Por favor, indique un Nombre valido.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Direccion IS NULL
             OR RTRIM(LTRIM(@Direccion)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Dirección no indicada. Por favor, indique una Dirección.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @DireccionNumero IS NULL
             OR RTRIM(LTRIM(@DireccionNumero)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Número de Dirección no indicado. Por favor, indique un Número de Dirección.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Colonia IS NULL
             OR RTRIM(LTRIM(@Colonia)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Colonia no indicada. Por favor, indique una Colonia.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Poblacion IS NULL
             OR RTRIM(LTRIM(@Poblacion)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Población no indicada. Por favor, indique una Población.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Estado IS NULL
             OR RTRIM(LTRIM(@Estado)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Estado no indicado. Por favor, indique un Estado.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Pais IS NULL
             OR RTRIM(LTRIM(@Pais)) = ''
           )
            BEGIN
                SET @sDescripcion = 'País no indicado. Por favor, indique un País.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Pais IS NULL
             OR RTRIM(LTRIM(@Pais)) = ''
           )
            BEGIN
                SET @sDescripcion = 'País no indicado. Por favor, indique un País.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @CodigoPostal IS NULL
             OR RTRIM(LTRIM(@CodigoPostal)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Código Postal no indicado. Por favor, indique un Código Postal.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END
        IF ( @Grupo IS NULL
             OR RTRIM(LTRIM(@Grupo)) = ''
           )
            BEGIN
                SET @sDescripcion = 'Grupo no indicado. Por favor, indique su Grupo.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_CteActualizar', -- varchar(255)
                    @Tipo = 'Error de Validación', -- varchar(255)
                    @DetalleError = @sDescripcion, -- varchar(max)
                    @Usuario = @Usuario, -- varchar(10)
                    @Parametros = @LogParametrosXML; -- xml
                RAISERROR (@sDescripcion, 16, 1);
                RETURN;
            END

-- =============================================
-- Proceso
-- =============================================
        IF @Sucursal = 0 /*Se quiere actualizar Matríz*/
            BEGIN
                IF EXISTS ( SELECT  c.Grupo
                            FROM    dbo.Cte c
                            WHERE   c.Cliente = @Cliente
                                    AND c.Grupo = @Grupo )
                    BEGIN
                        UPDATE  dbo.Cte
                        SET     Nombre = @Nombre ,
                                Direccion = @Direccion ,
                                DireccionNumero = @DireccionNumero ,
                                DireccionNumeroInt = @DireccionNumeroInt ,
                                Colonia = @Colonia ,
                                Poblacion = @Poblacion ,
                                Estado = @Estado ,
                                Pais = @Pais ,
                                CodigoPostal = @CodigoPostal ,
                                Telefonos = @Telefonos ,
                                Fax = @Fax ,
                                Contacto1 = @Contacto ,
                                Extencion1 = @Extencion ,
                                eMail1 = @Email ,
                                Usuario = @Usuario
                        WHERE   Cliente = @Cliente;
                    END
                ELSE
                    BEGIN
                        SET @UltimoId = ( SELECT    ISNULL(MAX(cea.ID), 0) + 1
                                          FROM      dbo.CteEnviarA cea
                                          WHERE     cea.Cliente = @Cliente
                                        );
                        SET @Sucursal = @UltimoId;
                        INSERT  INTO dbo.CteEnviarA
                                ( Cliente ,
                                  ID ,
                                  Nombre ,
                                  Direccion ,
                                  EntreCalles ,
                                  Colonia ,
                                  Poblacion ,
                                  Estado ,
                                  Pais ,
                                  CodigoPostal ,
                                  Telefonos ,
                                  Fax ,
                                  PedirTono ,
                                  Contacto1 ,
                                  Extencion1 ,
                                  eMail1 ,
                                  Estatus ,
                                  Categoria ,
                                  Grupo ,
                                  Logico1 ,
                                  Logico2 ,
                                  Logico3 ,
                                  DireccionNumero ,
                                  DireccionNumeroInt
				                )
                        VALUES  ( @Cliente , -- Cliente - char(10)
                                  @UltimoId , -- ID - int
                                  @Nombre , -- Nombre - varchar(100)
                                  @Direccion , -- Direccion - varchar(100)
                                  @EntreCalles , -- EntreCalles - varchar(100)
                                  @Colonia , -- Colonia - varchar(100)
                                  @Poblacion , -- Poblacion - varchar(100)
                                  @Estado , -- Estado - varchar(30)
                                  @Pais , -- Pais - varchar(30)
                                  @CodigoPostal , -- CodigoPostal - varchar(15)
                                  @Telefonos , -- Telefonos - varchar(100)
                                  @Fax , -- Fax - varchar(50)
                                  0 , -- PedirTono - bit
                                  @Contacto , -- Contacto1 - varchar(50)
                                  @Extencion , -- Extencion1 - varchar(10)
                                  @Email , -- eMail1 - varchar(50)
                                  'ALTA' , -- Estatus - char(15)
                                  'CLIENTES' , -- Categoria - varchar(50)
                                  @Grupo , -- Grupo - varchar(50)
                                  0 , -- Logico1 - bit
                                  0 , -- Logico2 - bit
                                  0 , -- Logico3 - bit
                                  @DireccionNumero , -- DireccionNumero - varchar(20)
                                  @DireccionNumeroInt -- DireccionNumeroInt - varchar(20)
				                );
                    END
                    
            END
        ELSE
            BEGIN
				/*Se esta actualizando una Sucursal*/
                IF EXISTS ( SELECT  cea.Grupo
                            FROM    dbo.CteEnviarA cea
                            WHERE   cea.Cliente = @Cliente
                                    AND cea.ID = @Sucursal
                                    AND cea.Grupo = @Grupo )
                    BEGIN
                        UPDATE  dbo.CteEnviarA
                        SET     Nombre = @Nombre ,
                                Direccion = @Direccion ,
                                DireccionNumero = @DireccionNumero ,
                                DireccionNumeroInt = @DireccionNumeroInt ,
                                Colonia = @Colonia ,
                                Poblacion = @Poblacion ,
                                Estado = @Estado ,
                                Pais = @Pais ,
                                CodigoPostal = @CodigoPostal ,
                                Telefonos = @Telefonos ,
                                Fax = @Fax ,
                                Contacto1 = @Contacto ,
                                Extencion1 = @Extencion ,
                                eMail1 = @Email ,
                                EntreCalles = @EntreCalles
                        WHERE   Cliente = @Cliente
                                AND ID = @Sucursal
                    END
                ELSE
                    BEGIN
                        SET @UltimoId = ( SELECT    ISNULL(MAX(cea.ID), 0) + 1
                                          FROM      dbo.CteEnviarA cea
                                          WHERE     cea.Cliente = @Cliente
                                        );
                        SET @Sucursal = @UltimoId;
                        INSERT  INTO dbo.CteEnviarA
                                ( Cliente ,
                                  ID ,
                                  Nombre ,
                                  Direccion ,
                                  EntreCalles ,
                                  Colonia ,
                                  Poblacion ,
                                  Estado ,
                                  Pais ,
                                  CodigoPostal ,
                                  Telefonos ,
                                  Fax ,
                                  PedirTono ,
                                  Contacto1 ,
                                  Extencion1 ,
                                  eMail1 ,
                                  Estatus ,
                                  Categoria ,
                                  Grupo ,
                                  Logico1 ,
                                  Logico2 ,
                                  Logico3 ,
                                  DireccionNumero ,
                                  DireccionNumeroInt
				                )
                        VALUES  ( @Cliente , -- Cliente - char(10)
                                  @UltimoId , -- ID - int
                                  @Nombre , -- Nombre - varchar(100)
                                  @Direccion , -- Direccion - varchar(100)
                                  @EntreCalles , -- EntreCalles - varchar(100)
                                  @Colonia , -- Colonia - varchar(100)
                                  @Poblacion , -- Poblacion - varchar(100)
                                  @Estado , -- Estado - varchar(30)
                                  @Pais , -- Pais - varchar(30)
                                  @CodigoPostal , -- CodigoPostal - varchar(15)
                                  @Telefonos , -- Telefonos - varchar(100)
                                  @Fax , -- Fax - varchar(50)
                                  0 , -- PedirTono - bit
                                  @Contacto , -- Contacto1 - varchar(50)
                                  @Extencion , -- Extencion1 - varchar(10)
                                  @Email , -- eMail1 - varchar(50)
                                  'ALTA' , -- Estatus - char(15)
                                  'CLIENTES' , -- Categoria - varchar(50)
                                  @Grupo , -- Grupo - varchar(50)
                                  0 , -- Logico1 - bit
                                  0 , -- Logico2 - bit
                                  0 , -- Logico3 - bit
                                  @DireccionNumero , -- DireccionNumero - varchar(20)
                                  @DireccionNumeroInt -- DireccionNumeroInt - varchar(20)
				                );
                    END 
            END


		/* Se Agrega la cave de uso por default para Turismo*/
        IF NOT EXISTS ( SELECT  *
                        FROM    dbo.CteCFD
                        WHERE   Cliente = @Cliente )
            BEGIN
                INSERT  INTO dbo.CteCFD
                        ( Cliente, ClaveUsoCFDI )
                VALUES  ( @Cliente, -- Cliente - char(10)
                          'G03'  -- ClaveUsoCFDI - varchar(3)
                          );	
            END
        ELSE
            BEGIN
                UPDATE  CteCFD
                SET     ClaveUsoCFDI = 'G03'
                WHERE   Cliente = @Cliente;	
            END

-- =============================================
-- Información de Retorno
-- =============================================
        SELECT  c.Cliente ,
                ISNULL(cea.ID, 0) AS Sucursal ,
                ccfd.ClaveUsoCFDI
        FROM    dbo.Cte c
                LEFT JOIN dbo.CteEnviarA cea ON cea.Cliente = c.Cliente
                                                AND cea.ID = @Sucursal
                LEFT JOIN dbo.CteDireccionFiscal cdf ON cdf.Cliente = c.Cliente
                LEFT JOIN dbo.CteCFD ccfd ON ccfd.Cliente = c.Cliente
        WHERE   c.Cliente = @Cliente;
    END
GO
GRANT EXECUTE ON  [dbo].[Interfaz_cteActualizar] TO [Linked_Svam_Pruebas]
GO
