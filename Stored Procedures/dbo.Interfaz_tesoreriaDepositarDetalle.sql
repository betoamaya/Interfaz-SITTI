SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Autor:		ROBERTO AMAYA
-- Fecha de actualización: 13/12/2016
-- Descripción:	Insersión y afectación de depositos de tesoreria.
-- =============================================
CREATE PROCEDURE [dbo].[Interfaz_tesoreriaDepositarDetalle]
    @Empresa AS CHAR(5) ,
    @FechaDeCorte AS SMALLDATETIME ,
    @Concepto AS VARCHAR(50) ,
    @Moneda AS CHAR(10) ,
    @TipoCambio AS FLOAT ,
    @Usuario AS CHAR(10) ,
    @Referencia AS VARCHAR(50) ,
    @CtaDinero AS CHAR(10) ,
    @Importe AS MONEY ,
    @CentroDeCostos AS VARCHAR(20) ,
    @Observaciones AS VARCHAR(100) ,
    @Comentarios AS VARCHAR(MAX) ,
    @Partidas AS VARCHAR(MAX) = NULL ,
    @IdIntelisis AS INT OUTPUT ,
    @MovimientoId AS VARCHAR(MAX) OUTPUT
AS
    BEGIN
        SET NOCOUNT ON;

	--LOG
        DECLARE @logParametrosXML AS XML;
        SET @logParametrosXML = ( SELECT    @Empresa AS 'Empresa' ,
                                            @FechaDeCorte AS 'FechaDeCorte' ,
                                            @Concepto AS 'Concepto' ,
                                            @Moneda AS 'Moneda' ,
                                            @TipoCambio AS 'TipoCambio' ,
                                            @Usuario AS 'Usuario' ,
                                            @Referencia AS 'Referencia' ,
                                            @CtaDinero AS 'CtaDinero' ,
                                            @Importe AS 'Importe' ,
                                            @CentroDeCostos AS 'CentroDeCostos' ,
                                            @Observaciones AS 'Observaciones' ,
                                            @Comentarios AS 'Comentarios' ,
                                            @Partidas AS 'Partidas'
                                FOR
                                  XML PATH('Parametros')
                                );
        EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
            @Tipo = 'Ejecución', @DetalleError = '', @Usuario = @Usuario,
            @Parametros = @logParametrosXML;
	
	/* VARIABLES*/
        DECLARE @iError AS INT ,
            @MensajeError AS VARCHAR(255) ,
            @iIdDeposito AS CHAR(10) ,
            @iContacto AS CHAR(10) ,
            @iIDRegreso AS INT ,
            @xmlPartidas AS XML;

        DECLARE @tPartidas AS TABLE
            (
              iConsecutivo INT IDENTITY(1, 1)
                               NOT NULL ,
              iIdIntelisis INT ,
              sMovId CHAR(10)
            );

        DECLARE @tSolicitudes AS TABLE
            (
              iConsecutivo INT IDENTITY(1, 1)
                               NOT NULL ,
              iId INT ,
              sMovId CHAR(10) ,
              mSaldo MONEY ,
              sObservaciones VARCHAR(100) ,
              sReferencia VARCHAR(50) ,
              sCliente CHAR(10)
            );

	/*Llenar @tPartidas*/
        SELECT  @xmlPartidas = CAST(@Partidas AS XML);
        IF NOT @Partidas IS NULL
            BEGIN
                INSERT  INTO @tPartidas
                        ( iIdIntelisis ,
                          sMovId
                        )
                        SELECT  T.Loc.value('@IdIntelisis', 'int') AS IdIntelisis ,
                                T.Loc.value('@MovID', 'Char(10)') AS MovID
                        FROM    @xmlPartidas.nodes('//row/fila') AS T ( Loc );
            END;
	
	--***********************************************************
	-- V A L I D A C I O N E S
	--***********************************************************

        IF ( @Empresa IS NULL
             OR RTRIM(LTRIM(@Empresa)) = ''
           )
            BEGIN
                SET @MensajeError = 'Empresa no indicada. Por favor, indique una Empresa.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error de Validación',
                    @DetalleError = @MensajeError, @Usuario = @Usuario,
                    @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;
        IF ( @FechaDeCorte IS NULL )
            BEGIN
                SET @MensajeError = 'Fecha de Corte no indicada. Por favor, indique una Fecha de Corte.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error de Validación',
                    @DetalleError = @MensajeError, @Usuario = @Usuario,
                    @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;
        IF ( @Concepto IS NULL
             OR RTRIM(LTRIM(@Concepto)) = ''
           )
            BEGIN
                SET @MensajeError = 'Concepto no indicado. Por favor, indique un Concepto.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error de Validación',
                    @DetalleError = @MensajeError, @Usuario = @Usuario,
                    @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;
        IF ( @Moneda IS NULL
             OR RTRIM(LTRIM(@Moneda)) = ''
           )
            BEGIN
                SET @MensajeError = 'Moneda no indicada. Por favor, indique una Moneda.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error de Validación',
                    @DetalleError = @MensajeError, @Usuario = @Usuario,
                    @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;
        IF ( RTRIM(LTRIM(@Moneda)) <> 'Pesos'
             AND RTRIM(LTRIM(@Moneda)) <> 'Dolares'
           )
            BEGIN
                SET @MensajeError = 'Moneda no indicada. Por favor, indique una Moneda.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error de Validación',
                    @DetalleError = @MensajeError, @Usuario = @Usuario,
                    @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;
        IF ( @TipoCambio IS NULL
             OR @TipoCambio = 0
           )
            BEGIN
                SET @MensajeError = 'Tipo de cambio no indicado o menor o igual que cero. Por favor, indique un Tipo de cambio mayor que cero.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error de Validación',
                    @DetalleError = @MensajeError, @Usuario = @Usuario,
                    @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;
        IF ( @Usuario IS NULL
             OR RTRIM(LTRIM(@Usuario)) = ''
           )
            BEGIN
                SET @MensajeError = 'Usuario no indicado. Por favor, indique un Usuario.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error de Validación',
                    @DetalleError = @MensajeError, @Usuario = @Usuario,
                    @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;
        IF ( @Usuario = 'SITTI' )
            BEGIN
                IF ( @Concepto <> 'VIAJES ESPECIALES' )
                    BEGIN
                        SET @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al usuario indicado. Por favor, indique un Concepto valido para este usuario.';
                        EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                            @Tipo = 'Error de Validación',
                            @DetalleError = @MensajeError, @Usuario = @Usuario,
                            @Parametros = @logParametrosXML;
                        RAISERROR(@MensajeError,16,1);
                        RETURN;
                    END;
            END;
        ELSE
            BEGIN
                SET @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error de Validación',
                    @DetalleError = @MensajeError, @Usuario = @Usuario,
                    @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;
        IF NOT EXISTS ( SELECT  *
                        FROM    dbo.Usuario u
                        WHERE   RTRIM(LTRIM(u.Usuario)) = RTRIM(LTRIM(@Usuario)) )
            BEGIN
                SET @MensajeError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error de Validación',
                    @DetalleError = @MensajeError, @Usuario = @Usuario,
                    @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;
        IF ( @Importe IS NULL
             OR @Importe <= 0
           )
            BEGIN
                SET @MensajeError = 'Importe no indicado o menor o igual que cero. Por favor, indique un Importe mayor que cero.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error de Validación',
                    @DetalleError = @MensajeError, @Usuario = @Usuario,
                    @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;
        IF ( @CentroDeCostos IS NULL
             OR RTRIM(LTRIM(@CentroDeCostos)) = ''
           )
            BEGIN
                SET @MensajeError = 'Centro de costos no indicado. Por favor, indique un Centro de costos.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error de Validación',
                    @DetalleError = @MensajeError, @Usuario = @Usuario,
                    @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;
        IF NOT EXISTS ( SELECT  *
                        FROM    dbo.CentroCostos cc
                        WHERE   cc.CentroCostos = RTRIM(LTRIM(@CentroDeCostos)) )
            BEGIN
                SET @MensajeError = 'Centro de costos no encontrado. Por favor, indique un Centro de costos valido de Intelisis.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error de Validación',
                    @DetalleError = @MensajeError, @Usuario = @Usuario,
                    @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;
        IF ( @CtaDinero IS NULL
             OR RTRIM(LTRIM(@CtaDinero)) = ''
           )
            BEGIN
                SET @MensajeError = 'Cuenta de Dinero no indicada. Por favor, indique una Cuenta de Dinero.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error de Validación',
                    @DetalleError = @MensajeError, @Usuario = @Usuario,
                    @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;
        IF NOT EXISTS ( SELECT  *
                        FROM    dbo.CtaDinero cd
                        WHERE   cd.CtaDinero = RTRIM(LTRIM(@CtaDinero)) )
            BEGIN
                SET @MensajeError = 'Centro de costos no encontrado. Por favor, indique un Centro de costos valido de Intelisis.';
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error de Validación',
                    @DetalleError = @MensajeError, @Usuario = @Usuario,
                    @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;
	--***********************************************************
	-- P R O C E S O
	--***********************************************************
	
        DECLARE @iTotalDepositos AS INT ,
            @iContador AS INT ,
            @iCId AS INT ,
            @iCMovId AS VARCHAR(30);

        SET @iTotalDepositos = ( SELECT COUNT(*)
                                 FROM   @tPartidas
                               );
        SET @iContador = 1;
		--PRINT @iTotalDepositos;
        WHILE @iContador <= @iTotalDepositos
            BEGIN
                SELECT  @iCId = tp.iIdIntelisis ,
                        @iCMovId = tp.sMovId
                FROM    @tPartidas tp
                WHERE   tp.iConsecutivo = @iContador;
				
                INSERT  INTO @tSolicitudes
                        ( iId ,
                          sMovId ,
                          mSaldo ,
                          sObservaciones ,
                          sReferencia ,
                          sCliente
	                    )
                        SELECT  din.ID ,
                                din.MovID ,
                                din.Saldo ,
                                din.Observaciones ,
                                din.Referencia ,
                                din.Cliente
                        FROM    dbo.MovFlujo mf
                                INNER JOIN dbo.Dinero din ON mf.DID = din.ID
                        WHERE   mf.DModulo = 'DIN'
                                AND mf.OModulo IN ( 'CXC', 'VTAS' )
                                AND mf.OID = @iCId
                                AND mf.OMovID = @iCMovId;

                SELECT TOP 1
                        @iIdDeposito = ts.sMovId ,
                        @iContacto = ts.sCliente
                FROM    @tSolicitudes ts;

                SET @iContador = @iContador + 1;
            END;
	
        INSERT  INTO dbo.Dinero
                ( Empresa ,--1
                  Mov ,
                  FechaEmision ,
                  UltimoCambio ,
                  Concepto ,
                  Moneda ,
                  TipoCambio ,
                  Referencia ,
                  Observaciones ,
                  Usuario ,--10
                  Estatus ,
                  CtaDinero ,
                  Importe ,
                  Impuestos ,
                  OrigenTipo ,
                  Origen ,
                  OrigenID ,
                  Comentarios ,
                  Directo ,
                  GenerarPoliza ,--20
                  FormaPago ,
                  ConDesglose ,
                  Contacto ,
                  ContactoTipo ,
                  FechaProgramada ,
                  SucursalDestino --26
	            )
        VALUES  ( @Empresa , --1
                  'Deposito' ,
                  dbo.Fn_QuitarHrsMin(@FechaDeCorte) ,
                  GETDATE() ,
                  @Concepto ,
                  @Moneda ,
                  @TipoCambio ,
                  @Referencia ,
                  @Observaciones ,
                  @Usuario , --10
                  'SINAFECTAR' ,
                  @CtaDinero ,
                  @Importe ,
                  0 ,
                  'DIN' ,
                  'Solicitud Deposito' ,
                  @iIdDeposito ,
                  @Comentarios ,
                  0 ,
                  0 ,--20
                  'Efectivo' ,
                  1 ,
                  @iContacto ,
                  'Cliente' ,
                  @FechaDeCorte ,
                  0 --26
	            );
		
	
        SET @iIDRegreso = SCOPE_IDENTITY();

        INSERT  INTO dbo.DineroD
                ( ID ,
                  Renglon ,
                  RenglonSub ,
                  Importe ,
                  Referencia ,
                  Aplica ,
                  AplicaID
		        )
                SELECT  ID = @iIDRegreso ,
                        Renglon = 2048 * ts.iConsecutivo ,
                        RenglonSub = 0 ,
                        Importe = ts.mSaldo ,
                        Referencia = ts.sReferencia ,
                        Aplica = 'Solicitud Deposito' ,
                        AplicaID = ts.sMovId
                FROM    @tSolicitudes ts;
	--***********************************************************
	-- A F E C T A R - - - M O V I E N T O
	--***********************************************************
        BEGIN TRY
            EXEC dbo.spAfectar @Modulo = 'DIN', @ID = @iIDRegreso,
                @Accion = 'AFECTAR', @Base = 'Todo', @GenerarMov = NULL,
                @Usuario = @Usuario, @SincroFinal = NULL, @EnSilencio = 1,
                @Ok = @iError OUTPUT, @OkRef = @MensajeError OUTPUT;
        END TRY
        BEGIN CATCH
            SELECT  @iError = ERROR_NUMBER() ,
                    @MensajeError = '(sp ' + ISNULL(ERROR_PROCEDURE(), '')
                    + ', ln ' + ISNULL(CAST(ERROR_LINE() AS VARCHAR), '')
                    + ') ' + ISNULL(ERROR_MESSAGE(), '');
			
        END CATCH;

        IF ( SELECT Estatus
             FROM   dbo.Dinero
             WHERE  ID = @iIDRegreso
           ) = 'SINAFECTAR'
            BEGIN
                DECLARE @sMensajeError AS VARCHAR(255);
                SELECT  @MensajeError = Descripcion
                FROM    dbo.MensajeLista
                WHERE   Mensaje = @iError;
                SET @sMensajeError = 'Error al aplicar el movimiento de depósito de Intelisis: Error'
                    + CAST(ISNULL(@iError, -1) AS VARCHAR) + ', Mensaje = ';
                    --+ @MensajeError;
                EXEC dbo.Interfaz_LogsInsertar @SP = 'Interfaz_tesoreriaDepositarDetalle',
                    @Tipo = 'Error', @DetalleError = @sMensajeError,
                    @Usuario = @Usuario, @Parametros = @logParametrosXML;
                RAISERROR(@MensajeError,16,1);
                RETURN;
            END;

        SET @IdIntelisis = @iIDRegreso;
        SET @MovimientoId = ( SELECT    MovID
                              FROM      dbo.Dinero
                              WHERE     ID = @iIDRegreso
                            );
        RETURN;
    
    END;
GO
GRANT EXECUTE ON  [dbo].[Interfaz_tesoreriaDepositarDetalle] TO [Linked_Svam_Pruebas]
GO
