-- atender el incidente de sobreventa en vivo (lo corre el DBA como root)
-- cancela las ventas que se colaron, registra el reembolso y corrige el inventario
USE bd_hm_retail;
SET SQL_SAFE_UPDATES = 0;

START TRANSACTION;

-- 1. bloquear el renglon de la chamarra para que nadie compre mientras se corrige
SET @stock = (SELECT Stock FROM INVENTARIO WHERE ID_Inventario = 128 FOR UPDATE);
SET @sobrantes = GREATEST(-@stock, 0);

-- 2. las ventas que se colaron son las ultimas @sobrantes ventas en linea de la chamarra hoy
--    (la primera compra si alcanzo la pieza y se respeta)
DROP TEMPORARY TABLE IF EXISTS ventas_a_cancelar;
CREATE TEMPORARY TABLE ventas_a_cancelar AS
SELECT ID_Venta, ID_Cliente, Total
FROM (
    SELECT v.ID_Venta, v.ID_Cliente, v.Total,
           ROW_NUMBER() OVER (ORDER BY v.ID_Venta DESC) AS n
    FROM VENTA v
    JOIN DETALLE_VENTA d ON v.ID_Venta = d.ID_Venta
    WHERE d.ID_Producto = 2142 AND v.ID_Sucursal = 1
      AND v.ID_Cliente >= 1000002 AND v.Fecha = CURDATE()
) x
WHERE n <= @sobrantes;

-- 3. a quien hay que llamar y cuanto devolverle
SELECT c.ID_Venta AS Folio, cl.Nombre AS Cliente, cl.Email, cl.Telefono, c.Total AS Monto_A_Reembolsar
FROM ventas_a_cancelar c
JOIN CLIENTE cl ON c.ID_Cliente = cl.ID_Cliente;

-- 4. dejar constancia del reembolso
INSERT INTO REEMBOLSO (ID_Venta, ID_Cliente, Monto, Motivo, Fecha_Hora)
SELECT ID_Venta, ID_Cliente, Total, 'Sobreventa por compras simultaneas: articulo agotado', NOW(3)
FROM ventas_a_cancelar;

-- 5. cancelar las ventas que no debieron pasar
DELETE d FROM DETALLE_VENTA d JOIN ventas_a_cancelar c ON d.ID_Venta = c.ID_Venta;
DELETE v FROM VENTA v JOIN ventas_a_cancelar c ON v.ID_Venta = c.ID_Venta;

-- 6. regresar el inventario a 0 (el trigger lo registra en la bitacora con el usuario root)
UPDATE INVENTARIO SET Stock = Stock + @sobrantes WHERE ID_Inventario = 128;

-- 7. marcar la alerta como atendida
UPDATE ALERTA SET Atendida = 1 WHERE ID_Inventario = 128 AND Atendida = 0;

COMMIT;
DROP TEMPORARY TABLE IF EXISTS ventas_a_cancelar;

-- validar
SELECT ID_Inventario, Stock FROM INVENTARIO WHERE ID_Inventario = 128;

SELECT r.ID_Reembolso, r.ID_Venta AS Folio, c.Nombre AS Cliente, r.Monto, r.Motivo, r.Fecha_Hora
FROM REEMBOLSO r JOIN CLIENTE c ON r.ID_Cliente = c.ID_Cliente
ORDER BY r.ID_Reembolso;

SELECT ID_Auditoria, Usuario, Fecha_Hora, Stock_Anterior, Stock_Nuevo
FROM AUDITORIA_INVENTARIO WHERE ID_Inventario = 128 ORDER BY ID_Auditoria;
