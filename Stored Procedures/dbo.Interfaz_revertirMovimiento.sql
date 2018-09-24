SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE Procedure [dbo].[Interfaz_revertirMovimiento]  
  
@ID int,  
@Modulo char(5),  
@Usuario char(10)  
as  
 set nocount on    
BEGIN  
Begin  
         EXEC spAfectar @MODULO, @ID, 'CANCELAR', 'Todo', NULL, @Usuario, NULL, 1--, @Error OUTPUT, @Mensaje OUTPUT     
END  
END
GO
