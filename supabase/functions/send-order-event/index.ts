import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

interface OrderRecord {
  id: string
  name: string
  phone: string
  city: string
  status: string
}

interface OrderEvent {
  type: string
  table: string
  record: OrderRecord
  old_record: { status: string }
  timestamp: string
}

interface KusanaliPayload {
  order_id: string
  status: string
  name: string
  phone: string
  city: string
  timestamp: string
}

serve(async (req) => {
  const auth = req.headers.get('Authorization')
  const expectedSecret = Deno.env.get('SUPABASE_WEBHOOK_SECRET')

  if (!auth || !auth.startsWith('Bearer ') || !expectedSecret || auth.slice(7) !== expectedSecret) {
    return new Response('Unauthorized', { status: 401 })
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  let event: OrderEvent
  try {
    event = await req.json()
  } catch {
    return new Response('Invalid JSON', { status: 400 })
  }

  if (event.type !== 'ORDER_STATUS_CHANGE') {
    return new Response('Ignored: not a status change event', { status: 200 })
  }

  const payload: KusanaliPayload = {
    order_id: event.record.id,
    status: event.record.status,
    name: event.record.name,
    phone: event.record.phone,
    city: event.record.city,
    timestamp: event.timestamp,
  }

  const kusanaliUrl = Deno.env.get('KUSANALI_URL') ?? 'https://kusanali-api/webhook/order-status'
  const kusanaliToken = Deno.env.get('KUSANALI_TOKEN') ?? ''

  const response = await fetch(kusanaliUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${kusanaliToken}`,
    },
    body: JSON.stringify(payload),
  })

  if (!response.ok) {
    const errorText = await response.text()
    console.error(`Kusanali returned ${response.status}: ${errorText}`)
    return new Response('Failed to forward event to Kusanali', { status: 502 })
  }

  return new Response('OK', { status: 200 })
})
