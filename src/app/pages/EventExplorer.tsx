import { useState, useEffect } from "react";
import { supabase } from "../../lib/supabase";

interface AnalyticsEvent {
  id: string;
  event_name: string;
  created_at: string;
  seconds_from_start: number;
  metadata: Record<string, unknown>;
  session_id: string;
}

export default function EventExplorer() {
  const [events, setEvents] = useState<AnalyticsEvent[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      const { data, error } = await supabase
        .from("analytics_events")
        .select("id, event_name, created_at, seconds_from_start, metadata, session_id")
        .order("created_at", { ascending: false })
        .limit(100);

      if (error) {
        console.error("[EventExplorer]", error);
      } else {
        setEvents(data ?? []);
      }
      setLoading(false);
    })();
  }, []);

  const formatTime = (iso: string) => {
    const d = new Date(iso);
    return d.toLocaleTimeString("es-MX", { hour: "2-digit", minute: "2-digit" });
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-muted-foreground text-sm">Cargando eventos...</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background px-4 py-6 max-w-2xl mx-auto">
      <div className="mb-6">
        <h1 className="font-display text-xl text-foreground mb-1">Event Explorer</h1>
        <p className="text-xs text-muted-foreground font-light">
          {events.length} eventos · tiempo real · sin datos personales
        </p>
      </div>

      <div className="flex flex-col gap-1.5">
        {events.length === 0 && (
          <p className="text-sm text-muted-foreground font-light text-center py-12">
            No hay eventos registrados aún.
          </p>
        )}

        {events.map((ev) => (
          <div
            key={ev.id}
            className="flex items-start gap-3 rounded-lg border border-border bg-card px-4 py-3"
          >
            <span className="text-[0.65rem] text-muted-foreground font-mono shrink-0 mt-0.5 w-10 text-right">
              {formatTime(ev.created_at)}
            </span>

            <div className="min-w-0 flex-1">
              <p className="text-sm font-medium text-foreground truncate">
                {ev.event_name}
              </p>
              <div className="flex flex-wrap gap-x-3 gap-y-0.5 mt-0.5">
                <span className="text-[0.62rem] text-muted-foreground/60 font-mono">
                  session={ev.session_id.slice(0, 8)}...
                </span>
                <span className="text-[0.62rem] text-muted-foreground/60 font-mono">
                  +{ev.seconds_from_start}s
                </span>
              </div>
            </div>

            {Object.keys(ev.metadata || {}).length > 0 && (
              <details className="shrink-0">
                <summary className="text-[0.6rem] text-muted-foreground/50 cursor-pointer hover:text-muted-foreground transition-colors">
                  meta
                </summary>
                <pre className="text-[0.6rem] text-muted-foreground font-mono mt-1 whitespace-pre-wrap max-w-[200px]">
                  {JSON.stringify(ev.metadata, null, 1)}
                </pre>
              </details>
            )}
          </div>
        ))}
      </div>

      <p className="text-[0.6rem] text-muted-foreground/40 text-center mt-8 font-mono">
        Kusanali Intelligence · dev only
      </p>
    </div>
  );
}
