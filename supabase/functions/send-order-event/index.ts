import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

interface OrderEvent {
  type: string
  table: string
  record: {
    id: string
    name: string
    phone: string
    city: string
    status: string
    support_opt_in: boolean | null
  }
  old_record: { status: string }
  timestamp: string
}

interface EventEnvelope {
  event_id: string
  type: string
  order: {
    id: string
    name: string
    phone: string
    city: string
    status: string
    support_opt_in: boolean
  }
  timestamp: string
}

const RETRIES = [
  { delay: 500 },
  { delay: 1500 },
  { delay: 3000 },
]
const TIMEOUT_MS = 5000

async function sendWithRetry(
  url: string,
  token: string,
  body: EventEnvelope,
): Promise<Response> {
  let lastError: Error | null = null

  for (const { delay } of RETRIES) {
    if (lastError) {
      await new Promise((r) => setTimeout(r, delay))
    }

    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      })
      clearTimeout(timer)
      return response
    } catch (err) {
      clearTimeout(timer)
      lastError = err instanceof Error ? err : new Error(String(err))
      console.error(`send-order-event: retry attempt failed — ${lastError.message}`)
    }
  }

  throw lastError ?? new Error('All retries exhausted')
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

  const optIn = event.record.support_opt_in ?? true

  const envelope: EventEnvelope = {
    event_id: crypto.randomUUID(),
    type: event.type,
    order: {
      id: event.record.id,
      name: event.record.name,
      phone: event.record.phone,
      city: event.record.city,
      status: event.record.status,
      support_opt_in: optIn,
    },
    timestamp: event.timestamp,
  }

  const kusanaliUrl = Deno.env.get('KUSANALI_URL') ?? 'https://kusanali-api/webhook/order-status'
  const kusanaliToken = Deno.env.get('KUSANALI_TOKEN') ?? ''

  try {
    const response = await sendWithRetry(kusanaliUrl, kusanaliToken, envelope)

    if (!response.ok) {
      const errorText = await response.text()
      console.error(`send-order-event: Kusanali returned ${response.status} — ${errorText}`)
      return new Response('Failed to forward event to Kusanali', { status: 502 })
    }

    return new Response('OK', { status: 200 })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error(`send-order-event: all retries exhausted — ${message}`)
    return new Response('Failed after retries', { status: 502 })
  }
})
