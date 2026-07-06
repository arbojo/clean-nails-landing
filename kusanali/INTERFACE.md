# Kusanali — Webhook Interface

## Endpoint

```
POST /webhook/order-status
```

## Headers

| Header          | Value              | Required |
|-----------------|--------------------|----------|
| Content-Type    | application/json   | yes      |
| Authorization   | Bearer <TOKEN>     | yes      |

## Event Envelope

Payload que llega desde la Edge Function de Supabase:

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

## Regla crítica

Antes de iniciar cualquier flujo, verificar `support_opt_in`:

```
if (!order.support_opt_in) {
  runLogisticsOnlyFlow(order)
  return
}

runCustomerSuccessFlow(order)
```

### `runLogisticsOnlyFlow(order)`

Solo mensajes logísticos — SIN customer success:

| Status      | Message |
|-------------|---------|
| `new`       | Tu pedido de Clean Nails ha sido registrado. |
| `confirmed` | Tu pedido ha sido confirmado. |
| `in_route`  | Tu Clean Nails va en camino. |
| `delivered` | Tu pedido ha sido entregado. |

### `runCustomerSuccessFlow(order)`

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

## Idempotencia (OBLIGATORIO)

### event_log table

```sql
CREATE TABLE event_log (
  event_id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL,
  status TEXT NOT NULL,
  payload JSONB,
  success BOOLEAN DEFAULT false,
  error TEXT,
  processed_at TIMESTAMPTZ DEFAULT now()
);
```

### Flujo

1. Recibir evento
2. Buscar `event_id` en `event_log`
3. Si existe → `return 200` (ignorar, ya procesado)
4. Si no existe → insertar registro con `success = false`
5. Verificar `support_opt_in` y elegir flujo
6. Ejecutar flujo correspondiente
7. Actualizar registro: `success = true` (o guardar error si falló)

## Observabilidad

Loggear en cada evento:

```
event_id=<uuid> order_id=<uuid> status=<status> support_opt_in=<bool> timestamp=<ISO> result=success|failure flow=logistics|customer_success
```

En caso de error, incluir el mensaje de error en `event_log.error`.

## Seguridad

- Validar `Authorization: Bearer <TOKEN>` en cada request
- Rechazar con `401` si el token no es válido o falta

## Próximos pasos (arquitectura futura)

Separar `event_type` en dos familias:

| Tipo | Ámbito |
|------|--------|
| `ORDER_CREATED` | Logística |
| `ORDER_CONFIRMED` | Logística |
| `ORDER_DELIVERED` | Logística |
| `CS_ONBOARDING_START` | Customer Success |
| `CS_CHECKIN_DAY_7` | Customer Success |
| `CS_CLOSURE_DAY_21` | Customer Success |

Esto permite escalar a CRM real sin mezclar pipelines.

## Diagrama

```
Supabase (orders table)
  │
  │  AFTER UPDATE OF status
  │  (trigger: notify_order_status_change)
  │
  ▼
Edge Function (send-order-event)
  │
  │  Genera event_id (UUID v4)
  │  Construye event envelope { ..., support_opt_in }
  │  Retry: 3 intentos (500ms, 1500ms, 3000ms)
  │  Timeout: 5s por intento
  │
  ▼
Kusanali (/webhook/order-status)
  │
  │  1. Validar Authorization
  │  2. Verificar event_id en event_log
  │     → si existe → return 200
  │  3. Insertar en event_log (success=false)
  │  4. ¿support_opt_in?
  │     ├─ false → runLogisticsOnlyFlow(order)
  │     └─ true  → runCustomerSuccessFlow(order)
  │  5. Actualizar event_log (success=true)
  │
  ▼
Baileys (WhatsApp sender)
  │
  ▼
Customer phone
```
