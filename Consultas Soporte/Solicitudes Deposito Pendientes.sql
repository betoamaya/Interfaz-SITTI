SELECT c.ID,
       c.Mov,
       c.MovID,
       c.Estatus,
       c.Importe + c.Impuestos AS Monto,
       c.FechaEmision,
       c2.FechaTimbrado,
       cii.IdCFD,
       cii.Activo AS 'Activo SITTI',
       p.Folio AS 'Folio SITTI',
       p.FechaCancelacion AS 'Fecha Cancelacion SITTI'
FROM dbo.Cxc AS c
    INNER JOIN dbo.CFD AS c2
        ON c2.ModuloID = c.ID
           AND c2.Modulo = 'CXC'
    INNER JOIN GTPSITTIDB.sitti.dbo.CFDIntelisisInfo AS cii
        ON cii.IdIntelisis = c.ID
    INNER JOIN GTPSITTIDB.sitti.dbo.Pagos AS p
        ON p.IdCFD = cii.IdCFD
WHERE c.MovID IN (
                     SELECT
                         (
                             SELECT CASE
                                        WHEN mf.Omovid = 'TVE140655' THEN
                                            'TVE140656'
                                        ELSE
                                            mf.OMovID
                                    END
                         )
                     FROM Cxc AS A
                         INNER JOIN dbo.Dinero AS d
                             ON d.MovID = A.OrigenID
                         INNER JOIN dbo.MovFlujo AS mf
                             ON mf.DID = d.ID
                                AND mf.DMovID = d.MovID
                     WHERE A.Mov IN ( 'Nota Credito SIVE', 'Nota Credito TransIn', 'Solicitud Deposito' )
                           AND A.Empresa = 'TUN'
                           AND A.Usuario = 'SITTI'
                           AND A.Estatus = 'PENDIENTE'
                           AND A.FechaEmision
                           BETWEEN GETDATE() - 60 AND GETDATE() - 1
                 )
ORDER BY c.FechaEmision;