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
```

---

## Requisitos

- **Python:** 3.10 o superior
- **Base de datos:** MySQL Server 8.0
- **Dependencias de Python:**

```bash
pip install flask mysql-connector-python
```

---

## Arquitectura de Base de Datos y DRP

### Restauración y scripts operativos (`sql/`)

1. **`respaldo_inicial_antes_demo.sql`:** Restaura la base `bd_hm_retail` (8 tablas, con `DETALLE_VENTA` particionada por rango), datos iniciales, llaves, índices, el usuario con privilegios mínimos `app_tienda` y el inventario de prueba (`ID_Inventario = 128` con 1 pieza disponible).
2. **`07_deteccion.sql`:** Consulta las alertas activas, registros con stock negativo, movimientos en `AUDITORIA_INVENTARIO` y ventas vinculadas al incidente.
3. **`09_monitoreo_en_vivo.sql`:** Inspecciona las sesiones de `app_tienda`, bloqueos activos en `sys.innodb_lock_waits`, stock actual y alertas recientes.
4. **`10_atender_incidente.sql`:** Ejecuta en una transacción atómica la remediación del incidente: cancela las ventas excedentes, registra el reembolso en `REEMBOLSO`, restablece el stock a `0` y marca la alerta como atendida.
5. **`11_reponer_pieza.sql`:** Incrementa en 1 unidad el inventario `128` para validar el flujo correcto con control de concurrencia.

### Seguridad y principio de menor privilegio

La aplicación web se conecta exclusivamente mediante el usuario `app_tienda@localhost`, restringido a:
- `SELECT` en toda la base de datos.
- `INSERT` únicamente en `CLIENTE`, `VENTA` y `DETALLE_VENTA`.
- `UPDATE` únicamente en `INVENTARIO` y `ALERTA`.

Al no contar con permisos de borrado (`DELETE`), las tareas administrativas de remediación (`10_atender_incidente.sql`) se ejecutan bajo supervisión como `root`.

### Auditoría automática mediante Trigger

El trigger `audita_inventario_update` (`AFTER UPDATE` sobre `INVENTARIO`) registra automáticamente cualquier cambio de stock en `AUDITORIA_INVENTARIO` capturando el valor anterior, el nuevo valor, el usuario exacto mediante `USER()` (en lugar de `CURRENT_USER()` para identificar al ejecutor real y no al *definer*) y marca de tiempo con milisegundos `NOW(3)`. Si el nuevo stock es menor a `0`, genera automáticamente un registro `STOCK_NEGATIVO` en `ALERTA`.

---

## Control de Concurrencia (`POST /api/comprar`)

El comportamiento de compra se alterna desde `demo/config.ini` mediante la bandera `control_concurrencia`:

- **`control_concurrencia = no` (`comprar_sin_control`):** Lee el stock sin bloqueo, simula el tiempo de procesamiento de pago (`tiempo_pago` segundos) y descuenta inventario. Si dos peticiones concurrentes leen `Stock = 1` dentro de esa ventana, ambas completan la venta y dejan el inventario en `-1`.
- **`control_concurrencia = si` (`comprar_con_control`):** Inicia una transacción explícita (`START TRANSACTION`) y bloquea el registro mediante `SELECT ... FOR UPDATE OF i`. La segunda petición queda en espera hasta el `COMMIT` de la primera; al leer `Stock = 0`, rechaza la operación devolviendo HTTP `409` (*artículo agotado*).

---

## Configuración y ejecución

### 1. Configurar `demo/config.ini`

Completa las credenciales locales antes de iniciar el servidor (reiniciar `app.py` tras cualquier cambio):

| Sección | Clave | Descripción |
| :--- | :--- | :--- |
| `mysql` | `host`, `user`, `password`, `database` | Credenciales de conexión (por defecto `app_tienda` en `localhost`). |
| `tienda` | `sucursal`, `empleado`, `cliente` | IDs operativos de sucursal (`1`), empleado en línea y cliente base. |
| `tienda` | `tiempo_pago` | Latencia simulada de cobro en segundos para reproducir cruces de compra. |
| `tienda` | `control_concurrencia` | `no` (vulnerable a condición de carrera) / `si` (bloqueo `FOR UPDATE`). |
| `empresa` | `nombre` | Nombre desplegado en el monitor y en notificaciones. |
| `correo` | `usuario`, `contrasena_app`, `destinatarios` | Credenciales SMTP de Gmail (opcional; si se omite, solo opera el monitor web). |

### 2. Ejecutar la aplicación web

```bash
cd demo
python app.py
```

- **Tienda:** `http://localhost:5000`
- **Tienda en modo demo (disparo simultáneo de 2 compras):** `http://localhost:5000/?demo=1`
- **Monitor en tiempo real:** `http://localhost:5000/monitor`

*(Opcional) Para pruebas desde dispositivos móviles fuera de la red local:*
```bash
cloudflared tunnel --url http://localhost:5000
```

### 3. Prueba aislada de concurrencia en consola

El script `prueba_inventario_negativo.py` crea una base temporal (`hm_pruebas`) y lanza hilos concurrentes sin necesidad de levantar el servidor web:

```bash
cd demo
python prueba_inventario_negativo.py <contraseña_de_root>
```

---

## Endpoints de la API

| Ruta | Método | Descripción |
| :--- | :--- | :--- |
| `/` | `GET` | Vista de la tienda (`?demo=1` habilita el botón de compra doble simultánea). |
| `/monitor` | `GET` | Panel de monitoreo de base de datos, bloqueos y alertas. |
| `/api/productos` | `GET` | Catálogo de productos con precios, atributos y stock actual. |
| `/api/comprar` | `POST` | Procesa una orden (`200` con folio de venta o `409` si no hay existencias). |
| `/api/estado` | `GET` | Telemetría de MySQL, modo activo, inventario, últimas 8 alertas, bitácora y reembolsos. |
