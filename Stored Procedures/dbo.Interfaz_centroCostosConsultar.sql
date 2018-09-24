SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE Procedure [dbo].[Interfaz_centroCostosConsultar] --'SITTI'  
 @Usuario char(10)  
As  
  
 -- *************************************************************************  
 -- Variables  
 -- *************************************************************************  
   
 Declare @LogParametrosXml Xml;  
 Set @LogParametrosXml =   
  (select   
   @Usuario   as 'Usuario'  
  For Xml Path('Parametros'));  
   
 Exec Interfaz_LogsInsertar 'Interfaz_centroCostosConsultar','Consulta','',@Usuario,@LogParametrosXml;  
  
 Declare @mensajeError   varchar(max)  
   
 Create Table #result  
 (  
  CentroCostos char(20),  
  Descripcion  varchar(100)  
 )  
  
 -- *************************************************************************  
 -- Validaciones  
 -- *************************************************************************  
   
 If(@Usuario Is Null Or rtrim(ltrim(@Usuario)) = '')   
 Begin  
  Set @MensajeError = 'Usuario no indicado. Por favor, indique un Usuario.';  
  Exec Interfaz_LogsInsertar 'Interfaz_centroCostosConsultar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;  
  raiserror(@MensajeError,16,1);  
  return;  
 End  
   
   
 If Not Exists(select * from Usuario where rtrim(ltrim(Usuario)) = rtrim(ltrim(@Usuario)))   
 Begin  
  Set @MensajeError = 'Usuario no encontrado. Por favor, indique un Usuario valido de Intelisis.';  
  Exec Interfaz_LogsInsertar 'Interfaz_centroCostosConsultar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;  
  raiserror(@MensajeError,16,1);  
  return;  
 End  
   
 -- *************************************************************************  
 -- Proceso  
 -- *************************************************************************  
   
 If(@Usuario = 'SITTI')  
 Begin  
   
  Insert Into #result  
   Select   
    CentroCostos,  
    Descripcion  
   From   
    CentroCostos  
   Where  
    Descripcion like '%turis%'  or Descripcion like '%(VE)%'
   
 End  
   
 -- *************************************************************************  
 -- Información de Retorno  
 -- *************************************************************************  
   
 Select   
  CentroCostos,  
  Descripcion  
 From   
  #result  
GO
GRANT EXECUTE ON  [dbo].[Interfaz_centroCostosConsultar] TO [Linked_Svam_Pruebas]
GO
