SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE Procedure [dbo].[Interfaz_tesoreriaDepositar]    
 @Empresa  char(5),    
 @FechaDeCorte smalldatetime,    
 @Concepto  varchar(50),    
 @Moneda   char(10),    
 @TipoCambio  float,    
 @Usuario  char(10),    
 @Referencia  varchar(50),    
 @CtaDinero  char(10),    
 @Importe  money,    
 @CentroDeCostos varchar(20),    
 @Observaciones varchar(100),    
 @Comentarios varchar(max)    
As    
    
 set nocount on    
    
 -- *************************************************************************    
 -- Variables    
 -- *************************************************************************    
     
 Declare @LogParametrosXml Xml;    
 Set @LogParametrosXml =     
  (select     
   @Empresa   as 'Empresa',    
   @FechaDeCorte  as 'FechaDeCorte',    
   @Concepto   as 'Concepto',    
   @Moneda    as 'Moneda',    
   @TipoCambio   as 'TipoCambio',    
   @Usuario   as 'Usuario',    
   @Referencia   as 'Referencia',    
   @CtaDinero   as 'CtaDinero',    
   @Importe   as 'Importe',    
   @CentroDeCostos  as 'CentroDeCostos',    
   @Observaciones  as 'Observaciones',    
   @Comentarios  as 'Comentarios'    
  For Xml Path('Parametros'));    
     
 Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Ejecución','',@Usuario,@LogParametrosXml;    
     
 Declare @MensajeError     varchar(255)    
 Declare @MensajeCompleto    varchar(max)    
    
 Declare @RegresoID      int    
 Declare @RegresoMov      varchar(20)    
 Declare @RegresoMovID     varchar(20)    
     
 Declare @Error       int    
 Declare @mensaje      varchar(512)    
     
 Declare @PrimerIDDeDepositosPorAplicar int    
 Declare @Contacto      int    
 Declare @ContactoTipo     char(10)    
     
 Declare @SaldoActual     money    
 Declare @ImporteActual     money    
 Declare @intCont      int     
 Declare @intCantidadTotal    int    
     
 Create Table #solicitudesPendientes    
 (    
  Consecutivo  int identity(1,1) not null,    
  ID    int,    
  MovID   int,    
  Saldo   Money,    
  Observaciones varchar(100),    
  Referencia  varchar(50),    
  Cliente   char(10)    
 )    
     
 Create Table #solicitudesParaAplicar    
 (    
  Consecutivo  int identity(1,1) not null,    
  ID    int,    
  MovID   int,    
  Saldo   Money,    
  Observaciones varchar(100),    
  Referencia  varchar(50),    
  Cliente   char(10)      
 )    
     
 -- *************************************************************************    
 -- Validaciones    
 -- *************************************************************************    
     
 ;With origenes (OrigenTipo, Origen, OrigenID, ContUso, FechaEmision, Cliente) as    
 (    
  select     
   OrigenTipo = 'CXC',    
   Origen  = Mov,     
   OrigenID = MovID,    
   ContUso,    
   FechaEmision,    
   Cliente    
  from     
   cxc     
  where     
   Usuario   = @Usuario and    
   ContUso   = @CentroDeCostos and    
   FechaEmision = dbo.fn_quitarhrsmin(@FechaDeCorte)  --se eliminan días anteriores  
  Union All    
  select     
   OrigenTipo = 'VTAS',    
   Origen  = Mov,     
   OrigenID = MovID,    
   ContUso,    
   FechaEmision,    
   Cliente    
  from     
   venta     
  where     
   Usuario   = @Usuario and    
   ContUso   = @CentroDeCostos and    
   FechaEmision = dbo.fn_quitarhrsmin(@FechaDeCorte)  --se eliminan días anteriores  
 )    
 Insert Into #solicitudesPendientes    
  select     
   d.ID,    
   d.MovId,    
   d.Saldo,    
   d.Observaciones,    
   d.Referencia,    
   o.Cliente    
  from     
   dinero d    
       
   inner join origenes o on    
    o.OrigenTipo = d.OrigenTipo and    
    o.Origen  = d.Origen and    
    o.OrigenID  = d.OrigenID     
  where     
   estatus  = 'pendiente' and     
   mov   = 'solicitud deposito' and     
   empresa  = @Empresa and     
   usuario  = @Usuario and    
   Moneda  = @Moneda     
  Order by    
   o.FechaEmision    
     
     
     
 If(@Empresa Is Null Or rtrim(ltrim(@Empresa)) = '')     
 Begin    
  Set @MensajeError = 'Empresa no indicada. Por favor, indique una Empresa';    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End    
     
 If(@FechaDeCorte Is Null)     
 Begin    
  raiserror('Fecha de Corte no indicada. Por favor, indique una Fecha de Corte',16,1);    
  return;    
 End    
     
 If(@Concepto Is Null Or rtrim(ltrim(@Concepto)) = '')     
 Begin    
  Set @MensajeError = 'Concepto no indicado. Por favor, indique un Concepto.';    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End    
     
 If(@Moneda Is Null Or rtrim(ltrim(@Moneda)) = '')     
 Begin    
  Set @MensajeError = 'Moneda no indicada. Por favor, indique una Moneda.';    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End    
     
 If(rtrim(ltrim(@Moneda)) <> 'Pesos' and rtrim(ltrim(@Moneda)) <> 'Dolares')     
 Begin    
  Set @MensajeError = 'La Moneda indicada no es ni "Pesos" ni "Dolares" (Moneda indicada "' + rtrim(ltrim(@Moneda)) + '"). Por favor, indique una Moneda valida.'    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End    
     
 If(@TipoCambio Is Null Or @TipoCambio <= 0)     
 Begin    
  Set @MensajeError = 'Tipo de cambio no indicado o menor o igual que cero. Por favor, indique un Tipo de cambio mayor que cero.';    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End    
     
 If(@Usuario Is Null Or rtrim(ltrim(@Usuario)) = '')     
 Begin    
  Set @MensajeError = 'Usuario no indicado. Por favor, indique un Usuario.';    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End    
      
 If Not Exists(select * from Usuario where rtrim(ltrim(Usuario)) = rtrim(ltrim(@Usuario)))     
 Begin    
  Set @MensajeError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End    
     
 If(@Importe Is Null Or @Importe <= 0)     
 Begin    
  Set @MensajeError = 'Importe no indicado o menor o igual que cero. Por favor, indique un Importe mayor que cero.';    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End    
     
 If(@CentroDeCostos Is Null Or rtrim(ltrim(@CentroDeCostos)) = '')     
 Begin    
  Set @MensajeError = 'Centro de costos no indicado. Por favor, indique un Centro de costos.';    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End    
     
 If Not Exists(select * from CentroCostos where CentroCostos = @CentroDeCostos)     
 Begin    
  Set @MensajeError = 'Centro de costos no encontrado. Por favor, indique un Centro de costos valido de Intelisis.';    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End    
     
 If(@CtaDinero Is Null Or rtrim(ltrim(@CtaDinero)) = '')     
 Begin    
  Set @MensajeError = 'Cuenta de Dinero no indicada. Por favor, indique una Cuenta de Dinero.';    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End    
     
 If Not Exists(Select * from ctaDinero Where ctaDinero = @CtaDinero)     
 Begin    
  Set @MensajeError = 'Cuenta de Dinero no encontrada. Por favor, indique una Cuenta de Dinero valida de Intelisis.';    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End    
     
     
 If not exists (select * from #solicitudesPendientes)    
 Begin    
  Set @MensajeError = 'No se encontraron solicitudes de depósito pendientes. Por favor, verificar que exista al menos una.';    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End    
     
 If (select Sum(Saldo) from #solicitudesPendientes) < @Importe    
 Begin    
  Set @MensajeError = 'La suma de saldos de las solicitudes pendientes no concuerdan con el Importe indicado (el Importe es mayor a la suma de saldos). Por favor, verificar el Importe.';    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End     
     
 If(@Usuario = 'SITTI' Or @Usuario = 'VIAJESESP')    
 Begin    
     
  If(@Concepto <> 'VIAJES ESPECIALES')    
  Begin    
   Set @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al usuario indicado. Por favor, indique un Concepto valido para este usuario.';    
   Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
   raiserror(@MensajeError,16,1);    
   return;    
  End    
     
 End    
 Else    
 Begin    
  Set @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';    
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeError,16,1);    
  return;    
 End    
     
      
     
 -- *************************************************************************    
 -- Proceso    
 -- *************************************************************************    
     
 Set @intCont = 1    
 Set @intCantidadTotal = (Select Count(*) From #solicitudesPendientes)    
 Set @ImporteActual = @Importe    
 while @intCont <= @intCantidadTotal and @ImporteActual <> 0    
 Begin    
      
  Select Top 1    
   @SaldoActual = Saldo    
  From    
   #solicitudesPendientes    
  Where    
   Consecutivo = @intCont    
      
  if @SaldoActual <= @ImporteActual    
  Begin    
      
   Insert Into #solicitudesParaAplicar    
    Select Top 1    
     ID,    
     MovID,    
     Saldo,    
     Observaciones,    
     Referencia,    
     Cliente    
    From    
     #solicitudesPendientes    
    Where    
     Consecutivo = @intCont    
        
   Set @ImporteActual = @ImporteActual - @SaldoActual;    
  End    
  Else    
  Begin    
       
   Insert Into #solicitudesParaAplicar    
    Select Top 1    
     ID,    
     MovID,    
     @ImporteActual,    
     Observaciones,    
     Referencia,    
     Cliente    
    From    
     #solicitudesPendientes    
    Where    
     Consecutivo = @intCont    
        
   Set @ImporteActual = 0;       
  End    
      
  Set @intCont = @intCont + 1;    
     
 End    
      
     
 Set @PrimerIDDeDepositosPorAplicar = (Select Top 1 MovID From #solicitudesParaAplicar)    
 --Set @Contacto = (Select Top 1 Cliente From #solicitudesParaAplicar)    ---Comentado para Depositos con CLiente "PubGral"
 set @Contacto= (select TOP 1  Case when cliente='PubGral' then 1 else cliente end as cliente from #solicitudesParaAplicar)    
 Insert Into dinero    
 (    
  Empresa,    
  Mov,    
  FechaEmision,    
  UltimoCambio,    
  Concepto,    
  Moneda,    
  TipoCambio,    
  Referencia,    
  Observaciones,    
  Usuario,    
  Estatus,    
  CtaDinero,    
  Importe,    
  Impuestos,    
  OrigenTipo,    
  Origen,    
  OrigenID,    
      
  Comentarios,    
  --ContUso,    
      
  Directo,    
  GenerarPoliza,    
  FormaPago,    
  ConDesglose,    
  Contacto,    
  ContactoTipo,    
  FechaProgramada,    
  SucursalDestino    
 )    
 Values    
 (    
  @Empresa,    
  'Deposito',    
  dbo.fn_quitarhrsmin(@FechaDeCorte),  --@FechaDeCorte,    
  GETDATE(),    
  @Concepto,    
  @Moneda,    
  @TipoCambio,    
  @Referencia,    
  @Observaciones,    
  @Usuario,    
  'SINAFECTAR',    
  @CtaDinero,    
  @Importe,    
  0,    
  'DIN',    
  'Solicitud Deposito',    
  @PrimerIDDeDepositosPorAplicar,    
      
  @Comentarios,    
  --@CentroDeCostos,    
      
  0,    
  0,    
  'Efectivo',    
  1,    
  @Contacto,    
  'Cliente',    
  @FechaDeCorte,    
  0    
 );    
     
 Set @RegresoID = SCOPE_IDENTITY();    
     
 Insert Into dinerod     
 (    
  ID,    
  Renglon,    
  RenglonSub,    
  Importe,    
  Referencia,    
  Aplica,    
  AplicaID--,    
  --ContUso    
 )    
  Select     
   ID   = @RegresoID,    
   Renglon  = 2048 * spa.Consecutivo,    
   RenglondSub = 0,    
   Importe  = spa.Saldo,    
   Referencia = spa.Referencia,    
   Aplica  = 'Solicitud Deposito',    
   AplicaID = spa.MovID--,    
   --ContUso  = @CentroDeCostos       
  From     
   #solicitudesParaAplicar spa    
     
 -- Se afecta el movimiento     
 Begin Try    
      
  EXEC spAfectar 'DIN', @RegresoID, 'AFECTAR', 'Todo', NULL, @Usuario, NULL, 1, @Error OUTPUT, @Mensaje OUTPUT    
     
 End Try    
 Begin Catch     
     
  SELECT    
   @Error  = ERROR_NUMBER(),    
   @Mensaje = '(sp ' + Isnull(ERROR_PROCEDURE(),'') + ', ln ' + Isnull(Cast(ERROR_LINE() as varchar),'') + ') ' + Isnull(ERROR_MESSAGE(),'');    
       
 End Catch    
     
 If(Select Estatus From dinero Where ID = @RegresoID) = 'SINAFECTAR'    
 Begin    
     
  -- Si algo salio mal, hay que revertir el proceso.    
  Delete from dinerod where ID = @RegresoID    
  Delete from dinero where ID = @RegresoID    
         
  Set @MensajeCompleto =     
   'Error al aplicar el movimiento de depósito de Intelisis: ' +     
   'Error = ' + Cast(IsNull(@Error,-1) as varchar(255)) + ', Mensaje = ' + IsNull(@Mensaje, '')    
       
  Exec Interfaz_LogsInsertar 'Interfaz_tesoreriaDepositar','Error',@MensajeCompleto,@Usuario,@LogParametrosXml;    
  raiserror(@MensajeCompleto,16,1)    
  return;    
     
 End    
     
     
 -- Que MovID    
 SET @RegresoMovID = (SELECT    
       MovID    
       FROM    
       dinero    
       WHERE        
       ID = @RegresoID);    
           
     
 -- *************************************************************************    
 -- Información de Retorno    
 -- *************************************************************************    
     
 Select    
  ID  = @RegresoID,    
  MovID = @RegresoMovID 
GO
