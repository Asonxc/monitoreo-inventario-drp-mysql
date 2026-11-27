-- consultas de deteccion y medicion del dano (pasos del DRP)
USE bd_hm_retail;

-- 1. alertas generadas por el trigger
SELECT * FROM ALERTA ORDER BY Fecha_Hora DESC;

-- 2. inventario con stock negativo
SELECT i.ID_Inventario, s.Nombre AS Sucursal, p.Nombre AS Producto, i.Stock
FROM INVENTARIO i
JOIN SUCURSAL s ON i.ID_Sucursal = s.ID_Sucursal
JOIN PRODUCTO p ON i.ID_Producto = p.ID_Producto
WHERE i.Stock < 0;

-- 3. bitacora del producto afectado: quien, cuando, de cuanto a cuanto
SELECT ID_Auditoria, Usuario, Fecha_Hora, Stock_Anterior, Stock_Nuevo
FROM AUDITORIA_INVENTARIO
WHERE ID_Inventario = 128
ORDER BY Fecha_Hora;

-- 4. ventas en linea de ese producto el dia de hoy (cuales se colaron)
SELECT v.ID_Venta, c.Nombre AS Cliente, v.Fecha, v.Total, d.Cantidad, d.Precio_Unitario
FROM VENTA v
JOIN CLIENTE c ON v.ID_Cliente = c.ID_Cliente
JOIN DETALLE_VENTA d ON v.ID_Venta = d.ID_Venta
WHERE v.ID_Cliente >= 1000002 AND d.ID_Producto = 2142 AND v.Fecha = CURDATE()
ORDER BY v.ID_Venta;

-- 5. dinero comprometido: piezas vendidas de mas y su valor
SELECT -i.Stock AS Piezas_De_Mas, -i.Stock * p.Precio AS Monto_A_Reembolsar
FROM INVENTARIO i
JOIN PRODUCTO p ON i.ID_Producto = p.ID_Producto
WHERE i.ID_Inventario = 128 AND i.Stock < 0;

-- 6. sesiones conectadas a la base en este momento
SHOW PROCESSLIST;
