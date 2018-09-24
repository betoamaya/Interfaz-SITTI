SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[Interfaz_ventasInsertar_Test]
    @Empresa AS CHAR(5),
    @Mov AS CHAR(20),
    @FechaEmision AS SMALLDATETIME,
    @Concepto AS VARCHAR(50),
    @Moneda AS CHAR(10),
    @TipoCambio AS FLOAT,
    @Usuario AS CHAR(10),
    @Referencia AS VARCHAR(50),
    @Cliente AS CHAR(10),
    @Sucursal AS INT,
    @Vencimiento AS SMALLDATETIME,
    @Importe AS MONEY,
    @Impuestos AS MONEY,
    @CentroDeCostos AS VARCHAR(20),
    @TipoPago AS VARCHAR(50),
    @Observaciones AS VARCHAR(100),
    @Comentarios AS VARCHAR(MAX),
    --@PartidasVtas VARCHAR(MAX) = NULL,
    @ID AS INT = NULL OUTPUT,
    @MovID AS VARCHAR(MAX) = NULL OUTPUT,
    @CFDXml AS VARCHAR(MAX) = NULL OUTPUT,
    @noCertificado AS VARCHAR(MAX) = NULL OUTPUT,
    @Sello AS VARCHAR(MAX) = NULL OUTPUT,
    @SelloSAT AS VARCHAR(MAX) = NULL OUTPUT,
    @TFDCadenaOriginal VARCHAR(MAX) = NULL OUTPUT,
    @UUID AS VARCHAR(MAX) = NULL OUTPUT,
    @FechaTimbrado AS VARCHAR(MAX) = NULL OUTPUT,
    @noCertificadoSAT AS VARCHAR(MAX) = NULL OUTPUT,
	@PartidasVtas VARCHAR(MAX) = NULL
    
AS
    SET NOCOUNT ON
    
    --********************************************************************
    --        VARIABLES 
    --********************************************************************

    -- Se crea y se genera Xml con los parametros para tabla Interfaz_Logs
    DECLARE @LogParametrosXml XML;
    SET @LogParametrosXml =
        (
        SELECT
            @Empresa AS 'Empresa',
            @Mov AS 'Mov',
            @FechaEmision AS 'FechaEmision',
            @Concepto AS 'Concepto',
            @Moneda AS 'Moneda',
            @TipoCambio AS 'TipoCambio',
            @Usuario AS 'Usuario',
            @Referencia AS 'Referencia',
            @Cliente AS 'Cliente',
            @Sucursal AS 'Sucursal',
            @Vencimiento AS 'Vencimiento',
            @Importe AS 'Importe',
            @Impuestos AS 'Impuestos',
            @CentroDeCostos AS 'CentroDeCostos',
            @TipoPago AS 'TipoPago',
            @Observaciones AS 'Observaciones',
            @Comentarios AS 'Comentarios',
            @PartidasVtas AS 'Comentarios'
        FOR XML PATH('Parametros')
        );
    
    -- Se carga Interfaz_Logs
    EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar', 'Inserción', '', @Usuario, @LogParametrosXml;
    
    -- VARIBLES PARA MENSAJES DE ERROR
    DECLARE @MensajeError AS VARCHAR(MAX),
            @MensajeCompleto AS VARCHAR(MAX),
            @Error AS INT,
            @Codigo AS INT,
            @Mensaje AS VARCHAR(512);
    
    
    -- VARIABLES DE REGRESO
    DECLARE @RegresoID AS INT,
            @RegresoMovID AS VARCHAR(20),
            @RegresoXml AS XML,
            @RegresoFechaAprobacion AS DATETIME,
            @RegresoSerie AS VARCHAR(50),
            @RegresoFolio AS INT,
            @MovIdCFD AS VARCHAR(30),
            @CadenaSal AS VARCHAR(255),
            @SelloSal AS VARCHAR(255),
            @noCertificadoSal AS VARCHAR(30),
            @FechaAutorizacionSal AS DATETIME;
    
    -- VARIABLES DE LOS MOVIMIENTOS
    DECLARE @DescripcionExtra AS VARCHAR(255),
            @TasaImpuesto AS MONEY,
            @Almacen AS CHAR(10),
            @Articulo AS VARCHAR(20),
            @Condicion AS VARCHAR(20),
            @Impuesto1 AS FLOAT;

    DECLARE @T_PartidasVtas Table
        (
            Consecutivo INT IDENTITY (1,1) NOT NULL,
            Articulo VARCHAR(20),
            Precio MONEY,
            TasaImpuesto MONEY
        )
            
    DECLARE @X_PartidasVtas XML
    SET @X_PartidasVtas = CAST(@PartidasVtas AS XML)

/* OJO CONDICIONES */

    SELECT @Condicion = 'Credito';

    IF @PartidasVtas IS NULL
        BEGIN
            IF @Mov IN ('CFD sin Viaje', 'CFD FactViaCredito')
                BEGIN
                    INSERT INTO @T_PartidasVtas 
                        (Articulo, Precio, TasaImpuesto)
                    VALUES
                        ('RENTA UNIDADES', @Importe, 0);
                END
            ELSE
                BEGIN
                    IF @Mov IN ('FACT.VE.GRAVADO', 'CFDI SIN VIAJE GRAV', 'Ing.CFDI Ant.Gravado', 'Factura TranspInd', 'Fact Otros Ing Cont')
                        BEGIN
                            INSERT INTO @T_PartidasVtas
                                (Articulo, Precio, TasaImpuesto)
                            VALUES
                                ('V.ESP.GRAVADO', @Importe, 16);
                        END
                    ELSE
                        BEGIN
                            SET @MensajeError = 'Partidas no indicadas. Por favor, indique las partidas del movimiento de Venta';
                            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar', 'Error de Validación', '', @Usuario, @LogParametrosXml;
                            RAISERROR(@MensajeError,16,1);
                            RETURN;
                        END
                END
        END
    ELSE
        BEGIN
            INSERT INTO @T_PartidasVtas
                SELECT
                    T.LOC.value('@Articulo', 'VARCHAR(20)') AS ARTICULO,  ---- SECOPA-10,SECOPA-15 RENTA UNIDADES
                    T.LOC.value('@Precio', 'MONEY') AS Precio,
                    T.LOC.value('@TasaImpuesto', 'MONEY') AS TasaImpuesto  --Tasa 11,16,0
                FROM
                    @X_PartidasVtas.nodes('//row/fila') AS T(LOC);
        END

    /*
    
    IF @Mov IN ('CFD sin Viaje', 'CFD FactViaCredito')
        BEGIN
            SELECT 
                @Articulo = 'RENTA UNIDADES',
                @Condicion = 'Credito',
                @Impuesto1 = 0;
        END
    ELSE
        BEGIN
            IF @Mov IN ('FACT.VE.GRAVADO', 'CFDI SIN VIAJE GRAV', 'Ing.CFDI Ant.Gravado')
                BEGIN
                    SELECT 
                        @Articulo = 'V.ESP.GRAVADO',
                        @Condicion = 'Credito',
                        @Impuesto1 = 16,
                        @TasaImpuesto=16;
                END
        END
    
    */

    -- *************************************************************************
    --        Validaciones
    -- *************************************************************************
    
    IF (@Empresa IS NULL OR RTRIM(LTRIM(@Empresa)) = '')
        BEGIN
            SET @MensajeError = 'Empresa no indicada. Por favor, indique una Empresa';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar', 'Error de Validación', '', @Usuario, @LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
    
    IF (@Empresa = 'TUN')
        BEGIN
            SET @Almacen = 'TUN_VE'
        END
    ELSE
        BEGIN
            IF (@Empresa = 'TSL')
                BEGIN
                    SET @Almacen = 'TSL_VE'
                END    
        END
    
    IF(@Mov IS NULL OR RTRIM(LTRIM(@Mov)) = '')
        BEGIN
            SET @MensajeError = 'Movimiento no indicado. Por favor, indique un Movimiento.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar', 'Error de Validación', '', @Usuario, @LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
        
    IF (@FechaEmision IS NULL)
        BEGIN
            SET @MensajeError = 'Fecha de emisión no indicada. Por favor, indique una Fecha de emisión.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
    
    IF (@Concepto IS NULL OR RTRIM(LTRIM(@Concepto)) = '')
        BEGIN
            SET @MensajeError = 'Concepto no indicado. Por favor, indique un Concepto.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
    
    IF (@Moneda IS NULL OR RTRIM(LTRIM(@Moneda)) = '')
        BEGIN
            SET @MensajeError = 'Moneda no indicada. Por favor, indique una Moneda.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
    
    IF (RTRIM(LTRIM(@Moneda)) <> 'Pesos' AND RTRIM(LTRIM(@Moneda)) <> 'Dolares')
        BEGIN
            SET @MensajeError = 'La Moneda indicada no es ni "Pesos" ni "Dolares" (Moneda indicada "'+ rtrim(ltrim(@Moneda)) + 
                                '"). Por favor, indique una Moneda valida.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
    
    IF (@TipoCambio IS NULL OR @TipoCambio <= 0)
        BEGIN
            SET @MensajeError = 'Tipo de cambio no indicado o menor o igual que cero. Por favor, indique un Tipo de cambio mayor que cero.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
        
    IF (@Usuario IS NULL OR RTRIM(LTRIM(@Usuario)) = '')
        BEGIN
            SET @MensajeError = 'Tipo de cambio no indicado o menor o igual que cero. Por favor, indique un Tipo de cambio mayor que cero.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
    
    IF NOT EXISTS (SELECT * FROM Usuario WHERE RTRIM(LTRIM(Usuario)) = RTRIM(LTRIM(@Usuario))) 
        BEGIN
            SET @MensajeError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
    
    IF (@Cliente IS NULL OR RTRIM(LTRIM(@Cliente)) = '')
        BEGIN
            SET @MensajeError = 'Cliente no indicado. Por favor, indique un Cliente.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
    
    IF (@Sucursal < 0)
        BEGIN
            SET @MensajeError = 'Sucursal no indicada o menor que cero. Por favor, indique una Sucursal mayor o igual que cero.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
        
    IF (@Sucursal = 0)
        BEGIN
            SET @Sucursal = NULL;
        END
    
    IF (@Vencimiento IS NULL)
        BEGIN
            SET @MensajeError = 'Vencimiento no indicado. Por favor, indique un Vencimiento.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
    
    IF ((@Mov IN ('CFD FactVia Credito', 'FACT.VE.GRAVADO')) AND @Vencimiento < DateAdd(dd,1,@FechaEmision))
        BEGIN
            SET @MensajeError = 'El Vencimiento es incorrecto. El Vencimiento debe ser al menos un día mas de la fecha de emisión, ' + 
                                'de acuerdo con el movimiento indicado. Por favor, indique un Vencimiento valido.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
    
    IF (@Importe IS NULL OR @Importe <= 0)
        BEGIN
            SET @MensajeError = 'Importe no indicado o menor o igual que cero. Por favor, indique un Importe mayor que cero.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
    
    IF (@Impuestos IS NULL OR @Impuestos < 0)
        BEGIN
            SET @MensajeError = 'Importe no coincide con la suma de las partidas. Por favor, indique un Importe valido.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
    
    IF (@CentroDeCostos IS NULL OR RTRIM(LTRIM(@CentroDeCostos)) = '')
        BEGIN
            SET @MensajeError = 'Centro de costos no indicado. Por favor, indique un Centro de costos.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
        
    IF NOT EXISTS (SELECT * FROM CentroCostos WHERE CentroCostos = @CentroDeCostos)
        BEGIN
            SET @MensajeError = 'Centro de costos no encontrado. Por favor, indique un Centro de costos valido de Intelisis.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
     
     
     IF (@TipoPago IS NULL OR RTRIM(LTRIM(@TipoPago)) = '')
        BEGIN
            SET @MensajeError = 'Tipo de pago no indicado. Por favor, indique un Tipo de pago.'; 
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END
    
    --********************************************************************
    --        VALIDACIONES POR MOVIMIENTO
    --********************************************************************
    
    --    ***    'CFD FactVia Credito' ***
    IF (@Mov = 'CFD FactVia Credito')
        BEGIN
        IF (@Usuario = 'SITTI')
                BEGIN
                    SET @DescripcionExtra = 'SERVICIO DE TRANSPORTE PÚBLICO DE PERSONAS';
                    IF (@Concepto <> 'VIAJES ESPECIALES') 
                        BEGIN
                            SET @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. ' + 
                                                'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                            RAISERROR(@MensajeError,16,1);
                            RETURN;
                        END
                END
            ELSE
                BEGIN
                    SET @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, ' + 
                                        'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
                    EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                    RAISERROR(@MensajeError,16,1);
                    RETURN;
                END
        END    
    ELSE
        BEGIN
    
    --    ***    'FACT.VE.GRAVADO' | REFORMA HACENDARIA FACTURA DE CREDITO ***
    IF (@Mov = 'FACT.VE.GRAVADO')
        BEGIN
        IF (@Usuario = 'SITTI')
        BEGIN
                    SET @DescripcionExtra = 'SERVICIO DE TRANSPORTE PÚBLICO DE PERSONAS';
                    IF (@Concepto <> 'VIAJE ESPECIAL GRAVADO' AND
                        @Concepto <> 'VIAJES ESPECIALES') 
                        BEGIN
                            SET @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. ' + 
                                                'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                            RAISERROR(@MensajeError,16,1);
                            RETURN;
                        END
                END
            ELSE
                BEGIN
                    SET @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, ' + 
                                        'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
                    EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                    RAISERROR(@MensajeError,16,1);
                    RETURN;
                END
        END    
    ELSE
        BEGIN
    
    --    ***    'Factura TranspInd' ***
    IF (@Mov = 'Factura TranspInd')
        BEGIN
        IF (@Usuario = 'SITTI')
                BEGIN
                    SET @DescripcionExtra = 'TI  SERVICIO DE TRANSPORTE DE PERSONAL';
                    IF (@Concepto <> 'T.INDUSTRIAL 10%' AND
                        @Concepto <> 'T.INDUSTRIAL 15%') 
                        BEGIN
                            SET @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. ' + 
                                                'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                            RAISERROR(@MensajeError,16,1);
                            RETURN;
                        END
                    IF (@Concepto = 'T.INDUSTRIAL 10%')
                        BEGIN
                            SELECT
                                @Condicion = 'Credito',
                                @Impuesto1 = 11;
                            UPDATE @T_PartidasVtas
                            SET
                                Articulo = 'TI-10', TasaImpuesto = 11;
                        END
                    ELSE
                        IF (@Concepto = 'T.INDUSTRIAL 15%')
                            BEGIN
                                SELECT 
                                    @Condicion = 'Credito',
                                    @Impuesto1 = 16;
                                UPDATE @T_PartidasVtas
                                SET
                                    Articulo = 'TI-15', TasaImpuesto = 16;
                            END
                END
            ELSE
                BEGIN
                    SET @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, ' + 
                                        'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
                    EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                    RAISERROR(@MensajeError,16,1);
                    RETURN;
                END
        END    
    ELSE
        BEGIN
    
    --    ***    'CFD Sin Viaje' ***
    IF (@Mov = 'CFD Sin Viaje')
        BEGIN
        IF (@Usuario = 'SITTI')
                BEGIN
                    SET @DescripcionExtra = 'SERVICIO DE TRANSPORTE PÚBLICO DE PERSONAS';
                    IF (@Concepto <> 'VIAJES ESPECIALES') 
                        BEGIN
                            SET @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. ' + 
                                                'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                            RAISERROR(@MensajeError,16,1);
                            RETURN;
                        END
                END
            ELSE
                BEGIN
                    SET @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, ' + 
                                        'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
                    EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                    RAISERROR(@MensajeError,16,1);
                    RETURN;
                END
        END    
    ELSE
        BEGIN
    
    --    ***    'CFDI SIN VIAJE GRAV' ***
    IF (@Mov = 'CFDI SIN VIAJE GRAV')
        BEGIN
        IF (@Usuario = 'SITTI')
                BEGIN
                    SET @DescripcionExtra = 'SERVICIO DE TRANSPORTE PÚBLICO DE PERSONAS';
                    IF (@Concepto <> 'VIAJE ESPECIAL GRAVADO') 
                        BEGIN
                            SET @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. ' + 
                                                'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                            RAISERROR(@MensajeError,16,1);
                            RETURN;
                        END
                END
            ELSE
                BEGIN
                    SET @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, ' + 
                                        'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
                    EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                    RAISERROR(@MensajeError,16,1);
                    RETURN;
                END
        END    
    ELSE
        BEGIN
    
    --    ***    'Ing CFD Anticipado' ***
    IF (@Mov = 'Ing CFD Anticipado')
        BEGIN
        IF (@Usuario = 'SITTI')
                BEGIN
                    IF (@Concepto <> 'VIAJES ESPECIALES') 
                        BEGIN
                            SET @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. ' + 
                                                'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                            RAISERROR(@MensajeError,16,1);
                            RETURN;
                        END
                END
            ELSE
                BEGIN
                    SET @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, ' + 
                                        'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
                    EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                    RAISERROR(@MensajeError,16,1);
                    RETURN;
                END
        END    
    ELSE
        BEGIN
    
    --    ***    'Ing.CFDI Ant.Gravado' ***
    IF (@Mov = 'Ing.CFDI Ant.Gravado')
        BEGIN
        IF (@Usuario = 'SITTI')
                BEGIN
                    IF (@Concepto <> 'VIAJE ESPECIAL GRAVADO') 
                        BEGIN
                            SET @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. ' + 
                                                'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                            RAISERROR(@MensajeError,16,1);
                            RETURN;
                        END
                END
            ELSE
                BEGIN
                    SET @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, ' + 
                                        'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
                    EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                    RAISERROR(@MensajeError,16,1);
                    RETURN;
                END
        END    
    ELSE
        BEGIN
    
    --    ***    'Fact Otros Ing Cont' ***
    IF (@Mov = 'Fact Otros Ing Cont')
        BEGIN
        IF (@Usuario = 'SITTI')
                BEGIN
                    IF (@Concepto <> 'ENTRADAS A PARQUES' AND
                        @Concepto <> 'EXTRA PAQUETES') 
                        BEGIN
                            SET @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. ' + 
                                                'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                            RAISERROR(@MensajeError,16,1);
                            RETURN;
                        END
                    IF (@Concepto = 'ENTRADAS A PARQUES')
                        BEGIN
                            SELECT 
                                @Condicion = 'Contado',
                                @TasaImpuesto = 16;
                            UPDATE @T_PartidasVtas
                            SET
                                Articulo = 'PARQUES-15', TasaImpuesto = 16;

                        END
                    ELSE
                        BEGIN
                            IF (@Concepto = 'EXTRA PAQUETES')
                                BEGIN
                                    SELECT 
                                        @Condicion = 'Contado',
                                        @TasaImpuesto = 16;
                                    UPDATE @T_PartidasVtas
                                    SET
                                        Articulo = 'SECOPA-15', TasaImpuesto = 16;
                                END
                        END
                END
            ELSE
                BEGIN
                    SET @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, ' + 
                                        'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
                    EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                    RAISERROR(@MensajeError,16,1);
                    RETURN;
                END
        END    
    ELSE
        BEGIN
    
    --    ***    'Ing.CFDI Ant.Gravado' ***
    IF (@Mov = 'Ing.CFDI Ant.Gravado')
        BEGIN
        IF (@Usuario = 'SITTI')
                BEGIN
                    IF (@Concepto <> 'VIAJE ESPECIAL GRAVADO') 
                        BEGIN
                            SET @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. ' + 
                                                'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                            RAISERROR(@MensajeError,16,1);
                            RETURN;
                        END
                END
            ELSE
                BEGIN
                    SET @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, ' + 
                                        'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
                    EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                    RAISERROR(@MensajeError,16,1);
                    RETURN;
                END
        END    
    ELSE
        BEGIN

        --    ***    'Ing.Cred.Paquetes' ***
    IF (@Mov = 'Ing.Cred.Paquetes')
        BEGIN
        IF (@Usuario = 'SITTI')
                BEGIN
                    IF (@Concepto <> 'PAQUETE PROMOCIONES') 
                        BEGIN
                            SET @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. ' + 
                                                'Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';
                            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                            RAISERROR(@MensajeError,16,1);
                            RETURN;
                        END
                END
            ELSE
                BEGIN
                    SET @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, ' + 
                                        'pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
                    EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
                    RAISERROR(@MensajeError,16,1);
                    RETURN;
                END
        END    
    ELSE
        BEGIN
            --    ***    'NO HAY UN MOV VALIDO' ***
            SET @MensajeError = 'Mov no valido. El movimiento no se encuentra entre los movimientos esperados. ' 
                                + 'Por favor, indique un Movimiento valido.';
            EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
            RAISERROR(@MensajeError,16,1);
            RETURN;
        END

        END    --    ***    'Ing.Cred.Paquetes' ***
        END    --    ***    'Fact Otros Ing Cont' ***
        END    --    ***    'Ing.CFDI Ant.Gravado' ***
        END    --    ***    'Ing CFD Anticipado' ***
        END    --    ***    'CFDI SIN VIAJE GRAV' ***
        END    --    ***    'CFD Sin Viaje' ***
        END    --    ***    'Factura TranspInd' ***
        END    --    ***    'FACT.VE.GRAVADO' ***
        END --    ***    'CFD FactVia Credito' ***
    
    --********************************************************************
    --        PROCESO
    --********************************************************************
    
    IF (@Condicion = 'Contado')
		BEGIN
			SELECT @Vencimiento = @FechaEmision;
		END                           
	/* Clientes que solicitan @TipoPago = 'Transferencia Electrónica'
	Cementos Portland Moctezuma S.A. de C.V. id. 29683 21/02/2014
	COMERCIALIZADORA DE LACTEOS Y DERIVADOS S.A. DE C.V Id:10118 21/02/2014
	DI-DIGITAL  id:12027 19/10/2015
	FUNDACION TELETON MEXICO, A.C id:10565 27/10/2015
	KEY SAFETY SYSTEMS DE MEXICO S DE RL DE CV id:12441 suc:1 14/07/2016
	KEY AUTOMOTIVE ACCESSORIES DE MEXICO S DE RL DE CV id:12443 19/07/2016 
	*/
	If @Cliente in(29683,10118,12027,10565,12441,12443)
		BEGIN
			SET @TipoPago = 'Transferencia Electrónica';
		END
	/*T E M P O R A L*/
	/*Clientes que solicitan @TipoPago = 'Transferencia Electrónica' Por tiempo limitado*/
	/*id:28837 suc:13 CADENA COMERCIAL OXXO S.A. DE C.V. se refleje el método de pago transferencia bancaria hasta el 20 de agosto 20/07/2016*/
	IF @Cliente = '28837' AND @Sucursal = 13 AND @FechaEmision < '08/20/2016 23:59:59'
		BEGIN
			SET @TipoPago = 'Transferencia Electrónica';
		END
	
	/* Clientes que solicitan @TipoPago = 'Cheque nominativo'
	INVAMEX id. 46431 12/04/2016
	*/
	If @Cliente in(46431)
		BEGIN
			SET @TipoPago = 'Cheque Nominativo';
		END
	DECLARE @Unidad AS CHAR(20)
	IF @Cliente	= 8365 
	/*Cambio solicitado por Erika
	cliente id:8365 suc:0 ENSEÑANZA E INVESTIGACION SUPERIOR, A.C. 20/10/2015
	*/
		BEGIN
			SET @Unidad = 'No Aplica'
		END
	ELSE
		BEGIN
			SET @Unidad = 'Servicio'
		END
    
    --    ***        SE INSERTA LA VENTA        ***
    
    INSERT INTO Venta
        (
        Empresa,
        Mov,
        FechaEmision,
        UltimoCambio,
        Concepto,
        Moneda,
        TipoCambio,
        Usuario,
        Referencia,
        Observaciones,
        Estatus,
        Cliente,
        EnviarA,
        Almacen,
        FechaRequerida,
        Condicion,
        Vencimiento,
        Importe,
        Impuestos,
        ContUso,
        Comentarios,
        Prioridad,
        RenglonID,
        FormaPagoTipo
        )
    VALUES
        (
        @Empresa,
        @Mov,
        DBO.Fn_QuitarHrsMin(@FechaEmision),
        GETDATE(),
        @Concepto,
        @Moneda,
        @TipoCambio,
        @Usuario,
        @Referencia,
        @Observaciones,
        'SINAFECTAR',
        @Cliente,
        @Sucursal,
        @Almacen,
        @FechaEmision,
        @Condicion,
        @Vencimiento,
        @Importe,
        @Impuestos,
        @CentroDeCostos,
        @Comentarios,
        'Normal',
        1,
        @TipoPago
        );
    
    SET @RegresoID = SCOPE_IDENTITY();
    
    --    *****    SE INSERTA EL DETALLE EN VENTAD    *****
    
    INSERT INTO VentaD
        (
        ID,
        Renglon,
        RenglonSub,
        RenglonID,
        RenglonTipo,
        Cantidad,
        Almacen,
        Articulo,
        SubCuenta,
        Precio,
        PrecioSugerido,
        Impuesto1,
        Impuesto2,
        Impuesto3,
        DescripcionExtra,
        Costo,
        ContUso,
        Unidad,
        Factor,
        FechaRequerida,
        Sucursal,
        SucursalOrigen,
        PrecioMoneda,
        PrecioTipoCambio
        )
    SELECT
        @RegresoID,
        2048  * tpv.Consecutivo,
        0,
        1,
        'N',
        1,
        @Almacen,
        tpv.Articulo,
        NULL,
        tpv.Precio,
        0,
        tpv.TasaImpuesto,
        0,
        0,
        @DescripcionExtra,
        0,
        @CentroDeCostos,
        'Servicio',
        1,
        @FechaEmision,
        0,
        0,
        @Moneda,
        @TipoCambio
    FROM @T_PartidasVtas tpv;
    
    IF @Condicion = 'Contado'
        BEGIN
            INSERT INTO VentaCobro
                (
                ID,
                Importe1,
                Vencimiento,
                SucursalOrigen,
                FormaCobro1
                )
            SELECT
                @RegresoID,
                @Importe + @Impuestos,
                @Vencimiento,
                0, -- SucursalOrigen'
                @TipoPago;
        END
    
    --********************************************************************
    --        AFECTAR
    --********************************************************************
    
  --  IF EXISTS (SELECT Mov, CFD, CFD_tipoDeComprobante FROM MovTipo WHERE Modulo = 'VTAS' AND Mov = @Mov AND CFD = 1)
  --      BEGIN
  --          BEGIN TRY
  --              EXEC spAfectar 'VTAS', @RegresoID, 'AFECTAR', 'Todo', NULL, @Usuario, NULL, 1, @Error OUTPUT, @Mensaje OUTPUT;
  --          END TRY
            
  --          BEGIN CATCH
  --              SELECT 
  --                  @Error = ERROR_NUMBER(),                                    
  --                  @Mensaje = '(sp ' + IsNull(ERROR_PROCEDURE(),'') + ', ln ' + IsNull(Cast(ERROR_LINE() as varchar),'') + ') ' + 
  --                              IsNull(ERROR_MESSAGE(),'');
  --          END CATCH
            
  --          IF (SELECT Estatus FROM Venta WHERE ID = @RegresoID) = 'SINAFECTAR'
  --      BEGIN
  --                  SET @MensajeCompleto = 'Error al aplicar el movimiento de Intelisis: ' + 'Error = ' + Cast(IsNull(@Error,-1) as varchar(255)) + 
  --                                      ', Mensaje = ' + IsNull(@Mensaje, '')   +',Movimiento SIN AFECTAR, intente nuevamente';
  --                  EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar', 'Error', @MensajeCompleto, @Usuario, @LogParametrosXml;
  --                  RAISERROR(@MensajeCompleto,16,1);
  --                  RETURN;
  --              END
  --      END
  --  ELSE
  --      BEGIN
  --          BEGIN TRY
  --              EXEC spAfectar 'VTAS', @RegresoID, 'AFECTAR', 'Todo', NULL, @Usuario, NULL, 1, @Error OUTPUT, @Mensaje OUTPUT;
  --          END TRY
            
  --          BEGIN CATCH
  --              SELECT 
  --                  @Error = ERROR_NUMBER(),                                    
  --                  @Mensaje = '(sp ' + IsNull(ERROR_PROCEDURE(),'') + ', ln ' + IsNull(Cast(ERROR_LINE() as varchar),'') + ') ' + 
  --                              IsNull(ERROR_MESSAGE(),'');
  --          END CATCH
            
  --------If(Select Estatus From venta Where ID = @RegresoID ) = 'SINAFECTAR'                                    
  ------Begin                                    
                                      
  ------  Si algo salio mal, hay que revertir el proceso.                       
  ------   EXEC spAfectar 'Cancelar', @RegresoID, 'AFECTAR', 'Todo', NULL, @Usuario, NULL, 1, @Error OUTPUT, @Mensaje OUTPUT                                    
                                    
  ------ Delete from ventad where ID = @RegresoID                                    
  ------ Delete from venta where ID = @RegresoID                      
                                          
  ------ Set @MensajeCompleto =                                     
  ------  'Error al aplicar el movimiento de venta de Intelisis: ' +                                     
  ------  'Error = ' + Cast(IsNull(@Error,-1) as varchar(255)) + ', Mensaje = ' + IsNull(@Mensaje, '') +',Movimiento CANCELADO, intente nuevamente'                                        
                                        
  ------ Exec Interfaz_LogsInsertar 'Interfaz_ventasInsertar','Error',@MensajeCompleto,@Usuario,@LogParametrosXml;                                    
  ------ raiserror(@MensajeCompleto,16,1)                                    
  ------ return;                                    
                                      
  ------End         
            
  --          IF (SELECT Estatus FROM Venta WHERE ID = @RegresoID) = 'SINAFECTAR'
  --              BEGIN
  --                  SET @MensajeCompleto = 'Error al aplicar el movimiento de Intelisis: ' + 'Error = ' + Cast(IsNull(@Error,-1) as varchar(255)) + 
  --                                      ', Mensaje = ' + IsNull(@Mensaje, '')   +',Movimiento SIN AFECTAR, intente nuevamente';
  --                  EXEC Interfaz_LogsInsertar 'Interfaz_VentasInsertar', 'Error', @MensajeCompleto, @Usuario, @LogParametrosXml;
  --                  RAISERROR(@MensajeCompleto,16,1);
  --                  RETURN;
  --              END
  --      END
            
  --  SET @RegresoMovID = 
  --      (
  --      SELECT
  --          MovID
  --      FROM
  --          Venta
  --      WHERE
  --          ID = @RegresoID
  --      );
        
  --  --********************************************************************
  --  --        INFORMACION DE RETORNO
  --  --********************************************************************
  --  IF EXISTS (SELECT * FROM CFD AS A WHERE A.ModuloID = @RegresoID AND A.MovID = @RegresoMovID)
  --      BEGIN
  --          SELECT
  --              ID = @RegresoID,
  --              MovID = @RegresoMovID,
  --              CFDXml = CAST(T1.Documento AS VARCHAR(MAX)),
  --              Sello = T1.Sello,
  --              SelloSAT = T1.SelloSAT,
  --              TFDCadenaOriginal = T1.TFDCadenaOriginal,
  --              UUID = T1.UUID,
  --         FechaTimbrado = T1.FechaTimbrado,
  --              noCertificadoSAT = T1.noCertificadoSAT        
  --          FROM
  --              CFD AS T1
  --          WHERE
  --              T1.ModuloID = @RegresoID AND T1.MovID = @RegresoMovID;
        
  --          SELECT
  --              @ID  = @RegresoID,
  --              @MovID = @RegresoMovID,
  --              @CFDXml = CAST(T1.Documento AS VARCHAR(MAX)),
  --              @noCertificado = T1.noCertificado,
  --              @Sello = T1.Sello,
  --              @SelloSAT = T1.SelloSAT,
  --              @TFDCadenaOriginal = T1.TFDCadenaOriginal,
  --              @UUID = T1.UUID,
  --              @FechaTimbrado = T1.FechaTimbrado,
  --              @noCertificadoSAT = T1.noCertificadoSAT
  --          FROM
  --              CFD AS T1
  --          WHERE
  --              T1.ModuloID = @RegresoID AND T1.MovID = @RegresoMovID;
  --      END
  --  ELSE
  --      BEGIN
  --          SELECT
  --              ID = @RegresoID,
  --              MovID = @RegresoMovID,
  --              CFDXml = NULL,
  --              Sello = NULL,
  --              SelloSAT = NULL,
  --              TFDCadenaOriginal = NULL,
  --              UUID = NULL,
  --              FechaTimbrado = NULL,
  --              noCertificadoSAT = NULL;
  --          SELECT
  --              @ID  = @RegresoID,
  --              @MovID = @RegresoMovID,
  --              @CFDXml = NULL,
  --              @noCertificado = NULL,
  --              @Sello = NULL,
  --              @SelloSAT = NULL,
  --              @TFDCadenaOriginal = NULL,
  --              @UUID = NULL,
  --              @FechaTimbrado = NULL,
  --              @noCertificadoSAT = NULL;
  --      END

GO
