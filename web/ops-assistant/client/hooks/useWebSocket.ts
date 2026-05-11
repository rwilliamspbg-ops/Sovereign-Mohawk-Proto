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

export const useWebSocket = (url: string = 'ws://localhost:3000') => {
  const [isConnected, setIsConnected] = useState(false);
  const [clientId, setClientId] = useState<string | null>(null);
  const [lastMessage, setLastMessage] = useState<WebSocketMessage | null>(null);
  const [subscriptions, setSubscriptions] = useState<
    Map<string, SubscriptionCallback>
  >(new Map());

  const wsRef = useRef<WebSocket | null>(null);
  const callbacksRef = useRef<Map<string, SubscriptionCallback>>(
    new Map()
  );

  /**
   * Connect to WebSocket
   */
  const connect = useCallback(() => {
    try {
      const ws = new WebSocket(url);

      ws.onopen = () => {
        console.log('[Hook] Connected to WebSocket');
        setIsConnected(true);
        wsRef.current = ws;
      };

      ws.onmessage = (event) => {
        try {
          const message: WebSocketMessage = JSON.parse(event.data);

          if (message.type === 'connected') {
            setClientId(message.clientId || null);
          }

          setLastMessage(message);

          // Trigger subscription callbacks
          if (message.query && callbacksRef.current.has(message.query)) {
            const callback = callbacksRef.current.get(message.query);
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
      if (!wsRef.current || !isConnected) {
        console.warn('[Hook] WebSocket not connected');
        return;
      }

      // Store callback if provided
      if (callback) {
        callbacksRef.current.set(query, callback);
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
    if (!wsRef.current || !isConnected) return;

    const message = {
      type: 'unsubscribe',
      query,
    };

    wsRef.current.send(JSON.stringify(message));
    callbacksRef.current.delete(query);
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
