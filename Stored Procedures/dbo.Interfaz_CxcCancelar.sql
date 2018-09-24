SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE procedure [dbo].[Interfaz_CxcCancelar]  
--@Anticipo int,
@ID int,  
@USUARIO varchar(20)  
AS  
 BEGIN  
  
 set nocount on  
 -- *************************************************************************  
 -- Variables  
 -- *************************************************************************   
    --  
    Declare @Deposito int
    Declare   
     @mensajeError varchar(max)  
     ,@MensajeCompleto varchar(max)  
    --  
    Declare @LogParametrosXml Xml;  
     Set @LogParametrosXml =   
 (select   
  @ID   as 'ID',  
  @USUARIO as 'Usuario'  
  For Xml Path('Parametros'));  
     --   
     Exec Interfaz_LogsInsertar 'Interfaz_CxcCancelar','Inserción','',@Usuario,@LogParametrosXml;  
    --   
 -- *************************************************************************  
 -- proceso 
 -- *************************************************************************       
    --declare @id int
--set @id=964

 IF (select Estatus from cxc where id=@id)='Concluido'
 select
     @id=DID from movflujo where oid=@id and omodulo='CXC' and dmodulo='cxc' and dmov='cfd Aplicacion'
Select @id

set @deposito=@id
  --  Solicitud Deposito  
  --set @Deposito=@Id+1
  IF EXISTS (SELECT 1 FROM CXC WHERE ID = @Deposito and mov='Solicitud Deposito') --AND ESTATUS ='CONCLUIDO')  
   BEGIN  
   
        Exec spAfectar 'CXC', @id, 'CANCELAR', 'Todo', NULL, @USUARIO  
        Exec spAfectar 'CXC', @Deposito, 'CANCELAR', 'Todo', NULL, @USUARIO
        Exec spAfectar 'DIN', @Deposito, 'CANCELAR', 'Todo', NULL, @USUARIO
		
      END  
     ELSE  
      BEGIN  
        Set @MensajeError = 'El ID:'+ Cast (@id as Varchar(5)) +'no existe en el módulo CXC, favor de verificarlo.' ;  
     Exec Interfaz_LogsInsertar 'Interfaz_cxcCancelar','Error de Validación',@MensajeError,@Usuario,@LogParametrosXml;  
     raiserror(@MensajeError,16,1);  
     return;  
      END   
   END  
  
 -- *************************************************************************  
 -- Información de Retorno  
 -- *************************************************************************     
  --  
  SELECT ID = @ID  
        ,ESTATUS = (SELECT ESTATUS FROM CXC WHERE ID = @ID  )  

GO
