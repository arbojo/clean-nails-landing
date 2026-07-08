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

interface OrderRequestEvent {
  type: string
  table: string
  record: {
    id: string
    customer_name: string
    phone: string
    street: string
    colony: string
    city: string
    state: string
    zip: string | null
    references: string | null
    product_name: string
    quantity: number
    total: number
    support_opt_in: boolean | null
    metadata: Record<string, unknown>
  }
  old_record: null
  timestamp: string
}

interface OrderEnvelope {
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

interface OrderRequestEnvelope {
  event_id: string
  type: string
  order_request: {
    id: string
    customer_name: string
    phone: string
    street: string
    colony: string
    city: string
    state: string
    zip: string | null
    references: string | null
    product_name: string
    quantity: number
    total: number
    support_opt_in: boolean
    metadata: Record<string, unknown>
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
  body: OrderEnvelope | OrderRequestEnvelope,
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
  const expectedSecret = Deno.env.get('CLEAN_NAILS_WEBHOOK_SECRET')

  if (!auth || !auth.startsWith('Bearer ') || !expectedSecret || auth.slice(7) !== expectedSecret) {
    return new Response('Unauthorized', { status: 401 })
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  let rawEvent: Record<string, unknown>
  try {
    rawEvent = await req.json()
  } catch {
    return new Response('Invalid JSON', { status: 400 })
  }

  const eventType = rawEvent.type as string

  if (eventType === 'ORDER_REQUEST_CREATED') {
    const event = rawEvent as unknown as OrderRequestEvent

    const optIn = event.record.support_opt_in ?? true

    const envelope: OrderRequestEnvelope = {
      event_id: crypto.randomUUID(),
      type: event.type,
      order_request: {
        id: event.record.id,
        customer_name: event.record.customer_name,
        phone: event.record.phone,
        street: event.record.street,
        colony: event.record.colony,
        city: event.record.city,
        state: event.record.state,
        zip: event.record.zip,
        references: event.record.references,
        product_name: event.record.product_name,
        quantity: event.record.quantity,
        total: event.record.total,
        support_opt_in: optIn,
        metadata: event.record.metadata,
      },
      timestamp: event.timestamp,
    }

    const kusanaliUrl = Deno.env.get('KUSANALI_URL') ?? 'https://kusanali-api/webhook/order-request'
    const kusanaliToken = Deno.env.get('KUSANALI_TOKEN') ?? ''

    try {
      const response = await sendWithRetry(kusanaliUrl, kusanaliToken, envelope)

      if (!response.ok) {
        const errorText = await response.text()
        console.error(`send-order-event: Kusanali returned ${response.status} — ${errorText}`)
        return new Response('Failed to forward order request to Kusanali', { status: 502 })
      }

      return new Response('OK', { status: 200 })
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      console.error(`send-order-event: all retries exhausted — ${message}`)
      return new Response('Failed after retries', { status: 502 })
    }
  }

  if (eventType === 'ORDER_STATUS_CHANGE') {
    const event = rawEvent as unknown as OrderEvent

    const optIn = event.record.support_opt_in ?? true

    const envelope: OrderEnvelope = {
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
  }

  return new Response(`Ignored: unknown event type — ${eventType}`, { status: 200 })
})
