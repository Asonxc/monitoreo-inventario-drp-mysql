-- el almacen repone una pieza de la chamarra para comprobar la version corregida
USE bd_hm_retail;

UPDATE INVENTARIO SET Stock = Stock + 1 WHERE ID_Inventario = 128;

SELECT ID_Inventario, Stock FROM INVENTARIO WHERE ID_Inventario = 128;
