import { useEffect, useMemo, useState } from 'react';
import { buildApiUrl } from '../config';
import { A2UiEnvelope, AgUiEvent } from '../types/protocol';

function isA2UiEnvelope(value: unknown): value is A2UiEnvelope {
  if (!value || typeof value !== 'object') {
    return false;
  }

  const maybe = value as Partial<A2UiEnvelope>;
  return Boolean(maybe.version && maybe.surface && maybe.layout?.components);
}

export function useAgUiStream() {
  const [events, setEvents] = useState<AgUiEvent[]>([]);
  const [connectionStatus, setConnectionStatus] = useState<'connecting' | 'open' | 'closed'>(
    'connecting'
  );

  useEffect(() => {
    const source = new EventSource(buildApiUrl('/api/agent/events'));

    source.onopen = () => {
      setConnectionStatus('open');
    };

    source.onerror = () => {
      setConnectionStatus('closed');
    };

    source.addEventListener('ag-ui', (message) => {
      try {
        const parsed = JSON.parse((message as MessageEvent).data) as AgUiEvent;
        setEvents((current) => [...current.slice(-24), parsed]);
      } catch (error) {
        console.error('[AG-UI] Failed to parse event payload', error);
      }
    });

    return () => {
      source.close();
      setConnectionStatus('closed');
    };
  }, []);

  const latestEnvelope = useMemo(() => {
    for (let index = events.length - 1; index >= 0; index -= 1) {
      const event = events[index];
      if ((event.kind === 'agent.ui.replace' || event.kind === 'agent.ui.patch') && event.payload) {
        const candidate = event.payload.envelope;
        if (isA2UiEnvelope(candidate)) {
          return candidate;
        }
      }
    }

    return null;
  }, [events]);

  return {
    events,
    latestEnvelope,
    connectionStatus,
  };
}
