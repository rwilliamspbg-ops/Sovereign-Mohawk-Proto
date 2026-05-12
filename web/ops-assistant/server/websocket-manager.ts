import WebSocket from 'ws';
import { EventEmitter } from 'events';
import axios from 'axios';

/**
 * WebSocket Manager for real-time metric streaming
 * Handles client connections, subscriptions, and metric streaming
 */

interface Client {
  id: string;
  ws: WebSocket;
  subscriptions: Set<string>;
  connected: boolean;
  remoteAddress?: string;
}

interface MetricSubscription {
  query: string;
  interval: number;
  clientId: string;
}

export class WebSocketManager extends EventEmitter {
  private clients: Map<string, Client> = new Map();
  private subscriptions: Map<string, MetricSubscription[]> = new Map();
  private streamIntervals: Map<string, NodeJS.Timeout> = new Map();
  private prometheusUrl: string;
  private messageQueue: Map<string, any[]> = new Map();

  constructor(prometheusUrl: string = 'http://prometheus:9090') {
    super();
    this.prometheusUrl = prometheusUrl;
  }

  /**
   * Register a WebSocket client
   */
  registerClient(clientId: string, ws: WebSocket, remoteAddress?: string): void {
    const client: Client = {
      id: clientId,
      ws,
      subscriptions: new Set(),
      connected: true,
      remoteAddress,
    };

    this.clients.set(clientId, client);
    this.messageQueue.set(clientId, []);

    ws.on('message', (data) => this.handleMessage(clientId, data));
    ws.on('close', () => this.handleDisconnect(clientId));
    ws.on('error', (error) => this.handleError(clientId, error));

    console.log(
      `[WebSocket] Client registered: ${clientId}${remoteAddress ? ` from ${remoteAddress}` : ''}`
    );
    this.emit('client_connected', { clientId });
  }

  /**
   * Handle incoming WebSocket messages
   */
  private handleMessage(clientId: string, data: WebSocket.Data): void {
    try {
      const message = JSON.parse(data.toString());
      console.log(`[WebSocket] Message from ${clientId}: ${message.type}`);

      switch (message.type) {
        case 'subscribe':
          this.subscribe(clientId, message.query, message.interval || 1000);
          break;
        case 'unsubscribe':
          this.unsubscribe(clientId, message.query);
          break;
        case 'query':
          this.handleQuery(clientId, message.query);
          break;
        case 'ping':
          this.sendMessage(clientId, { type: 'pong', timestamp: Date.now() });
          break;
        default:
          console.warn(`[WebSocket] Unknown message type: ${message.type}`);
      }
    } catch (error) {
      console.error(`[WebSocket] Error handling message:`, error);
      this.sendMessage(clientId, {
        type: 'error',
        message: 'Invalid message format',
      });
    }
  }

  /**
   * Subscribe to metric streaming
   */
  subscribe(clientId: string, query: string, interval: number = 1000): void {
    const client = this.clients.get(clientId);
    if (!client) return;

    client.subscriptions.add(query);

    if (!this.subscriptions.has(query)) {
      this.subscriptions.set(query, []);
    }

    this.subscriptions.get(query)?.push({ query, interval, clientId });

    // Start streaming if not already running
    if (!this.streamIntervals.has(query)) {
      this.startStreaming(query, interval);
    }

    this.sendMessage(clientId, {
      type: 'subscribed',
      query,
      timestamp: Date.now(),
    });

    console.log(`[WebSocket] Client ${clientId} subscribed to: ${query}`);
  }

  /**
   * Unsubscribe from metric streaming
   */
  unsubscribe(clientId: string, query: string): void {
    const client = this.clients.get(clientId);
    if (!client) return;

    client.subscriptions.delete(query);

    const subs = this.subscriptions.get(query) || [];
    const index = subs.findIndex((s) => s.clientId === clientId);
    if (index >= 0) {
      subs.splice(index, 1);
    }

    // Stop streaming if no more subscribers
    if (subs.length === 0) {
      this.stopStreaming(query);
    }

    this.sendMessage(clientId, {
      type: 'unsubscribed',
      query,
      timestamp: Date.now(),
    });

    console.log(`[WebSocket] Client ${clientId} unsubscribed from: ${query}`);
  }

  /**
   * Start streaming metrics for a query
   */
  private startStreaming(query: string, interval: number): void {
    const intervalId = setInterval(async () => {
      try {
        const data = await this.queryPrometheus(query);

        const subs = this.subscriptions.get(query) || [];
        for (const sub of subs) {
          this.sendMessage(sub.clientId, {
            type: 'metric_update',
            query,
            data,
            timestamp: Date.now(),
          });
        }
      } catch (error) {
        console.error(`[WebSocket] Error querying Prometheus:`, error);

        const subs = this.subscriptions.get(query) || [];
        for (const sub of subs) {
          this.sendMessage(sub.clientId, {
            type: 'error',
            query,
            message: 'Failed to query metrics',
            timestamp: Date.now(),
          });
        }
      }
    }, interval);

    this.streamIntervals.set(query, intervalId);
    console.log(`[WebSocket] Started streaming for query: ${query} (interval: ${interval}ms)`);
  }

  /**
   * Stop streaming metrics for a query
   */
  private stopStreaming(query: string): void {
    const intervalId = this.streamIntervals.get(query);
    if (intervalId) {
      clearInterval(intervalId);
      this.streamIntervals.delete(query);
      console.log(`[WebSocket] Stopped streaming for query: ${query}`);
    }
  }

  /**
   * Handle one-off queries
   */
  private async handleQuery(clientId: string, query: string): Promise<void> {
    try {
      const data = await this.queryPrometheus(query);
      this.sendMessage(clientId, {
        type: 'query_result',
        query,
        data,
        timestamp: Date.now(),
      });
    } catch (error) {
      this.sendMessage(clientId, {
        type: 'error',
        query,
        message: error instanceof Error ? error.message : 'Query failed',
        timestamp: Date.now(),
      });
    }
  }

  /**
   * Query Prometheus API
   */
  private async queryPrometheus(query: string): Promise<any> {
    const response = await axios.get(`${this.prometheusUrl}/api/v1/query`, {
      params: { query },
      timeout: 5000,
    });

    return response.data;
  }

  /**
   * Send message to specific client
   */
  private sendMessage(clientId: string, message: any): void {
    const client = this.clients.get(clientId);
    if (!client || client.ws.readyState !== WebSocket.OPEN) return;

    try {
      client.ws.send(JSON.stringify(message));
    } catch (error) {
      console.error(`[WebSocket] Error sending message to ${clientId}:`, error);
    }
  }

  /**
   * Broadcast message to all connected clients
   */
  broadcastMessage(message: any): void {
    this.clients.forEach((client) => {
      if (client.ws.readyState === WebSocket.OPEN) {
        try {
          client.ws.send(JSON.stringify(message));
        } catch (error) {
          console.error(`[WebSocket] Error broadcasting to ${client.id}:`, error);
        }
      }
    });
  }

  /**
   * Handle client disconnect
   */
  private handleDisconnect(clientId: string): void {
    const client = this.clients.get(clientId);
    if (!client) return;

    client.connected = false;

    // Clean up subscriptions
    client.subscriptions.forEach((query) => {
      const subs = this.subscriptions.get(query) || [];
      const index = subs.findIndex((s) => s.clientId === clientId);
      if (index >= 0) {
        subs.splice(index, 1);
      }

      if (subs.length === 0) {
        this.stopStreaming(query);
      }
    });

    this.clients.delete(clientId);
    this.messageQueue.delete(clientId);

    console.log(
      `[WebSocket] Client disconnected: ${clientId}${client.remoteAddress ? ` from ${client.remoteAddress}` : ''}`
    );
    this.emit('client_disconnected', { clientId });
  }

  /**
   * Handle WebSocket errors
   */
  private handleError(clientId: string, error: Error): void {
    console.error(`[WebSocket] Error for client ${clientId}:`, error);
    this.emit('client_error', { clientId, error });
  }

  /**
   * Get client count
   */
  getClientCount(): number {
    return this.clients.size;
  }

  /**
   * Get subscription count
   */
  getSubscriptionCount(): number {
    let count = 0;
    this.subscriptions.forEach((subs) => {
      count += subs.length;
    });
    return count;
  }

  /**
   * Get all active subscriptions
   */
  getActiveSubscriptions(): Array<{ query: string; subscribers: number }> {
    const result: Array<{ query: string; subscribers: number }> = [];
    this.subscriptions.forEach((subs, query) => {
      if (subs.length > 0) {
        result.push({
          query,
          subscribers: new Set(subs.map((s) => s.clientId)).size,
        });
      }
    });
    return result;
  }

  /**
   * Graceful shutdown
   */
  shutdown(): void {
    console.log('[WebSocket] Shutting down...');

    // Stop all streaming
    this.streamIntervals.forEach((intervalId) => clearInterval(intervalId));
    this.streamIntervals.clear();

    // Close all client connections
    this.clients.forEach((client) => {
      if (client.ws.readyState === WebSocket.OPEN) {
        client.ws.close(1000, 'Server shutting down');
      }
    });

    this.clients.clear();
    this.subscriptions.clear();
    this.messageQueue.clear();

    console.log('[WebSocket] Shutdown complete');
  }
}
