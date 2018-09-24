SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
  
CREATE Procedure [dbo].[Interfaz_TIActualizar]        
 @ID    int,  ---De ventas, el cfd origen      
 @Usuario  char(10),        
 @Referencia  varchar(50),        
 @Cliente  char(10)        
As        
        
 set nocount on        
         
 -- *************************************************************************        
 -- Variables        
 -- *************************************************************************        
         
 Declare @LogParametrosXml Xml;        
 Set @LogParametrosXml =         
  (select         
   @ID    as 'ID',        
   @Usuario  as 'Usuario',        
   @Referencia  as 'Referencia',        
   @Cliente  as 'Cliente'        
  For Xml Path('Parametros'));        
         
 Exec Interfaz_LogsInsertar 'Interfaz_TIActualizar','Actualización','Actualización',@Usuario,@LogParametrosXml;        
         
 Declare @mensajeError   varchar(max)        
         
 -- *************************************************************************        
 -- Validaciones        
 -- *************************************************************************        
         
 If(@ID Is Null)         
 Begin        
  Set @MensajeError = 'ID no indicado. Por favor, indique un ID.';        
  Exec Interfaz_LogsInsertar 'Interfaz_TIActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;        
  raiserror(@MensajeError,16,1);        
  return;        
 End        
          
 If Not Exists(select * from Venta where ID = @ID)         
 Begin        
  Set @MensajeError = 'ID no encontrado. Por favor, indique un ID valido de Intelisis.';        
  Exec Interfaz_LogsInsertar 'Interfaz_TIActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;        
  raiserror(@MensajeError,16,1);        
  return;        
 End        
         
 --If (select Estatus from cxc where ID = @ID) = 'CONCLUIDO'        
 --Begin        
 -- Set @MensajeError = 'ID indicado ya se encuentra concluido. Por favor, indique un ID que no este concluido.';        
 -- Exec Interfaz_LogsInsertar 'Interfaz_cxcActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;        
 -- raiserror(@MensajeError,16,1);        
 -- return;        
 --End        
         
 If(@Usuario Is Null Or rtrim(ltrim(@Usuario)) = '')         
 Begin        
  Set @MensajeError = 'Usuario no indicado. Por favor, indique un Usuario.';        
  Exec Interfaz_LogsInsertar 'Interfaz_TIActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;        
  raiserror(@MensajeError,16,1);        
  return;        
 End        
          
 If Not Exists(select * from Usuario where rtrim(ltrim(Usuario)) = rtrim(ltrim(@Usuario)))         
 Begin        
  Set @MensajeError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';        
  Exec Interfaz_LogsInsertar 'Interfaz_TIActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;        
  raiserror(@MensajeError,16,1);        
  return;        
 End        
         
 If Not Exists(select * from Venta where ID = @ID and rtrim(ltrim(Usuario)) = rtrim(ltrim(@Usuario)))         
 Begin        
  Set @MensajeError = 'Usuario indicado no corresponde al ID. Por favor, indique un Usuario valido para este ID, o indique un ID que pertenezca a este usuario.';        
  Exec Interfaz_LogsInsertar 'Interfaz_TIActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;        
  raiserror(@MensajeError,16,1);        
  return;        
 End        
          
 If(@Cliente Is Null Or rtrim(ltrim(@Cliente)) = '')         
 Begin        
  Set @MensajeError = 'Cliente no indicado. Por favor, indique un Cliente.';        
  Exec Interfaz_LogsInsertar 'Interfaz_TIActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;        
  raiserror(@MensajeError,16,1);        
  return;        
 End        
         
 If Not Exists(select * from Venta where ID = @ID and rtrim(ltrim(Cliente)) = rtrim(ltrim(@Cliente)))         
 Begin        
  Set @MensajeError = 'Cliente indicado no corresponde al ID. Por favor, indique un Cliente valido para este ID, o indique un ID que pertenezca a este cliente.';        
  Exec Interfaz_LogsInsertar 'Interfaz_TIActualizar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;        
  raiserror(@MensajeError,16,1);        
  return;        
 End        
           
           
   Declare @cxcID int      
   Declare @Empresa  char(5)      
         
     Set @Empresa= (select Empresa from Venta where ID=@ID)      
   set @CxcID= (select DID  from MovFlujo  where OID=@Id and OModulo='VTAS' and Empresa= @Empresa AND DModulo='CXC')      
         
 -- *************************************************************************        
 -- Proceso        
 -- *************************************************************************        
         
 Update Venta Set        
  Referencia = @Referencia        
 Where        
  ID = @ID        
         
   Update Cxc Set        
  Referencia = @Referencia        
 Where        
  ID = @CxcID        
 -- *************************************************************************        
 -- Información de Retorno        
 -- *************************************************************************
GO
GRANT EXECUTE ON  [dbo].[Interfaz_TIActualizar] TO [Linked_Svam_Pruebas]
GO
