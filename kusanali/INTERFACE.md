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

## Payload

```json
{
  "order_id": "uuid",
  "status": "new | confirmed | assigned | in_route | delivered",
  "name": "string",
  "phone": "string",
  "city": "string",
  "timestamp": "ISO 8601 date"
}
```

## Messages by Status

| Status      | Message |
|-------------|---------|
| `new`       | Tu pedido ha sido registrado. Te contactaremos pronto para confirmar los detalles de entrega. |
| `confirmed` | Tu pedido ha sido confirmado. Ya estamos preparando tu Clean Nails para entrega. |
| `assigned`  | Tu pedido fue asignado a ruta. Pronto recibirás noticias del reparto. |
| `in_route`  | Tu pedido va en camino. Tenlo listo para recibirlo. |
| `delivered` | Tu pedido ha sido entregado 🎉 Bienvenido al programa de 21 días de Clean Nails. |

## Idempotency

Guardar un log por `order_id + status`. Si el par ya fue procesado, ignorar el evento.

## Security

- Validar `Authorization: Bearer <TOKEN>` en cada request
- Rechazar con `401` si el token no es válido o falta

## Diagram

```
Supabase (orders table)
  │
  │  AFTER UPDATE OF status
  │  (trigger: notify_order_status_change)
  │
  ▼
Edge Function (send-order-event)
  │
  │  HTTP POST /webhook/order-status
  │  Authorization: Bearer <SECRET>
  │
  ▼
Kusanali (webhook handler)
  │
  │  Check idempotency (order_id + status)
  │  Format message by status
  │
  ▼
Baileys (WhatsApp sender)
  │
  ▼
Customer phone
```
