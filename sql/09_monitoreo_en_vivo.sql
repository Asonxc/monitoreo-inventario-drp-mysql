-- monitoreo en vivo desde Workbench (correr como root durante la demo)
USE bd_hm_retail;

-- 1. conexiones de la tienda en linea en este momento (una por cada compra)
SELECT ID AS Conexion, USER AS Usuario, HOST AS Origen, COMMAND AS Comando,
       TIME AS Segundos, STATE AS Estado, INFO AS Consulta
FROM information_schema.PROCESSLIST
WHERE USER = 'app_tienda'
ORDER BY ID;

-- 2. compras esperando a que otra libere el renglon (solo pasa con control_concurrencia = si)
SELECT waiting_pid AS Conexion_Esperando, blocking_pid AS Conexion_Que_Bloquea,
       wait_age AS Esperando_Desde, locked_table AS Tabla, waiting_query AS Consulta
FROM sys.innodb_lock_waits;

-- 3. stock de la chamarra (la ultima pieza)
SELECT i.ID_Inventario, p.Nombre AS Producto, s.Nombre AS Sucursal, i.Stock
FROM INVENTARIO i
JOIN PRODUCTO p ON i.ID_Producto = p.ID_Producto
JOIN SUCURSAL s ON i.ID_Sucursal = s.ID_Sucursal
WHERE i.ID_Inventario = 128;

-- 4. bitacora del trigger: quien cambio el stock y cuando (con milisegundos)
SELECT ID_Auditoria, Usuario, Fecha_Hora, Stock_Anterior, Stock_Nuevo
FROM AUDITORIA_INVENTARIO
WHERE ID_Inventario = 128
ORDER BY ID_Auditoria;

-- 5. alertas generadas y si ya se mando el correo
SELECT ID_Alerta, Tipo, Descripcion, Fecha_Hora,
       IF(Notificada = 1, 'correo enviado', 'pendiente') AS Correo
FROM ALERTA
ORDER BY ID_Alerta;

-- 6. ventas en linea de hoy con el nombre de cada cliente
SELECT v.ID_Venta AS Folio, c.Nombre AS Cliente, p.Nombre AS Producto, v.Total
FROM VENTA v
JOIN CLIENTE c ON v.ID_Cliente = c.ID_Cliente
JOIN DETALLE_VENTA d ON v.ID_Venta = d.ID_Venta
JOIN PRODUCTO p ON d.ID_Producto = p.ID_Producto
WHERE v.ID_Cliente >= 1000002 AND v.Fecha = CURDATE()
ORDER BY v.ID_Venta;
