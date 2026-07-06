# Clean Nails Landing

## Stack

- Vite + React + TypeScript
- Tailwind CSS v4 (motion-ready)
- Supabase (auth, database, edge functions)
- Motion (animations)

## Propósito

Funnel de venta unisex para Clean Nails (dispositivo de luz para cuidado estético de uñas).
Tono conversacional, validación de frustración, sin lenguaje médico.

## Responsabilidades

- Mostrar la landing y el quiz de severidad
- Registrar `order_requests` en Supabase
- Kusanali Insights: `analytics_sessions` + `analytics_events`
- UI / UX / experiencia del usuario

## NO contiene

- Lógica de WhatsApp / Baileys
- Customer Success
- Logística / rutas
- Automatizaciones
- Paneles administrativos
- Dashboards / gráficas

## Dependencias externas

- Supabase project: `aveusacpaexwrfoyinas`
- Kusanali (proyecto separado): recibe eventos vía Edge Function → webhook

## Estructura

```
src/
├── app/
│   ├── App.tsx                → Funnel principal (6 pasos + formulario)
│   ├── components/            → Step* components, ExitModal
│   └── pages/                 → Pages auxiliares
├── lib/
│   ├── supabase.ts            → Cliente Supabase
│   └── insights/              → Módulo de analítica (desacoplado)
│       ├── index.ts           → startSession(), track(), finishSession(), setConverted()
│       └── storage.ts         → localStorage helpers
├── assets/                    → Imágenes
└── styles/
    └── theme.css              → Variables CSS, colores, tipografía

supabase/
├── migrations/                → Migraciones SQL numeradas
└── functions/
    └── send-order-event/      → Edge Function: recibe triggers, reenvía a Kusanali
```

## Arquitectura de datos

```
Landing (form) → INSERT order_requests → Trigger → Edge Function → Kusanali webhook
Landing (UX)   → INSERT analytics_*    → (futuro: Kusanali BI)
```

## Convenciones

- NO mezclar lógica de presentación con lógica de negocio
- NO escribir en la tabla `orders` directamente (solo Kusanali)
- `order_requests` es la fuente de solicitudes web
- `analytics_sessions` + `analytics_events` son la fuente de analítica
- Los módulos en `src/lib/` deben ser independientes de React
