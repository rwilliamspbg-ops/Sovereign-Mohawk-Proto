import { useEffect, useRef, useState, useCallback } from 'react';

/**
 * WebSocket Connection Hook
 * Manages WebSocket connection, subscriptions, and real-time data updates
 */

export interface WebSocketMessage {
  type: string;
  clientId?: string;
  query?: string;
  data?: any;
  message?: string;
  timestamp?: number;
  error?: string;
}

interface SubscriptionCallback {
  (data: any): void;
}

interface SubscriptionEntry {
  interval: number;
  callback?: SubscriptionCallback;
}

export const useWebSocket = (url: string = 'ws://localhost:3000') => {
  const [isConnected, setIsConnected] = useState(false);
  const [clientId, setClientId] = useState<string | null>(null);
  const [lastMessage, setLastMessage] = useState<WebSocketMessage | null>(null);

  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimerRef = useRef<number | null>(null);
  const reconnectAttemptRef = useRef(0);
  const manualDisconnectRef = useRef(false);
  const maxReconnectDelayMs = 30000;
  const desiredSubscriptionsRef = useRef<Map<string, SubscriptionEntry>>(
    new Map()
  );

  /**
   * Connect to WebSocket
   */
  const connect = useCallback(() => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      return;
    }

    if (reconnectTimerRef.current !== null) {
      window.clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    }

    try {
      const ws = new WebSocket(url);

      ws.onopen = () => {
        console.log('[Hook] Connected to WebSocket');
        setIsConnected(true);
        wsRef.current = ws;
        reconnectAttemptRef.current = 0;

        // Rehydrate all subscriptions after reconnect.
        desiredSubscriptionsRef.current.forEach((entry, query) => {
          ws.send(
            JSON.stringify({
              type: 'subscribe',
              query,
              interval: entry.interval,
            })
          );
        });
      };

      ws.onmessage = (event) => {
        try {
          const message: WebSocketMessage = JSON.parse(event.data);

          if (message.type === 'connected') {
            setClientId(message.clientId || null);
          }

          setLastMessage(message);

          // Trigger subscription callbacks
          if (message.query && desiredSubscriptionsRef.current.has(message.query)) {
            const callback = desiredSubscriptionsRef.current.get(message.query)?.callback;
            if (callback) {
              callback(message);
            }
          }
        } catch (error) {
          console.error('[Hook] Error parsing message:', error);
        }
      };

      ws.onclose = () => {
        console.log('[Hook] Disconnected from WebSocket');
        setIsConnected(false);
        setClientId(null);
        wsRef.current = null;

        if (!manualDisconnectRef.current) {
          const attempt = reconnectAttemptRef.current + 1;
          reconnectAttemptRef.current = attempt;
          const delay = Math.min(1000 * 2 ** (attempt - 1), maxReconnectDelayMs);

          reconnectTimerRef.current = window.setTimeout(() => {
            connect();
          }, delay);
        }
      };

      ws.onerror = (error) => {
        console.error('[Hook] WebSocket error:', error);
        setIsConnected(false);
      };

      wsRef.current = ws;
    } catch (error) {
      console.error('[Hook] Connection error:', error);
    }
  }, [url]);

  /**
   * Disconnect from WebSocket
   */
  const disconnect = useCallback(() => {
    manualDisconnectRef.current = true;

    if (reconnectTimerRef.current !== null) {
      window.clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    }

    if (wsRef.current) {
      wsRef.current.close();
      wsRef.current = null;
      setIsConnected(false);
      setClientId(null);
    }
  }, []);

  /**
   * Subscribe to metric query
   */
  const subscribe = useCallback(
    (query: string, interval: number = 1000, callback?: SubscriptionCallback) => {
      desiredSubscriptionsRef.current.set(query, { interval, callback });

      if (!wsRef.current || !isConnected) {
        console.warn('[Hook] WebSocket not connected');
        return;
      }

      const message = {
        type: 'subscribe',
        query,
        interval,
      };

      wsRef.current.send(JSON.stringify(message));
      console.log(`[Hook] Subscribed to: ${query}`);
    },
    [isConnected]
  );

  /**
   * Unsubscribe from metric query
   */
  const unsubscribe = useCallback((query: string) => {
    desiredSubscriptionsRef.current.delete(query);

    if (!wsRef.current || !isConnected) return;

    const message = {
      type: 'unsubscribe',
      query,
    };

    wsRef.current.send(JSON.stringify(message));
    console.log(`[Hook] Unsubscribed from: ${query}`);
  }, [isConnected]);

  /**
   * Send query message
   */
  const sendQuery = useCallback(
    (query: string) => {
      if (!wsRef.current || !isConnected) {
        console.warn('[Hook] WebSocket not connected');
        return;
      }

      const message = {
        type: 'query',
        query,
      };

      wsRef.current.send(JSON.stringify(message));
    },
    [isConnected]
  );

  /**
   * Send ping
   */
  const ping = useCallback(() => {
    if (!wsRef.current || !isConnected) return;

    wsRef.current.send(JSON.stringify({ type: 'ping' }));
  }, [isConnected]);

  /**
   * Connect on mount
   */
  useEffect(() => {
    manualDisconnectRef.current = false;
    connect();

    return () => {
      disconnect();
    };
  }, [connect, disconnect]);

  return {
    isConnected,
    clientId,
    lastMessage,
    connect,
    disconnect,
    subscribe,
    unsubscribe,
    sendQuery,
    ping,
  };
};
