# Sistema de Monitoreo de Inventario, Concurrencia y DRP (Velté / H&M Retail)

Proyecto integral de administración de bases de datos y desarrollo backend que implementa un **Plan de Recuperación ante Desastres (DRP)**, control de concurrencia transaccional y monitoreo en tiempo real sobre **MySQL 8.0** y **Python (Flask)**.

El sistema simula una tienda en línea conectada a la base de datos `bd_hm_retail` e incluye tres componentes principales:
- **Tienda web en Flask:** Catálogo de ocho productos de la sucursal 1 con dos modos de operación: uno vulnerable a condiciones de carrera (*race conditions*) que permite inventario negativo (`-1`), y otro corregido mediante bloqueos pesimistas (`SELECT ... FOR UPDATE`).
- **Panel de monitoreo en tiempo real:** Dashboard web que consulta el estado del servidor, bloqueos de InnoDB, bitácoras y alertas cada 2 segundos.
- **Servicio de alertas automatizadas:** Hilo en segundo plano en Python que detecta anomalías de inventario (`STOCK_NEGATIVO`) generadas por *triggers* en MySQL y envía notificaciones por correo electrónico.

---

## Estructura del repositorio

```text
├── README.md
├── docs/
│   └── Velté_DRP.pdf                   Plan de Recuperación ante Desastres (DRP) y documentación técnica
├── sql/
│   ├── respaldo_inicial_antes_demo.sql Respaldo completo de estructura, datos, llaves y triggers de bd_hm_retail
│   ├── 07_deteccion.sql                Consultas de detección de alertas, stock negativo y bitácora
│   ├── 09_monitoreo_en_vivo.sql        Supervisión de conexiones activas y bloqueos (sys.innodb_lock_waits)
│   ├── 10_atender_incidente.sql        Transacción de remediación: cancelación, reembolso y ajuste de stock
│   └── 11_reponer_pieza.sql            Reposición de inventario para pruebas del modo con control de concurrencia
└── demo/
    ├── app.py                          Servidor Flask: tienda, monitor, API REST y demonio de alertas por correo
    ├── config.ini                      Parámetros de conexión a MySQL, modo de concurrencia y SMTP
    ├── prueba_inventario_negativo.py   Prueba multihilo en consola de la condición de carrera
    ├── templates/
    │   ├── tienda.html                 Interfaz de la tienda en línea
    │   └── monitor.html                Interfaz del panel de monitoreo
    └── static/
        ├── tienda.js / tienda.css      Lógica de compra y simulación de peticiones simultáneas
        ├── monitor.js / monitor.css    Actualización asíncrona cada 2 s desde /api/estado
        ├── prendas.js                  Gráficos SVG para productos sin fotografía
        ├── img/<ID_Producto>.jpg       Imágenes del catálogo
        └── *.png                       Identidad visual (incrustada también en alertas HTML)
