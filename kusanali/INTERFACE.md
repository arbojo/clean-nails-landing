# Kusanali — Webhook Interface

## Arquitectura general

```
Landing (formulario web)
  │
  │  INSERT
  ▼
order_requests (tabla de solicitudes)
  │
  │  AFTER INSERT trigger
  ▼
Edge Function (send-order-event)
  │
  │  event_id + envelope + retry
  ▼
Kusanali
  │
  ├─ /webhook/order-request  (nuevas solicitudes)
  │
  │  1. Validar
  │  2. Asignar vendedor
  │  3. Tracking
  │  4. Calcular ruta
  │  5. Convertir → INSERT en orders
  │  6. Customer Success (si support_opt_in)
  │
  └─ /webhook/order-status  (cambios de estado logístico)
      │
      1. runLogisticsOnlyFlow(order)
      2. runCustomerSuccessFlow(order) si support_opt_in
```

## Endpoints

| Endpoint | Evento | Propósito |
|----------|--------|-----------|
| `POST /webhook/order-request` | `ORDER_REQUEST_CREATED` | Nueva solicitud desde landing |
| `POST /webhook/order-status` | `ORDER_STATUS_CHANGE` | Cambio de estado en orders |

## Headers

| Header          | Value              | Required |
|-----------------|--------------------|----------|
| Content-Type    | application/json   | yes      |
| Authorization   | Bearer <TOKEN>     | yes      |

---

## 1. ORDER_REQUEST_CREATED

### Envelope

```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "type": "ORDER_REQUEST_CREATED",
  "order_request": {
    "id": "uuid",
    "customer_name": "string",
    "phone": "string",
    "city": "string",
    "product_name": "string",
    "total": 599.00,
    "support_opt_in": true,
    "metadata": {
      "product": {
        "severity": "mild"
      },
      "landing": {
        "version": "v1",
        "campaign": ""
      }
    }
  },
  "timestamp": "2026-07-05T20:00:00.000Z"
}
```

### Flujo Kusanali

1. Validar `event_id` en `event_log` (idempotencia)
2. Si existe → `return 200`
3. Insertar `event_log` con `success = false`
4. Validar datos del cliente
5. Asignar vendedor/route
6. Crear registro en `orders` con datos convertidos
7. Actualizar `order_requests.status = 'converted'`
8. Si `support_opt_in = true` → iniciar flujo Customer Success
9. Actualizar `event_log` con `success = true`

### Mapeo order_requests → orders

| order_requests     | orders          |
|--------------------|-----------------|
| `customer_name`    | `cliente`       |
| `phone`            | `numero`        |
| `street`           | `direccion`     |
| `colony`           | `colonia`       |
| `city`             | `municipio`     |
| `state`            | `estado`        |
| `zip`              | `cp`            |
| `references`       | `referencias`   |
| `product_name`     | `producto`      |
| `quantity`         | `cantidad`      |
| `total`            | `pago`          |
| `support_opt_in`   | `support_opt_in`|

---

## 2. ORDER_STATUS_CHANGE

### Envelope

```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "type": "ORDER_STATUS_CHANGE",
  "order": {
    "id": "uuid",
    "name": "string",
    "phone": "string",
    "city": "string",
    "status": "new | confirmed | assigned | in_route | delivered",
    "support_opt_in": true
  },
  "timestamp": "2026-07-05T20:00:00.000Z"
}
```

### Regla crítica

```
if (!order.support_opt_in) {
  runLogisticsOnlyFlow(order)
  return
}

runCustomerSuccessFlow(order)
```

#### `runLogisticsOnlyFlow(order)`

Solo mensajes logísticos — SIN customer success:

| Status      | Message |
|-------------|---------|
| `new`       | Tu pedido de Clean Nails ha sido registrado. |
| `confirmed` | Tu pedido ha sido confirmado. |
| `in_route`  | Tu Clean Nails va en camino. |
| `delivered` | Tu pedido ha sido entregado. |

#### `runCustomerSuccessFlow(order)`

Flujo completo — logística + acompañamiento 21 días:

| Status      | Message |
|-------------|---------|
| `new`       | Tu pedido de Clean Nails ha sido registrado. |
| `confirmed` | Tu pedido ha sido confirmado. |
| `in_route`  | Tu Clean Nails va en camino. |
| `delivered` | Tu pedido ha sido entregado 🎉 Comienza tu programa de 21 días con tu dispositivo. |

Además, disparar eventos internos de Customer Success:
- Onboarding día 0
- Recordatorio día 1
- Seguimiento rutina
- Refuerzo constancia
- Cierre día 21

---

## Idempotencia (OBLIGATORIO)

### event_log table

```sql
CREATE TABLE event_log (
  event_id TEXT PRIMARY KEY,
  order_id TEXT,
  event_type TEXT NOT NULL,
  status TEXT NOT NULL,
  payload JSONB,
  success BOOLEAN DEFAULT false,
  error TEXT,
  processed_at TIMESTAMPTZ DEFAULT now()
);
```

### Flujo genérico

1. Recibir evento
2. Buscar `event_id` en `event_log`
3. Si existe → `return 200` (ignorar, ya procesado)
4. Si no existe → insertar registro con `success = false`
5. Ejecutar flujo según `event_type`
6. Actualizar registro: `success = true` (o guardar error si falló)

---

## Observabilidad

Loggear en cada evento:

```
event_id=<uuid> type=<event_type> source_id=<uuid> support_opt_in=<bool> timestamp=<ISO> result=success|failure flow=logistics|customer_success|conversion
```

En caso de error, incluir el mensaje de error en `event_log.error`.

---

## Seguridad

- Validar `Authorization: Bearer <TOKEN>` en cada request
- Rechazar con `401` si el token no es válido o falta

---

## Próximos pasos (arquitectura futura)

Separar `event_type` en dos familias:

| Tipo | Ámbito |
|------|--------|
| `ORDER_REQUEST_CREATED` | Solicitud web |
| `ORDER_CREATED` | Logística |
| `ORDER_CONFIRMED` | Logística |
| `ORDER_DELIVERED` | Logística |
| `CS_ONBOARDING_START` | Customer Success |
| `CS_CHECKIN_DAY_7` | Customer Success |
| `CS_CLOSURE_DAY_21` | Customer Success |

Esto permite escalar a CRM real sin mezclar pipelines.
