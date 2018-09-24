SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[Interfaz_gastoInsertar]                                                                  
 @Empresa  char(5),                                                                  
 @Mov   char(20),                                                                  
 @FechaEmision smalldatetime,                                                                  
 --@Concepto  varchar(50),                                                                  
 @Moneda   char(10),                                                                  
 @TipoCambio  float,                                                                  
 @Usuario  char(10),                                                                  
 @Referencia  varchar(50),                                                                  
 @Proveedor  char(10),                                                                  
 @FechaRequerida smalldatetime,                                                                  
 @Observaciones varchar(100),                                                                  
 @Comentarios varchar(max),                                                                
 @Antecedente char(20)=null,--MovAplica                                                              
 @AntecedenteID varchar(20)=null, --Movp Aplica ID                                                              
@Clasificacion varchar(50) =null,                                                            
 @Partidas  varchar(max) = null                                                                  
As                                                                  
                                                                  
 set nocount on                                                                  
 set dateformat YMD                                                                  
                                                                   
 -- *************************************************************************                                                                  
 -- Variables                                                                  
 -- *************************************************************************    
 
 IF @Proveedor = 'E034748'
	BEGIN
		SET @Proveedor = 'E0034748' --Claudia
	END
                                                               
                                                                   
 Declare @LogParametrosXml Xml;                                                                  
 Set @LogParametrosXml =                                                                   
  (select                                                                   
   @Empresa   as 'Empresa',                                                                  
   @Mov    as 'Mov',                                                                  
   @FechaEmision  as 'FechaEmision',                                                                  
   --@Concepto   as 'Concepto',                                                                  
   @Moneda    as 'Moneda',                                                                  
   @TipoCambio   as 'TipoCambio',                                                                  
   @Usuario   as 'Usuario',                                                                  
   @Referencia   as 'Referencia',                                                                  
   @Proveedor   as 'Proveedor',                                                                  
   @FechaRequerida  as 'FechaRequerida',                                                                  
   @Observaciones  as 'Observaciones',                                                                  
   @Comentarios  as 'Comentarios',                                                               
   @Antecedente as 'Antecedente',                                                              
@AntecedenteID as 'AntecedenteID',               
  @Clasificacion as 'Clasificacion',                             
   @Partidas   as 'Partidas'                                  
  For Xml Path('Parametros'));                                    
                                                                   
 Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Inserción','',@Usuario,@LogParametrosXml;                                                                
                        
                                                                   
 Declare @Clase     varchar(50)                                                                 
 Declare @Importe    money                                         
 Declare @Impuestos    money                                                                  
                                                              
 Declare @mensajeError   varchar(max)                                        
 Declare @MensajeCompleto  varchar(max)                                                                  
                                                          
 Declare @RegresoID int                                                                  
 Declare @RegresoMovID varchar(20)                                                                  
 Declare @RegresoXml xml                                    
                                                                   
 Declare @movidCFD    VARCHAR(30)                                                                   
 Declare @Error     int                                                                  
 Declare @codigo     int                                                                  
 Declare @mensaje    varchar(512)                                                                  
                                                                   
 Declare @cadenaSal    varchar(255)                                                                   
 Declare @selloSal    varchar(255)                                                                  
 Declare @noCertificadoSal  varchar(30)                                                                  
 Declare @fechaAutorizacionSal datetime                                                                  
 Declare @subclase    varchar(50)                                                                  
                                                                   
 Create Table #partidas                                                                  
 (                                          
  ID    int identity(1,1) not null,                                                                  
  Cantidad  int,                                                                  
  Precio   money,                            Impuestos  money,                                                                  
  CentroDeCosto varchar(20),                                                                  
  Referencia  varchar(50),                                                                  
  Concepto  varchar(50),                                                                  
  RFC    varchar(20)                                                                  
  ,Espacio        varchar(20)                                                                  
 )                                                                  
                                                                  
 Declare @xml xml                                                                  
 Set @xml = Cast(@Partidas as xml)                                                                  
 if not @Partidas is null                                                                  
 Begin          
  Insert Into #partidas               
   SELECT              
    T.Loc.value('@Cantidad', 'int') As Cantidad,                                                                  
    T.Loc.value('@Precio', 'money') As Precio,                                         
    T.Loc.value('@Impuestos', 'money') As Impuestos,                                                                  T.Loc.value('@CentroDeCosto', 'varchar(20)') As CentroDeCosto,                                                                  
    T.Loc.value('@Referencia', 'varchar(50)') As Referencia,                                                                  
    T.Loc.value('@Concepto', 'varchar(50)') As Concepto,                        
    T.Loc.value('@RFC',      'varchar(20)') As RFC,                                                                  
    T.Loc.value('@Espacio',  'varchar(20)') As Espacio                                                     
   FROM                                                                    
    @xml.nodes('//row/fila') as T(Loc)                                                         
 End                                                                  
                                                                    
 -- *************************************************************************                                                                  
 -- Validaciones                                                                  
 -- *************************************************************************                                                                  
                                                                   
            If(@Empresa Is Null Or rtrim(ltrim(@Empresa)) = '')                                                                   
 Begin                                                                  
  Set @MensajeError = 'Empresa no indicada. Por favor, indique una Empresa';                                                          
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
  raiserror(@MensajeError,16,1);                                                                  
  return;                                                                  
 End                                                                  
                                                                   
 If(@Mov Is Null Or rtrim(ltrim(@Mov)) = '')                                                                   
 Begin                                                                  
  Set @MensajeError = 'Movimiento no indicado. Por favor, indique un Movimiento.';                                                                
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
  raiserror(@MensajeError,16,1);                                                         
  return;                                                                  
 End                                                                  
                                                                   
 If(@FechaEmision Is Null)                                                                   
 Begin                                                
  Set @MensajeError = 'Fecha de Emisión no indicada. Por favor, indique una Fecha de Emisión';                                                                  
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
  raiserror(@MensajeError,16,1);               
  return;                       
 End                             
                       
                     
                                                                   
 If(@Moneda Is Null Or rtrim(ltrim(@Moneda)) = '')                                          
 Begin                                                                  
  Set @MensajeError = 'Moneda no indicada. Por favor, indique una Moneda.';                  
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
  raiserror(@MensajeError,16,1);                                                 
  return;                                                                  
 End                                                            
                                                                   
 If(rtrim(ltrim(@Moneda)) <> 'Pesos' and rtrim(ltrim(@Moneda)) <> 'Dolares')                                                                   
 Begin                                                                  
  Set @MensajeError = 'La Moneda indicada no es ni "Pesos" ni "Dolares" (Moneda indicada "'+ rtrim(ltrim(@Moneda)) + '"). Por favor, indique una Moneda valida.'                                                                  
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
  raiserror(@MensajeError,16,1);                                                                  
  return;                                                                  
 End                                                                  
                                                        
 If(@TipoCambio Is Null Or @TipoCambio <= 0)                                                                   
 Begin                                                                  
  Set @MensajeError = 'Tipo de cambio no indicado o menor o igual que cero. Por favor, indique un Tipo de cambio mayor que cero.';                                                                  
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
  raiserror(@MensajeError,16,1);                                                                  
  return;                                                                  
 End                                                                  
                                                  
 If(@Usuario Is Null Or rtrim(ltrim(@Usuario)) = '')                                
 Begin                                                                  
  Set @MensajeError = 'Usuario no indicado. Por favor, indique un Usuario.';                                                                  
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                          
  raiserror(@MensajeError,16,1);                                                                  
  return;                                                                  
 End                                                                  
                                                                    
 If Not Exists(select * from Usuario where rtrim(ltrim(Usuario)) = rtrim(ltrim(@Usuario)))                                                                   
 Begin                                                                  
  Set @MensajeError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';                                                
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                    
  raiserror(@MensajeError,16,1);                                                                
  return;                                                                  
 End                                                                  
                                              
 If(@Proveedor Is Null Or rtrim(ltrim(@Proveedor)) = '')                                                                 
 Begin                                                                  
  Set @MensajeError = 'Proveedor no indicado. Por favor, indique un Proveedor.';                                                                  
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
  raiserror(@MensajeError,16,1);                                                                  
  return;                                                                  
 End                                                                  
                                                                   
 If(@FechaRequerida Is Null)                                                
 Begin                                                                  
  raiserror('Fecha requerida no indicada. Por favor, indique una Fecha requerida.',16,1);                                                                  
  return;                                                                  
 End                                   
                                                                    
 If(@Mov = 'Amortiz Pagos Ant')                                                                  
 Begin                                                                  
  If(@Usuario = 'SITTI')                                                                  
  Begin                                                           
                                                                    
   --If(@Concepto <> 'ENTRADAS A PARQUES (OTROS GASTOS)')                                                                  
   If Exists (Select * From #partidas where Concepto <> 'ENTRADAS A PARQUES (OTROS GASTOS)')                                                                  
   Begin                                                            
    Set @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';                                                        








  
    
      
        
          
    Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
    raiserror(@MensajeError,16,1);                                                                  
    return;                                                                  
   End                                                                  
                                                                     
  End                             
  Else                                                                  
  Begin                                                                  
   Set @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';                                                                  
   Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                
   raiserror(@MensajeError,16,1);            
   return;      
  End                                                                  
                                
 End                 
 Else If(@Mov = 'Pagos Anticipados')                                                          
 Begin                                                                  
          
  If(@Usuario = 'SITTI')                                                                  
  Begin                                                                  
                                                                    
   --If(@Concepto <> 'ENTRADAS A PARQUES')                                               
   If Exists (Select * From #partidas where Concepto <> 'ENTRADAS A PARQUES')                                                                  
   Begin                                                                  
    Set @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';                          
    Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
    raiserror(@MensajeError,16,1);                                                                  
    return;                                                                  
   End                                                 
                                                          
  End                                                                  
  Else                                                            
  Begin                                                                  
   Set @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';                                                                  
   Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
   raiserror(@MensajeError,16,1);                                                        
   return;                
  End                                                                   
                                                                    
 End                                                                  
                                                               
 --***********                                                              
 Else If(@Mov = 'Comprobante')                                                                  
 Begin                                                                  
                                          
  If(@Usuario = 'SITTI')                                                     
  Begin                                                                  
                                                                    
   --If(@Concepto <> 'ENTRADAS A PARQUES')                                                                  
   If (@Antecedente is null and @AntecedenteID is Null) --Exists (Select * From #partidas where Concepto <> 'ENTRADAS A PARQUES')                               
   Begin                                                                  
    Set @MensajeError = 'No se especificaron los origenes del comprobante, favor de indicar Antecedente y Atecedente ID';                                                                  
    Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
    raiserror(@MensajeError,16,1);                                                          
    return;                                                                  
   End                                  
   
  End                                                                  
  Else                                                                  
  Begin                                                       
   Set @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';                                                                  
   Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
   raiserror(@MensajeError,16,1);                                                                  
   return;                                                        
  End                                                             
--Begin                                       
-- IF EXISTS( SELECT @clasificacion from Gasto where not Clase  in  (                                                            
--'AJUSTE IMSS' ,                                                            
--'AMORTIZ. RENTAS PAGADAS POR ANTICIPADO',                                                            
--'AMORTIZ.PAGOS ANT DIVERSOS',                                                            
--'AMORTIZ.PLACAS Y TENENCIAS',                                                            
--'AMORTIZ.SEGUROS PAGADOS POR ANTICIPADO',                                                            
--'AMORTIZ.SISTEMAS COMPUTACIONALES',                                                            
--'AMORTIZ.UNIFORMES PAGADOS POR ANTICIPADO',                                                            
--'APLICACION PTU',                                                       
--'COSTO VENTAS (PROMOVISION)',                                                            
--'COSTOS ASIGNABLES',                                                            
--'COSTOS ASIGNABLES AL 10%',                                                            
--'COSTOS VARIABLES',                                                            
--'GASTOS  DE VENTA AL 10%',                                                            
--'GASTOS CORPORATIVOS',                        
--'GASTOS DE ADMINISTRACION DE ZONA',                                                            
--'GASTOS DE VENTA',                                                            
--'GASTOS FINANCIEROS',                                                            
--'INFONAVIT RETENIDO',                                                            
--'IVA ANTICIPOS',                                                            
--'OBRAS EN PROCESO',                                                            
--'OTROS ACTIVOS',                                                            
--'OTROS GASTOS',                                                            
--'PAGOS ANTICIPADOS',                                                            
--'PRESUPUESTO',                                                            
--'PRODUCTOS FINANCIEROS',                                                            
--'SIN CLASIFICACION'                                                            
--  ))                                                               
--   Begin                                                                  
--    Set @MensajeError = 'Clasificación no válida. Por favor indique una clasificación válida para el movimiento COMPROBANTE';                                                                  
--    Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                             
--    raiserror(@MensajeError,16,1);          
--   return;                                                                  
--   End                                    
--  set @Clase=@Clasificacion   
-- END                                                                   
 End                                                                  
                                                               
 --***********                                                              
                              
 Else If(@Mov = 'Solicitud Gasto')                                                                  
 Begin                                                                  
                                                                   
  If(@Usuario = 'SITTI')                                                  
  Begin                                                                  
                                                                    
   --If(@Concepto <> 'DEVOLUCIONES SOBRE VTAS VIAJES ESPECIALES (VENTAS)')                                                   
 If Exists(Select * From #Partidas Where Not Concepto In (                                                                   
   'DEVOLUCIONES SOBRE VTAS VIAJES ESPECIALES (VENTAS)',                                                                  
   'Cuotas y Peajes (Administración)',                            
   'Otros Gastos Intercompañía (Otros Gastos)',                                                                    
   'Diesel en Carreteras (Variables)',                                         
   'Gastos Varios (Ventas)',                                                                
   'ARRENDAMIENTO DE AUTOBUSES (VENTAS)'   ,                                                            
---Depurar conceptos de aquí hacia abajo                   
  'ALIMENTOS DE OPERADORES(ASIGNABLES) ',                                                            
  'AGUA PURIFICADA (VENTAS)',                                                                   
       'GTS. DE VIAJE CON ALGUNOS REQUISITOS (VENTAS)',                                                          
       'CONSUMO DE ALIMENTOS (VENTAS)',                                                     
       'CONSUMO DE ALIMENTOS (ASIGNABLES)',                                                                   
       'CONSUMOS DE HERRAMIENTAS (ASIGNABLES)',                                                                     
       'CUOTAS Y PEAJES  (VENTAS)',                                                                     
       'DIESEL EN CARRETERA C/ALGUNOS REQ. (VARIABLES)',                                                                     
       'DIESEL EN CARRETERAS (VARIABLES)',             
       'TRANSPORTE (VENTAS)',                                                                     
       'UTILES DE ASEO Y LIMPIEZA (ASIGNABLES)',                                                             
       'ACEITES Y GRASAS (VARIABLES)',                                                                     
       'CD REFACCIONES MANTTO (VARIABLES)',                                                                     
       'GTS. DE IMAGEN CON ALGUNOS REQUISITOS (ASIGNABLES)',                                                                     
       'GTS. DE IMAGEN CON ALGUNOS REQUISITOS (VENTAS)',                                                                     
     'HOSPEDAJE (VENTAS)',   
       'OTROS (ASIGNABLES)',                                                                     
  'OTROS IMPUESTOS (VENTAS)',                                        
       'VARIOS (VENTAS)',                                                                  
'GASTOS DE IMAGEN C/ALGUNOS REQUISITOS (VARIABLES)',                                                                     
       'GTS VARIOS DEDUCIBLES SIN REQ. (VENTAS)',                                                                     
       'LIMPIEZA DE UNIDADES (ASIGNABLES)',                                                            
       'REPARACIONES MENORES  (VARIABLES)',                                                                    
       'TELEFONO CELULAR (ASIGNABLES)',                                                                  
    'CD REFACCIONES ACOND (VARIABLES)',                              'ARRENDAMIENTO DE AUTOBUSES (VENTAS)',                                                                
  'GASTOS DE VIAJE CON ALGUNOS REQUISITOS (VARIABLES)',                                                                  
       'Cuotas y Peajes (Ventas)',                                                              
       'ACONDICIONAMIENTO DE INMUEBLES (VENTAS)',                                                               
                                 'Cuotas y Peajes (Administración)',                                                                    
                            'Otros Gastos Intercompañía (Otros Gastos)',                                                                    
                            'Diesel en Carreteras (Variables)',                                                                    
                            'Gastos Varios (Ventas)' ,                                                              
             /*Se agregan conceptos de la lista que tiene ISMAEL VAZQUEZ*/                                                              
      'GASTOS A COMPROBAR (EGRESOS)',                                                              
'GASTOS A COMPROBAR',                                                             
'REFACCIONES DE ALMACEN (VARIABLES)',                                                              
'CD REFACCIONES MANTTO (VARIABLES)',                                                              
'GTO. PAQ. CAMISETAS',                                                              
'OT. GTOS NO DEDUCIBLES DE ISR DE PAQUETES',               
                                                             
'OT. GTOS NO DEDUCIBLES PAQUETES',                                                              
'CD REFACCIONES ACOND (VARIABLES)',                                   
'CD REFACCIONES ACCID (VARIABLES)',                                                              
'DIESEL EN CARRETERAS (VARIABLES)',                                                              
'DIESEL DE RUTA FUERA DE BASE (VARIABLES)',                                           
'ACEITES Y GRASAS (VARIABLES)',                                                              
'CONSUMOS DE LLANTAS (VARIABLES)',                                                              
'GASTOS DE VIAJE CON ALGUNOS REQUISITOS (VARIABLES)',                                                              
'GASTOS DE IMAGEN C/ALGUNOS REQUISITOS (VARIABLES)',                                                              
'REPARACIONES MENORES  (VARIABLES)',                                                              
'DIESEL EN CARRETERA C/ALGUNOS REQ. (VARIABLES)',                            
'OTROS IMPUESTOS (ASIGNABLES)',                                                              
'LIMPIEZA DE UNIDADES (ASIGNABLES)',                
'MANT.VEHICULOS EN SERVICIO (ASIGNABLES)' ,                                                            
'TRANSPORTE (ASIGNABLES)',                        
'OTROS (ASIGNABLES)',                                                              
'CONSUMOS DE HERRAMIENTAS (ASIGNABLES)',                                                              
'CONSUMOS DE TALLER (ASIGNABLES)',                                                              
'TELEFONO CELULAR (ASIGNABLES)',                    
'MANT.HERR. Y EQ. DE TALLER (ASIGNABLES)',    
'MANT.MOB.Y EQ.OFICINA (ASIGNABLES)',                                  
'MANT.VEHICULOS EN SERVICIO (ASIGNABLES)',                        
'MANT.EQ.COMPUTACION (ASIGNABLES)',                                                 
'MANT. EQ. DE AUDIO Y VIDEO (ASIGNABLES)',                                          
'MANTENIMIENTO DE INMUEBLES (ASIGNABLES)',                                                              
'UTILES DE ASEO Y LIMPIEZA (ASIGNABLES)',                                                              
'GASTOS MEDICOS (ASIGNABLES)',                                                              
'ALIMENTOS A EMPLEADOS (ASIGNABLES)',        
'SEGUROS Y FIANZAS (ASIGNABLES)',                                                              
'PAPELERIA Y ART.DE OFICINA (ASIGNABLES)',                                 
'VARIOS (ASIGNABLES)',                                     
'HOSPEDAJE (ASIGNABLES)',                                                     
'FUMIGACION DE EDIFICIOS (ASIGNABLES)',                                                              
'VARIOS DE SEG.E HIGIENE (ASIGNABLES)',                                                              
'GASOLINA (ASIGNABLES)',                                                           
'HONORARIOS MEDICOS A PERS. FISICAS (ASIGNABLES)',                                                              
'HONORARIOS A  OTRAS PERS FIS. 15%  (ASIGNABLES)',                                                              
'OTROS DE CAPACITACION (ASIGNABLES)',                                                  
'ATENCION A ACCIDENTADOS (ASIGNABLES)',                                                              
'REPAR. DE VEHICULOS ACCIDENTADOS (ASIGNABLES)',                                                              
'OTROS GASTOS DE ACCIDENTES (ASIGNABLES)',                                                              
'GASTOS VARIOS (ASIGNABLES)',                                                              
'AGUA PURIFICADA  (ASIGNABLES)',                                                              
'GASTOS DE DORMITORIOS (ASIGNABLES)',                                    
'SERVICIOS DE VIGILANCIA (ASIGNABLES)',                                                              
'GTS DEDUCIBLES SIN REQ. (ASIGNABLES)',                                                              
'GASTOS VARIOS DED.SIN REQ. (ASIGNABLES)',                                                              
'GTS DE VIAJE CON ALGUNOS REQUISITOS. (ASIGNABLES)',                                                              
'GTS. DE IMAGEN CON ALGUNOS REQUISITOS (ASIGNABLES)',                                                              
'REP.MENORES CON ALGUNOS REQUISITOS (ASIGNABLES)',                                            
'GASTOS NO DEDUCIBLES (ASIGNABLES)',                                                              
'CUOTAS Y PEAJES  (VENTAS)',                                                              
'HOSPEDAJE (VENTAS)',                                                              
'TRANSPORTE (VENTAS)',                                                              
'CONSUMO DE ALIMENTOS (VENTAS)',                                  
   'CONSUMO DE ALIMENTOS (ASIGNABLES)',                                                        
'OTROS  (VENTAS)',                                                              
'ARRENDAMIENTO DE AUTOBUSES (VENTAS)',                              
'ARR.INMUEBLES PERSONAS FISICAS 15% (VENTAS)',                                                              
'ARR.INMUEBLES DE PERS.MORALES (VENTAS)',                                                              
'ENERGIA ELECTRICA (VENTAS)',                                                              
'AGUA POTABLE (VENTAS)',                                                              
'TELEFONOS (VENTAS)',            
'TELEFONO CELULAR (VENTAS)',                                                              
'SERVICIO DE CABLE (VENTAS)',                      
'MANT.MOB.Y EQ.OFICINA (VENTAS)',                       'MANT.VEHICULOS EN SERVICIO (VENTAS)',                                                              
'MANT.EQ.COMPUTACION (VENTAS)',                                             
'MANTENIMIENTO DE INMUEBLES (VENTAS)',                                                              
'UTILES DE ASEO Y LIMPIEZA (VENTAS)',                                                              
'SERVICIO DE LIMPIEZA (VENTAS)',                                                              
'ACONDICIONAMIENTO DE INMUEBLES (VENTAS)',                     
'EVENTOS ESPECIALES (VENTAS)',                                                              
'IVA DE GASTOS NO ACREDITABLE (VENTAS)',                                                              
'IVA DE GASTOS PRORRATEABLES (VENTAS)',                                                              
'PAPELERIA Y ART.DE OFICINA (VENTAS)',                                                              
'PAPELERIA IMPRESA (VENTAS)',                                                       
'VARIOS (VENTAS)',                     
'GASOLINA (VENTAS)',                                                              
'DIESEL EN CARRETERA (VENTAS)',                                                              
'ACEITES Y GRASAS (VENTAS)',                                                              
'FLETES Y ACARREOS (VENTAS)',                                                              
'PAQUETERIA (VENTAS)',                                                            
'ANUNCIOS EN SECCION AMARILLA (VENTAS)',                                                              
'ASESORIA PUBLICITARIA (VENTAS)',                                                              
'PUBLICIDAD EN PERIODICO (VENTAS)',                                                              
'OTROS MEDIOS DE PUBLICIDAD (VENTAS)',                                                              
'REPARAC.DE VEHICULOS ACCIDENTADOS (VENTAS)',                                    
'DONATIVOS (GTOS VENTA)',                               
'GASTOS VARIOS (VENTAS)',                                                              
'CONSUMO DE ALIMENTOS EN PLAZA (VENTAS)',                                                            
'AGUA PURIFICADA (VENTAS)',                                                              
'SERVICIOS DE VIGILANCIA  (VENTAS)',                                       
'GTS DEDUCIBLES SIN REQ. (VENTAS)',                                                              
'GTS VARIOS DEDUCIBLES SIN REQ. (VENTAS)',                                                              
'GTS. DE VIAJE CON ALGUNOS REQUISITOS (VENTAS)',                                                              
'GTS. DE IMAGEN CON ALGUNOS REQUISITOS (VENTAS)',                                                              
'REP.MENORES  CON ALGUNOS REQUISITOS (VENTAS)',                                                              
'GTS. NO DED X ISR DE FACILIDADES (VENTAS)',                                 
'GASTOS NO DEDUCIBLES (VENTAS)',                   
--'ALIMENTOS DE OPERADORES (ASIGNABLES)',                                                     
'OTROS GASTOS DIVERSOS (OTROS GASTOS)',                     
'OTROS GASTOS SIN REQUISITOS (OTROS GASTOS)',                                                              
'GASTOS DE IMAGEN Y LIMPIEZA',                                                              
'OTROS GASTOS INTERCOMPAÑIAS (OTROS GASTOS)',                        
'OTROS GTS SIN REQUISITOS DE PAQUETES',  
'ENTRADAS A PARQUES (OTROS GASTOS)',                                             
'GASTOS PAQ. DE HOTEL (OTROS GASTOS)',                                                              
'GASTOS DE PAQ.BOX LUNCH (OTROS GASTOS)',      
'GASTOS VARIOS DE PAQUETES (OTROS GASTOS)',                                                              
'ACTUALIZACION (VENTAS)',                                                              
'ALIMENTOS A EMPLEADOS (VENTAS)',                                                           
'ARR. DE EQUIPO (VENTAS)',                                                 
'ARR.INMUEBLES PERSONAS FISICAS 10% (VENTAS)',                                                              
'ATENCION A ACCIDENTADOS (VENTAS)',                                                              
'COMPRA DE PELICULAS (VENTAS)',                                                              
'CONS DE ALIM EN PLAZA DED. SIN REQ.(VENTAS)',                                                              
'CUOTAS SINDICALES (VENTAS)',                   
'CUOTAS Y  SUSCRIPCIONES (VENTAS)',                                                              
'DESPENSAS (VENTAS)',                                                              
'DIESEL EN BASE MANTENIMIENTO (VENTAS)',                                                              
'ESTUDIOS DE MERCADO (VENTAS)',                                                              
'FOMENTO DEPORTIVO (VENTAS)',                                                    
'GAS (VENTAS)',                                                              
'GASOLINA EN CARRETERA (VENTAS)',                                                              
'GASTOS DE BOLETOS',                                                              
'GASTOS DORMITORIOS (VENTAS)',                                           
'GASTOS MEDICOS (VENTAS)',                                                              
'GASTOS SINDICATO EMPLEADOS (VENTAS)',                                                              
'GTS DE ACC. DEDUCIBLES SIN REQ. (VENTAS)',                                                              
'GUIAS DE UPS (VENTAS)',                                                              
'INFRACCIONES DE TRANSITO (VENTAS)',                                                              
'MANT. EQ. DE AUDIO Y VIDEO  (VENTAS)',                                                              
'MANT.EQ.RADIO COMUNICACION (VENTAS)',                                                              
'MANT.EQ.RED DE COMUNICACION (VENTAS)',                                                              
'MTTO. DE BAJADAS DE AUTOBUSES (VENTAS)',                                                              
'MULTAS (VENTAS)',                                                              
'PAQUETES COMPUTACIONALES (VENTAS)',                                                             
'PUBLICIDAD EN  RADIO (VENTAS)',                                                              
'PUBLICIDAD EN T.V. (VENTAS)',                                                              
'ROLLOS Y REVELADOS (VENTAS)',                  
'GTS DE VIAJE CON ALGUNOS REQUISITOS (ASIGNABLES)',                                                    
'SEGURO DE VIDA EMPL.SINDICALIZADOS (VENTAS)',                                                              
'SERVICIO DE INTERNET (VENTAS)',                                                              
'SERVICIO DE RED TELEFONICA (VENTAS)',                                                 
'SERVICIO DE SKY (VENTAS)',                                                              
'SERVICIO POSTAL Y TELEGRAFICO (VENTAS)',                                          
'UNIFORMES (VENTAS)',                                                              
'VOLANTES (VENTAS)' ,                                                        
'MANT.MOB.Y EQ.OFICINA (VENTAS)'           
,'CD REFACCIONES ACOND (ASIGNABLES)'      ---FIN            
--REFORMA2014        
,'CUOTAS Y PEAJES SIN REQUISITOS (VENTAS)'        
,'DIESEL EN CARRETERA SIN REQUISITOS (VARIABLES)'        
,'GASTOS DE VIAJE SIN REQUISITOS  (ASIGNABLES)'        
,'GASTOS DE VIAJE SIN REQUISITOS (VENTAS)'     
,'GASTOS VARIOS DED.SIN REQ. (ASIGNABLES)'        
,'GTS VARIOS DEDUCIBLES SIN REQ. (VENTAS)'        
,'GTS VARIOS SIN REQUISITOS (VARIABLES)'        
        ,'GASTOS DE VIAJE SIN REQUISITOS  (ASIGNABLES)'    
        ,'MED.BOTIQUINES (ASIGNABLES)'-- Agregados 13/02/2014 como lo envio Zoralla   
        ,'VARIOS DE SEG.E HIGIENE (ASIGNABLES)'  
        ,'MED. BOTIQUINES (ASIGNABLES)'-- Agregados 13/02/2014 como lo envia el XML 
        ,'DIESEL EN CARRETERAS (VARIABLES)' --RAAM | 21/02/2014
        ,'FLETES Y ACARREOS (ASIGNABLES)' --RAAM | 23/04/2014  
        ,'IVA DE GASTOS NO ACREDITABLE (VENTAS)'	--RAAM | 08/05/2014 
        ,'IVA DE GASTOS NO ACREDITABLE ( VARIABLES)'	--RAAM | 08/05/2014 
        ,'IVA DE GASTOS NO ACREDITABLES (ASIGNABLES)'	--RAAM | 08/05/2014 
        ,'GASOLINA S/V (VENTAS) '	--RAAM | 10/07/2014 
		,'SERVICIO DE CABLE (VENTAS) '	--RAAM | 14/04/2015
		,'GTS VARIOS DEDUCIBLES SIN REQ. (VENTAS)'	--RAAM | 14/04/2015
                                                               
  ) )                                                                       
   Begin                                                                  
    Set @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';                                                   
      
        
          
    Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
    raiserror(@MensajeError,16,1);                                                                  
    return;                                                                  
   End                                                                  
                                                                  
   --Set @subclase = 'DEVOLUCIONES SOBRE VENTAS'                                             
                                                                
  End                                                                  
  Else                         
  Begin                                                                  
   Set @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';                                          
   Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
   raiserror(@MensajeError,16,1);                                                                  
   return;                                                                  
  End                                                                   
                                                                    
 End                                                                  
 Else If(@Mov = 'Solicitud SIVE')                                                                  
 Begin                                                                  
                                                                   
  If(@Usuario = 'SITTI')                                                                  
  Begin                         
                                                                    
   --If(@Concepto <> 'GTS. DE VIAJE CON ALGUNOS REQUISITOS (VENTAS)' and                                                                   
   -- @Concepto <> 'CONSUMO DE ALIMENTOS (VENTAS)' and                                                                   
   -- @Concepto <> 'CONSUMOS DE HERRAMIENTAS (ASIGNABLES)' and                                                                   
   -- @Concepto <> 'CUOTAS Y PEAJES  (VENTAS)' and                                                                   
   -- @Concepto <> 'DIESEL EN CARRETERA C/ALGUNOS REQ. (VARIABLES)' and                                                                   
   -- @Concepto <> 'DIESEL EN CARRETERAS (VARIABLES)' and 
   -- @Concepto <> 'TRANSPORTE (VENTAS)' and                                                                   
   -- @Concepto <> 'UTILES DE ASEO Y LIMPIEZA (ASIGNABLES)' and                                                                   
   -- @Concepto <> 'ACEITES Y GRASAS (VARIABLES)' and                                                                   
   -- @Concepto <> 'CD REFACCIONES MANTTO (VARIABLES)' and                                                                   
   -- @Concepto <> 'GTS. DE IMAGEN CON ALGUNOS REQUISITOS (ASIGNABLES)' and                                                                   
   -- @Concepto <> 'GTS. DE IMAGEN CON ALGUNOS REQUISITOS (VENTAS)' and                                                               
   -- @Concepto <> 'HOSPEDAJE (VENTAS)' and                                                                   
   -- @Concepto <> 'OTROS (ASIGNABLES)' and                                                                   
   -- @Concepto <> 'OTROS IMPUESTOS (VENTAS)' and                                                     
   -- @Concepto <> 'VARIOS (VENTAS)' and                                                                   
   -- @Concepto <> 'GASTOS DE IMAGEN C/ALGUNOS REQUISITOS (VARIABLES)' and                                                                   
   -- @Concepto <> 'GTS VARIOS DEDUCIBLES SIN REQ. (VENTAS)' and                                                                   
   -- @Concepto <> 'LIMPIEZA DE UNIDADES (ASIGNABLES)' and                                                                   
   -- @Concepto <> 'REPARACIONES MENORES  (VARIABLES)')                                                     
   If Exists(Select * From #Partidas Where Not Concepto In (                                                             
  'AGUA PURIFICADA (VENTAS)',                                                                 
       'GTS. DE VIAJE CON ALGUNOS REQUISITOS (VENTAS)',                                                                   
       'CONSUMO DE ALIMENTOS (VENTAS)',                                                           
          'CONSUMO DE ALIMENTOS (ASIGNABLES)',                                                                
       'CONSUMOS DE HERRAMIENTAS (ASIGNABLES)',          
       'CUOTAS Y PEAJES  (VENTAS)',                               
       'HOSPEDAJE (ASIGNABLES)',                                                                    
       'DIESEL EN CARRETERA C/ALGUNOS REQ. (VARIABLES)',                                                                   
       'DIESEL EN CARRETERAS (VARIABLES)',                                         
       'TRANSPORTE (VENTAS)',                                                           
       'UTILES DE ASEO Y LIMPIEZA (ASIGNABLES)',                                                                   
       'ACEITES Y GRASAS (VARIABLES)',                                                                   
     'CD REFACCIONES MANTTO (VARIABLES)',                                                                   
       'GTS. DE IMAGEN CON ALGUNOS REQUISITOS (ASIGNABLES)',                                                                   
       'GTS. DE IMAGEN CON ALGUNOS REQUISITOS (VENTAS)',                           
       'HOSPEDAJE (VENTAS)',                                                                   
       'OTROS (ASIGNABLES)',                  
  'OTROS IMPUESTOS (VENTAS)',                    
       'VARIOS (VENTAS)',                                                                   
'GASTOS DE IMAGEN C/ALGUNOS REQUISITOS (VARIABLES)',             
       'GTS VARIOS DEDUCIBLES SIN REQ. (VENTAS)',                                                                   
       'LIMPIEZA DE UNIDADES (ASIGNABLES)',                                                         
       'REPARACIONES MENORES  (VARIABLES)',                                             
       'TELEFONO CELULAR (ASIGNABLES)',      
    'CD REFACCIONES ACOND (VARIABLES)',                                           
    'ARRENDAMIENTO DE AUTOBUSES (VENTAS)',                                                              
    'GASTOS DE VIAJE CON ALGUNOS REQUISITOS (VARIABLES)',                                                                
       'Cuotas y Peajes (Ventas)',                                                            
       'ACONDICIONAMIENTO DE INMUEBLES (VENTAS)',                                                                  
                                 'Cuotas y Peajes (Administración)',                  
                            'Otros Gastos Intercompañía (Otros Gastos)',                                                                  
                            'Diesel en Carreteras (Variables)',                                                                  
                            'Gastos Varios (Ventas)' ,                                                            
           /*Se agregan conceptos de la lista que tiene ISMAEL VAZQUEZ*/                           
                              'ALIMENTOS DE OPERADORES(ASIGNABLES) ',                                         
                            'GASTOS A COMPROBAR (EGRESOS)',                                                            
'GASTOS A COMPROBAR',                                                            
'REFACCIONES DE ALMACEN (VARIABLES)',                                                            
'CD REFACCIONES MANTTO (VARIABLES)',                                                            
'GTO. PAQ. CAMISETAS',                  
'OT. GTOS NO DEDUCIBLES DE ISR DE PAQUETES',                                                            
'OT. GTOS NO DEDUCIBLES PAQUETES',                                                            
'CD REFACCIONES ACOND (VARIABLES)',                                                            
'CD REFACCIONES ACCID (VARIABLES)',                                                            
'DIESEL EN CARRETERAS (VARIABLES)',                                                            
'DIESEL DE RUTA FUERA DE BASE (VARIABLES)',                                                          
'ACEITES Y GRASAS (VARIABLES)',                                                            
'CONSUMOS DE LLANTAS (VARIABLES)',                                                            
'GASTOS DE VIAJE CON ALGUNOS REQUISITOS (VARIABLES)',                                                            
'GASTOS DE IMAGEN C/ALGUNOS REQUISITOS (VARIABLES)',                                                            
'REPARACIONES MENORES  (VARIABLES)',                                                            
'DIESEL EN CARRETERA C/ALGUNOS REQ. (VARIABLES)',                                          
'MANT.VEHICULOS EN SERVICIO (ASIGNABLES)' ,                                
'OTROS IMPUESTOS (ASIGNABLES)',                       
'LIMPIEZA DE UNIDADES (ASIGNABLES)',                                                            
'TRANSPORTE (ASIGNABLES)',                                                            
'OTROS (ASIGNABLES)',     
'CONSUMOS DE HERRAMIENTAS (ASIGNABLES)',                  
'GTS DE VIAJE CON ALGUNOS REQUISITOS (ASIGNABLES)',                                                            
'CONSUMOS DE TALLER (ASIGNABLES)',                                               
'TELEFONO CELULAR (ASIGNABLES)',                             
'MANT.HERR. Y EQ. DE TALLER (ASIGNABLES)',                                                      
'MANT.MOB.Y EQ.OFICINA (ASIGNABLES)',                                                            
'MANT.VEHICULOS EN SERVICIO (ASIGNABLES)',                                                            
'MANT.EQ.COMPUTACION (ASIGNABLES)',                                                            
'MANT. EQ. DE AUDIO Y VIDEO (ASIGNABLES)',                                                         
'MANTENIMIENTO DE INMUEBLES (ASIGNABLES)',                                     
'UTILES DE ASEO Y LIMPIEZA (ASIGNABLES)',                                                            
'GASTOS MEDICOS (ASIGNABLES)',                                                            
'ALIMENTOS A EMPLEADOS (ASIGNABLES)',                                                            
'SEGUROS Y FIANZAS (ASIGNABLES)',                                                            
'PAPELERIA Y ART.DE OFICINA (ASIGNABLES)',                                                            
'VARIOS (ASIGNABLES)',                                                            
'FUMIGACION DE EDIFICIOS (ASIGNABLES)',                                                            
'VARIOS DE SEG.E HIGIENE (ASIGNABLES)',                                           
'GASOLINA (ASIGNABLES)',                                               
'HONORARIOS MEDICOS A PERS. FISICAS (ASIGNABLES)',         
'HONORARIOS A  OTRAS PERS FIS. 15%  (ASIGNABLES)',                                                            
'OTROS DE CAPACITACION (ASIGNABLES)',                                                            
'ATENCION A ACCIDENTADOS (ASIGNABLES)',                                                            
'REPAR. DE VEHICULOS ACCIDENTADOS (ASIGNABLES)',                                                    
'OTROS GASTOS DE ACCIDENTES (ASIGNABLES)',                                                            
'GASTOS VARIOS (ASIGNABLES)',                                                            
'AGUA PURIFICADA  (ASIGNABLES)',                                                            
'GASTOS DE DORMITORIOS (ASIGNABLES)',                                                            
'SERVICIOS DE VIGILANCIA (ASIGNABLES)',                                          
'GTS DEDUCIBLES SIN REQ. (ASIGNABLES)',                                                            
'GASTOS VARIOS DED.SIN REQ. (ASIGNABLES)',                                                            
'GTS DE VIAJE CON ALGUNOS REQUISITOS. (ASIGNABLES)',                                                            
'GTS. DE IMAGEN CON ALGUNOS REQUISITOS (ASIGNABLES)',                                           
'REP.MENORES CON ALGUNOS REQUISITOS (ASIGNABLES)',                                                            
'GASTOS NO DEDUCIBLES (ASIGNABLES)',                                                            
'CUOTAS Y PEAJES  (VENTAS)',                                                            
'HOSPEDAJE (VENTAS)',                                                            
'TRANSPORTE (VENTAS)',                                                            
'CONSUMO DE ALIMENTOS (VENTAS)',                 
--'ALIMENTOS DE OPERADORES (ASIGNABLES)',                                         
'OTROS  (VENTAS)',                                                            
'ARRENDAMIENTO DE AUTOBUSES (VENTAS)',                                                            
'ARR.INMUEBLES PERSONAS FISICAS 15% (VENTAS)',                          
'ARR.INMUEBLES DE PERS.MORALES (VENTAS)',                                                            
'ENERGIA ELECTRICA (VENTAS)',                                                            
'AGUA POTABLE (VENTAS)',                                                            
'TELEFONOS (VENTAS)',                             
'TELEFONO CELULAR (VENTAS)',                   
'SERVICIO DE CABLE (VENTAS)',                                                            
'MANT.MOB.Y EQ.OFICINA (VENTAS)',                                                    
'MANT.VEHICULOS EN SERVICIO (VENTAS)',                                                            
'MANT.EQ.COMPUTACION (VENTAS)',                                                            
'MANTENIMIENTO DE INMUEBLES (VENTAS)',                                        
'UTILES DE ASEO Y LIMPIEZA (VENTAS)',                                                    
'SERVICIO DE LIMPIEZA (VENTAS)',                                                            
'ACONDICIONAMIENTO DE INMUEBLES (VENTAS)',                                                            
'EVENTOS ESPECIALES (VENTAS)',                                                 
   'IVA DE GASTOS NO ACREDITABLE (VENTAS)',                                                            
'IVA DE GASTOS PRORRATEABLES (VENTAS)',                                                            
'PAPELERIA Y ART.DE OFICINA (VENTAS)',                                                            
'PAPELERIA IMPRESA (VENTAS)',                                                            
'VARIOS (VENTAS)',                                                            
'GASOLINA (VENTAS)',                                                            
'DIESEL EN CARRETERA (VENTAS)',                                                            
'ACEITES Y GRASAS (VENTAS)',                                      
'FLETES Y ACARREOS (VENTAS)',                                               
'PAQUETERIA (VENTAS)',                                                            
'ANUNCIOS EN SECCION AMARILLA (VENTAS)',                                                            
'ASESORIA PUBLICITARIA (VENTAS)',                                                            
'PUBLICIDAD EN PERIODICO (VENTAS)',                                                            
'OTROS MEDIOS DE PUBLICIDAD (VENTAS)',                                                            
'REPARAC.DE VEHICULOS ACCIDENTADOS (VENTAS)',                                                            
'DONATIVOS (GTOS VENTA)',                                                      
'GASTOS VARIOS (VENTAS)',                                                            
'CONSUMO DE ALIMENTOS EN PLAZA (VENTAS)',                                                            
'AGUA PURIFICADA (VENTAS)',                                                            
'SERVICIOS DE VIGILANCIA  (VENTAS)',                                                            
'GTS DEDUCIBLES SIN REQ. (VENTAS)',                                                            
'GTS VARIOS DEDUCIBLES SIN REQ. (VENTAS)',                                                            
'GTS. DE VIAJE CON ALGUNOS REQUISITOS (VENTAS)',                                                            
'GTS. DE IMAGEN CON ALGUNOS REQUISITOS (VENTAS)',                                                            
'REP.MENORES  CON ALGUNOS REQUISITOS (VENTAS)',                                                            
'GTS. NO DED X ISR DE FACILIDADES (VENTAS)',                                                            
'GASTOS NO DEDUCIBLES (VENTAS)',                                                            
'OTROS GASTOS DIVERSOS (OTROS GASTOS)',                                                            
'OTROS GASTOS SIN REQUISITOS (OTROS GASTOS)',                
'GASTOS DE IMAGEN Y LIMPIEZA',                                                            
'OTROS GASTOS INTERCOMPAÑIAS (OTROS GASTOS)',                                                            
'OTROS GTS SIN REQUISITOS DE PAQUETES',                                                            
'ENTRADAS A PARQUES (OTROS GASTOS)',                                                         
'GASTOS PAQ. DE HOTEL (OTROS GASTOS)',                                                            
'GASTOS DE PAQ.BOX LUNCH (OTROS GASTOS)',                                                         
'GASTOS VARIOS DE PAQUETES (OTROS GASTOS)',                
'ACTUALIZACION (VENTAS)',                             
'ALIMENTOS A EMPLEADOS (VENTAS)',                                               
'ARR. DE EQUIPO (VENTAS)',        
'ARR.INMUEBLES PERSONAS FISICAS 10% (VENTAS)',     
'ATENCION A ACCIDENTADOS (VENTAS)',                                                            
'COMPRA DE PELICULAS (VENTAS)',                                                            
'CONS DE ALIM EN PLAZA DED. SIN REQ.(VENTAS)',                                                            
'CUOTAS SINDICALES (VENTAS)',                                                            
'CUOTAS Y  SUSCRIPCIONES (VENTAS)',                                                            
'DESPENSAS (VENTAS)',                                                            
'DIESEL EN BASE MANTENIMIENTO (VENTAS)',                                                            
'ESTUDIOS DE MERCADO (VENTAS)',                                                            
'FOMENTO DEPORTIVO (VENTAS)',                                                            
'GAS (VENTAS)',                                                            
'GASOLINA EN CARRETERA (VENTAS)',                                                            
'GASTOS DE BOLETOS',                                           
'GASTOS DORMITORIOS (VENTAS)',                                                            
'GASTOS MEDICOS (VENTAS)',                      
'GASTOS SINDICATO EMPLEADOS (VENTAS)',                                                            
'GTS DE ACC. DEDUCIBLES SIN REQ. (VENTAS)',                                       
'GUIAS DE UPS (VENTAS)',                                        
'INFRACCIONES DE TRANSITO (VENTAS)',                                                            
'MANT. EQ. DE AUDIO Y VIDEO  (VENTAS)',                                                            
'MANT.EQ.RADIO COMUNICACION (VENTAS)',                                                            
'MANT.EQ.RED DE COMUNICACION (VENTAS)',                                                            
'MTTO. DE BAJADAS DE AUTOBUSES (VENTAS)',                                                            
'MULTAS (VENTAS)',                                                            
'PAQUETES COMPUTACIONALES (VENTAS)',                                                            
'PUBLICIDAD EN  RADIO (VENTAS)',                                                            
'PUBLICIDAD EN T.V. (VENTAS)',                               
'OTROS IMPUESTOS (ASIGNABLES)',                                                           
'ROLLOS Y REVELADOS (VENTAS)',                                                            
'SEGURO DE VIDA EMPL.SINDICALIZADOS (VENTAS)',                                                            
'SERVICIO DE INTERNET (VENTAS)',                                                          
'SERVICIO DE RED TELEFONICA (VENTAS)',                           
'SERVICIO DE SKY (VENTAS)',                                                            
'SERVICIO POSTAL Y TELEGRAFICO (VENTAS)',                                                            
'UNIFORMES (VENTAS)',                                       
'VOLANTES (VENTAS)' ,                                  
'CD REFACCIONES ACOND (ASIGNABLES)'                                  
--REFORMA2014        
,'CUOTAS Y PEAJES SIN REQUISITOS (VENTAS)'        
,'DIESEL EN CARRETERA SIN REQUISITOS (VARIABLES)'        
,'GASTOS DE VIAJE SIN REQUISITOS  (ASIGNABLES)'        
,'GASTOS DE VIAJE SIN REQUISITOS (VENTAS)'        
,'GASTOS VARIOS DED.SIN REQ. (ASIGNABLES)'        
,'GTS VARIOS DEDUCIBLES SIN REQ. (VENTAS)'        
,'GTS VARIOS SIN REQUISITOS (VARIABLES)'       
,'GASTOS DE VIAJE SIN REQUISITOS  (ASIGNABLES)'    
  ,'MED.BOTIQUINES (ASIGNABLES)'-- Agregados 13/02/2014 como lo envio Zoralla   
        ,'VARIOS DE SEG.E HIGIENE (ASIGNABLES)'  
        ,'MED. BOTIQUINES (ASIGNABLES)'-- Agregados 13/02/2014 como lo envia el XML
        ,'DIESEL EN CARRETERAS (VARIABLES)' --RAAM | 21/02/2014
        ,'FLETES Y ACARREOS (ASIGNABLES)' --RAAM | 23/04/2014 
        ,'IVA DE GASTOS NO ACREDITABLE (VENTAS)'	--RAAM | 08/05/2014 
        ,'IVA DE GASTOS NO ACREDITABLE ( VARIABLES)'	--RAAM | 08/05/2014 
        ,'IVA DE GASTOS NO ACREDITABLES (ASIGNABLES)'	--RAAM | 08/05/2014         
        ,'GASOLINA S/V (VENTAS) '	--RAAM | 10/07/2014 
		,'SERVICIO DE CABLE (VENTAS) '	--RAAM | 14/04/2015
		,'GTS VARIOS DEDUCIBLES SIN REQ. (VENTAS)'	--RAAM | 14/04/2015
  ))                                                             
                        
   Begin                                                              
    raiserror('Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.',16,1);                                                            







  
    
      
    return;                                                  
   End                                                                  
                                                                
   Set @subclase = null                                                                  
                                                                     
  End                                                                  
  Else                                                                  
  Begin                                                                  
   raiserror('Usuario no valido. El usuario que indico existe en Intelisis, pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.',16,1);                                                                  
   return;                                                                  
  End                                                                   
                                                                    
 End                                                                  
 Else If(@Mov = 'Solicitud Gto a Comp')                                                                  
 Begin                                                                
 If(@Usuario = 'SITTI')                                                                  
  Begin                                                                  
                                                    
   --If(@Concepto <> 'GASTOS A COMPROBAR')                                                                  
   If Exists (Select * From #partidas where Concepto <> 'GASTOS A COMPROBAR')                                                                  
   Begin                                        Set @MensajeError = 'Concepto no valido. El concepto se valida de acuerdo al movimiento y usuario indicado. Por favor, indique un Concepto valido para esta combinación de movimiento y usuario.';             







  
    
     
        
          
            
              
                
                  
                    
                      
                        
                          
                            
                              
                                         
    Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
    raiserror(@MensajeError,16,1);                                               
    return;                                                              
   End                           
                                                       
  End                                                                  
  Else                                                    
  Begin                                                                  
   Set @MensajeError = 'Usuario no valido. El usuario que indico existe en Intelisis, pero no es uno de los usuarios esperados. Por favor, indique un Usuario valido.';                           
   Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
   raiserror(@MensajeError,16,1);                                                                  
   return;                                                                  
    set @Clase='SIN CLASIFICACION'                                                               
  End                                                             
                                                                    
 End                                                                  
 else                                                                  
 Begin                                                                  
  Set @MensajeError = 'Mov no valido. El movimiento no se encuentra entre los movimientos esperados. Por favor, indique un Movimiento valido.';                                                                  
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                     
  raiserror(@MensajeError,16,1);                                                                  
  return;                                                                  
 End                                                                  
                                                        
                                                                   
                                                                   
 If(@Mov='Pagos Anticipados') --and @Concepto ='ENTRADAS A PARQUES')                                                                  
 Begin                                                                  
  Set @Clase = 'PAGOS ANTICIPADOS';                                                                   
 End                                                 
 Else if(@Mov = 'Solicitud Gasto')                                           
 Begin                                                                  
  Set @Clase = 'GASTOS DE VENTA';                                                                   
  --Update #partidas set Impuestos = 0;                                                                  
 End                                                                  
 Else                                                                  
 Begin                                                                  
  Set @Clase = null;                                                                  
 End                                                                  
                                                                   
                                                                   
                                                                    
 If Exists (select * from #partidas where cantidad <= 0)                                                           
 Begin                                                 
  Set @MensajeError = 'Uno o mas partidas tienen cantidades menores o iguales a cero (Partidas número ';                        
  Set @MensajeError = @MensajeError + (SELECT Top 1 (SELECT CAST(ID as varchar) + ','                                              
                  FROM #partidas p2                                  
                  Where                                                                   
                 cantidad <= 0        
                  ORDER BY ID                                                                   
                  FOR XML PATH('')) AS IDs                                                                  
             FROM #partidas p1);                                               
  Set @MensajeError = SUBSTRING(@MensajeError, 0, Len(@MensajeError));                                                             
  Set @MensajeError = @MensajeError + '). Favor de verificarlas.'                                           
                                                 
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
  raiserror(@MensajeError,16,1)                                                          
  return;                                                                  
 End                                                                  
                                                                   
 If Exists (select * from #partidas where Precio <= 0)                            
 Begin                                                                  
  Set @MensajeError = 'Uno o mas partidas tienen precios menores o iguales a cero (Partidas número ';                                                                  
  Set @MensajeError = @MensajeError + (SELECT Top 1 (SELECT CAST(ID as varchar) + ','                                                                   
                  FROM #partidas p2                                        
                  Where                                      
                 precio <= 0                                                                  
ORDER BY ID                                                                 
                  FOR XML PATH('')) AS IDs                                                                  
             FROM #partidas p1);                                                                    
  Set @MensajeError = SUBSTRING(@MensajeError, 0, Len(@MensajeError));                                                                  
  Set @MensajeError = @MensajeError + '). Favor de verificarlas.'                                                                  
                                      
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
  raiserror(@MensajeError,16,1)                                                                  
  return;                         
 End                    
                                           
 If Exists (select * from #partidas where CentroDeCosto Is Null or rtrim(ltrim(CentroDeCosto)) = '')                                                                  
 Begin                                                 
  Set @MensajeError = 'Uno o mas partidas no tienen centro de costo indicado (Partidas número ';                                                                  
  Set @MensajeError = @MensajeError + (SELECT Top 1 (SELECT CAST(ID as varchar) + ','                                                       
                  FROM #partidas p2                 
                  Where                                                                   
                 CentroDeCosto Is Null or rtrim(ltrim(CentroDeCosto)) = ''                                                                  
                  ORDER BY ID                                                                   
             FOR XML PATH('')) AS IDs                       
             FROM #partidas p1);                                                    
  Set @MensajeError = SUBSTRING(@MensajeError, 0, Len(@MensajeError));                                                                  
  Set @MensajeError = @MensajeError + '). Favor de verificarlas.'                                                                  
                                                                    
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                
  raiserror(@MensajeError,16,1)                                                                  
  return;                                  
End                                                                  
                              
 If Exists (select                                                                   
     *                                                                         from                                                                   
     #partidas p                                                                  
                                                                       
     left join CentroCostos  cc on                                                                  
   cc.CentroCostos = p.CentroDeCosto                                                                  
      where                                                                   
     cc.CentroCostos Is Null)                                                                  
 Begin                                                             
  Set @MensajeError = 'Uno o mas partidas tienen un centro de costo que no fue encontrado en Intelisis (Partidas número ';                                                                  
  Set @MensajeError = @MensajeError + (SELECT Top 1 (SELECT CAST(ID as varchar) + ','                                                                   
                  FROM #partidas p2                                               
                                                                                    
         left join CentroCostos  cc on                                                                  
                 cc.CentroCostos = p2.CentroDeCosto                                                                  
                  where                                                                   
                 cc.CentroCostos Is Null                                                                  
       ORDER BY ID                                                                   
                  FOR XML PATH('')) AS IDs                                                                  
             FROM #partidas p1);                                                   
  Set @MensajeError = SUBSTRING(@MensajeError, 0, Len(@MensajeError));                                                                  
  Set @MensajeError = @MensajeError + '). Favor de verificarlas.'                                                           
                                                                    
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                     
  raiserror(@MensajeError,16,1)                                                                  
  return;                                          
 End                                                                  
                           
 --If(@Concepto Is Null Or rtrim(ltrim(@Concepto)) = '')                                                                   
 if exists (Select                                                    
     *                                                          
      From                              
     #partidas                                                                   
      where                                                                   
     IsNull(Concepto,'') = '')                                                                  
 Begin                                                                  
  Set @MensajeError = 'Uno o mas conceptos, no fueron indicados (partidas sin concepto ';       
  Set @MensajeError = @MensajeError + (SELECT Top 1 (SELECT CAST(ID as varchar) + ','                                                                   
   FROM #partidas p2                                                                                   
                  where   
       IsNull(Concepto,'') = ''                                                                  
                  ORDER BY ID                                                        
                  FOR XML PATH('')) AS IDs                                                                  
             FROM #partidas p1);                                                                    
  Set @MensajeError = SUBSTRING(@MensajeError, 0, Len(@MensajeError));                                                       
  Set @MensajeError = @MensajeError + '). Favor de verificarlos.'                                                                  
                                                                    
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                                  
  raiserror(@MensajeError,16,1);                                                                  
  return;                                                                  
 End
 
  IF EXISTS (SELECT * FROM #partidas AS A WHERE LEN(A.Espacio) > 0 AND LEN(A.Espacio) < 5)
	BEGIN
		SET @MensajeError = 'Uno o mas partidas indican unidades (espacio) con un numero de caracteres diferente a 5 (Partidas número ';
		SET @MensajeError = @MensajeError + (
			SELECT TOP 1 (
					SELECT CAST(ID AS VARCHAR) + ','
					WHERE LEN(ESPACIO) > 0 AND LEN(ESPACIO) < 5
					ORDER BY ID	FOR XML PATH('')) AS IDs
			FROM #partidas p1);
		SET @MensajeError = SUBSTRING(@MensajeError, 0, Len(@MensajeError));
		SET @MensajeError = @MensajeError + '). Favor de verificarlas.';
		EXEC Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;
		RAISERROR(@MensajeError,16,1);
		RETURN;
	END                                                                
                                                                   
 --If Exists (select * from #partidas where IsNull(Referencia,'') <> '' and IsNull(RFC,'') = '')                                                                  
 --Begin                                 
 -- Set @MensajeError = 'Uno o mas partidas tienen Referencias indicadas, pero no su R.F.C. (Partidas número ';                                                       
 -- Set @MensajeError = @MensajeError + (SELECT Top 1 (SELECT CAST(ID as varchar) + ','                                                                   
 --                 FROM #partidas p2                                  
 --      Where                                                                   
 --                IsNull(Referencia,'') <> '' and IsNull(RFC,'') = ''                                                                  
 --                 ORDER BY ID                                                                   
 --                 FOR XML PATH('')) AS IDs                                                        
 --            FROM #partidas p1);                                                                    
 -- Set @MensajeError = SUBSTRING(@MensajeError, 0, Len(@MensajeError));                                                  
 -- Set @MensajeError = @MensajeError + '). Favor de verificarlas.'                                                                  
                            
 -- Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;                                                            
 -- raiserror(@MensajeError,16,1)                                                                 
 -- return;                   
 --End
                                                                 
                                                               
 -- *************************************************************************           
 -- Proceso                                                                  
 -- *************************************************************************                                                                  
                                                                   
 Select                                                                  
  @Importe = Sum(Cantidad * Precio),                                                              
  @Impuestos = Sum(Impuestos)                                                                  
 From                 
  #partidas                                                                  
                                                                   
 Insert Into gasto                                                                  
 (                                                                  
  Empresa,                                   
  Mov,                                                                  
  FechaEmision,                                                            
  Moneda,                                                                  
  TipoCambio,                                                                  
  Usuario,                                                                  
  Observaciones,                                                                  
  Estatus,                                       
  Acreedor,                                                                  
  Vencimiento,                                                                  
  FechaRegistro,                                                                  
  FechaRequerida,                                                                  
  Comentarios,                                                                
  Clase,                                                                  
  subclase,                                                                  
  Importe,                                                                  
  Impuestos,                                                              
  MovAplica,                                                              
  MovAplicaID                                                                  
 )                                                                  
 Values                                   
 (                                                         
  @Empresa,                                                                  
  @Mov,                                                                  
  dbo.fn_quitarhrsmin(@FechaEmision),  --@FechaEmision,                                                                  
  @Moneda,                                                                  
  @TipoCambio,                                                                  
  @Usuario,                                                                  
  @Observaciones,                                                                  
  'SINAFECTAR',                     
  @Proveedor,                                                                  
  DateAdd(dd,5,@FechaEmision),      --cambio a solicitud de SVAM/Érika 10/10/12 2:36 pm                                                            
  GETDATE(),                                                     
@FechaRequerida,                            
  @Comentarios,                                              
  @Clase,                      
  @subclase,                                                                  
  @Importe,                                                                  
  @Impuestos,       
  @Antecedente,                                                            
  @AntecedenteID                                                                  
 )              
                                                                   
Set @RegresoID = Scope_Identity();                                                                  
                                         
 Insert into gastod (ID,Renglon,RenglonSub,Concepto,Fecha,Cantidad,Precio,Importe,Impuestos,ContUso,Referencia,RFCComprobante,Espacio)                                                                  
  Select                                                                   
   ID   = @RegresoID,                                                                  
   Renglon  = 2048 * p.ID,                                                                  
   RenglonSub = 0,                                                                  
   Concepto = Concepto,                                                
 Fecha  =@FechaEmision,                                     
   Cantidad = p.Cantidad,                                                                  
   Precio  = p.Precio,                                                                  
   Importe  = p.Cantidad * p.Precio,                                   Impuestos = p.Impuestos,                                                                  
   ContUso  = p.CentroDeCosto,                                                                 
   Referencia = CASE WHEN rtrim(ltrim(p.Referencia)) = '' Then Null Else p.Referencia End                                                                  
   ,RFCComprobante = p.RFC                                                                  
   ,Espacio = p.Espacio   --Autobus                                                                  
  From                                                            
   #partidas p                                                                  
                                                                   
                   ----*********prov                                                 
  ----Se afecta el gasto                                                              
 Begin Try                                                                         
  EXEC spAfectar 'GAS', @RegresoID, 'AFECTAR', 'Todo', NULL, @Usuario, NULL, 1, @Error OUTPUT, @Mensaje OUTPUT                                                                  
 End Try                                                            
 Begin Catch                                                                         
  SELECT                                                                  
   @Error  = ERROR_NUMBER(),                
   @Mensaje = convert(varchar(20),@RegresoID)+'/'+'(sp ' + Isnull(ERROR_PROCEDURE(),'') + ', ln ' + Isnull(Cast(ERROR_LINE() as varchar),'') + ') ' + Isnull(ERROR_MESSAGE(),'');                                                                  
                                                                     
 End Catch                                                
                                                                 
   ----Validación para regresar error por presupuesto.                                                           
 If(Select Estatus From gasto Where ID = @RegresoID and Mov not in ('Comprobante', 'Solicitud SIVE', 'Solicitud Gasto' )) = 'SINAFECTAR'                             
 Begin                                                                  
                                                                   
  -- Si algo salio mal, hay que revertir el proceso.                                                      
  --Delete from gastod where ID = @RegresoID                                                                  
  --Delete from gasto where ID = @RegresoID                                           
                                                                       
  Set @MensajeCompleto =                                                                   
  CONVERT(varchar(20),@RegresoID)+'/'+   --  'Error al aplicar el movimiento de gasto de Intelisis: ' +                                                                   
   'Error = ' + Cast(IsNull(@Error,-1) as varchar(255)) + ', Mensaje = ' + IsNull(@Mensaje, '')                                                                  
                                               
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error',@MensajeCompleto,@Usuario,@LogParametrosXml;                                                                  
  raiserror(@MensajeCompleto,16,1)                              
  return;                                                                  
                                                   
 End                     
                                        
if(Select Estatus From gasto Where ID = @RegresoID /*and Mov not in ('Comprobante', 'Solicitud SIVE', 'Solicitud Gasto' )*/) = 'SINAFECTAR'                                                                    
 Begin                                                                    
                                                      
  -- Si algo salio mal, hay que revertir el proceso.                                           
  IF @Mov not in   ('Comprobante', 'Solicitud SIVE', 'Solicitud Gasto', 'Gastos a Comprobar' )                                             
  begin                                                              
  --Delete from gastod where ID = @RegresoID                                                                    
  --Delete from gasto where ID = @RegresoID                                                                    
                                                                         
  Set @MensajeCompleto =                                                                     
  CONVERT(varchar(20),@RegresoID)+'/'+                                                    
   'Error al aplicar el movimiento de gasto de Intelisis: ' +                                                                     
   'Error = ' + Cast(IsNull(@Error,-1) as varchar(255)) + ', Mensaje = ' + IsNull(@Mensaje, '')                                                                    
                                                                       
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error',@MensajeCompleto,@Usuario,@LogParametrosXml;                                                                    
  raiserror(@MensajeCompleto,16,1)                                                               
  return;                                          
  end                                
  Else                                               
  begin                                 
                                                     
  Set @MensajeCompleto =                                
  CONVERT(varchar(20),@RegresoID)+'/'+                        
   'Error al aplicar el movimiento de gasto de Intelisis: ' +                                
   'Error = ' + Cast(IsNull(@Error,-1) as varchar(255)) + ', Mensaje = ' + IsNull(@Mensaje, '')                                                                    
                    
  Exec Interfaz_LogsInsertar 'Interfaz_gastoInsertar','Error',@MensajeCompleto,@Usuario,@LogParametrosXml;                                                                    
  raiserror(@MensajeCompleto,16,1)                                                                    
  return;                               
  end                                                               
                                                                     
 End                                                               
                                                                
                                                                   
 -- Que MovID                                                                  
 SET @RegresoMovID = (SELECT                                                                  
       MovID                                                                  
       FROM                                                                  
       gasto                                                                  
       WHERE                                                                      
       ID = @RegresoID)                                                                  
                                                                         
 --                                                               
IF (Select Estatus From gasto Where ID = @RegresoID and Mov='Comprobante' ) ='SINAFECTAR'                                                            
Begin                                                       
  Begin                                                            
      EXEC spAfectar 'GAS', @RegresoID, 'AFECTAR', 'Todo', NULL, 'EYCRUZ', NULL, 1, @Error OUTPUT, @Mensaje OUTPUT                                                            
  End                                                            
  IF (Select Estatus From gasto Where ID = @RegresoID and Mov='Comprobante') ='BORRADOR'                                                            
  Begin                   
      EXEC spCambiarSituacion 'GAS', @RegresoID, 'Autorizado', NULL, 'EYCRUZ', NULL, NULL   --se cambia la situación                                                              
  End                                                            
End                                                            
                                                            
IF (Select Estatus From gasto Where ID = @RegresoID and Mov <>'Comprobante') ='PENDIENTE'                                                            
BEGIN                                                            
  EXEC spCambiarSituacion 'GAS', @RegresoID, 'Autorización', NULL, 'EYCRUZ', NULL, NULL   --se cambia la situación                                                              
END                                                           
                                                            
 IF (Select Mov From gasto Where ID = @RegresoID) ='Solicitud Gto a Comp'                                                            
BEGIN                                                            
update gasto set vencimiento=@FechaRequerida,  clase='SIN CLASIFICACION' where ID=@RegresoID and mov='Solicitud Gto a Comp'                                                             
END                            
                                                       IF (Select Estatus From gasto Where ID = @RegresoID and Mov='Solicitud Gasto' ) ='SINAFECTAR'                                                            
Begin                                                            
  Begin            
      EXEC spAfectar 'GAS', @RegresoID, 'AFECTAR', 'Todo', NULL, 'EYCRUZ', NULL, 1, @Error OUTPUT, @Mensaje OUTPUT                                                            
  End           
 END           
                                                 
 --IF ( (@RegresoMovID IS NULL) OR (RTRIM(LTRIM(@RegresoMovID))='' ))                                                                  
 -- BEGIN                                       
 --   Exec spGeneraMovIdConsecxMov 'GAS',@RegresoID,@RegresoMovID output                    
 -- END                                                                  
 -- *************************************************************************                                                              
 -- Información de Retorno                 
 -- *************************************************************************                                                                  
                                                                  
 Select                                                    
  ID  = @RegresoID,                                                                  
  MovID = @RegresoMovID                                                             
                                                        
IF (Select Estatus From gasto Where ID = @RegresoID and Mov='Comprobante') ='BORRADOR'                                                            
  Begin                                                             
      EXEC spCambiarSituacion 'GAS', @RegresoID, 'Autorizado', NULL, 'EYCRUZ', NULL, NULL   --se cambia la situación                      
  End 
GO
GRANT EXECUTE ON  [dbo].[Interfaz_gastoInsertar] TO [Linked_Svam_Pruebas]
GO
