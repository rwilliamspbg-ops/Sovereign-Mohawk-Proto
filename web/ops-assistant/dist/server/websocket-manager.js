import WebSocket from 'ws';
import { EventEmitter } from 'events';
import axios from 'axios';
export class WebSocketManager extends EventEmitter {
    constructor(prometheusUrl = 'http://prometheus:9090') {
        super();
        Object.defineProperty(this, "clients", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: new Map()
        });
        Object.defineProperty(this, "subscriptions", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: new Map()
        });
        Object.defineProperty(this, "streamIntervals", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: new Map()
        });
        Object.defineProperty(this, "prometheusUrl", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "messageQueue", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: new Map()
        });
        this.prometheusUrl = prometheusUrl;
    }
    /**
     * Register a WebSocket client
     */
    registerClient(clientId, ws) {
        const client = {
            id: clientId,
            ws,
            subscriptions: new Set(),
            connected: true,
        };
        this.clients.set(clientId, client);
        this.messageQueue.set(clientId, []);
        ws.on('message', (data) => this.handleMessage(clientId, data));
        ws.on('close', () => this.handleDisconnect(clientId));
        ws.on('error', (error) => this.handleError(clientId, error));
        console.log(`[WebSocket] Client registered: ${clientId}`);
        this.emit('client_connected', { clientId });
    }
    /**
     * Handle incoming WebSocket messages
     */
    handleMessage(clientId, data) {
        try {
            const message = JSON.parse(data.toString());
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
        }
        catch (error) {
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
    subscribe(clientId, query, interval = 1000) {
        const client = this.clients.get(clientId);
        if (!client)
            return;
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
    unsubscribe(clientId, query) {
        const client = this.clients.get(clientId);
        if (!client)
            return;
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
    startStreaming(query, interval) {
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
            }
            catch (error) {
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
    stopStreaming(query) {
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
    async handleQuery(clientId, query) {
        try {
            const data = await this.queryPrometheus(query);
            this.sendMessage(clientId, {
                type: 'query_result',
                query,
                data,
                timestamp: Date.now(),
            });
        }
        catch (error) {
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
    async queryPrometheus(query) {
        const response = await axios.get(`${this.prometheusUrl}/api/v1/query`, {
            params: { query },
            timeout: 5000,
        });
        return response.data;
    }
    /**
     * Send message to specific client
     */
    sendMessage(clientId, message) {
        const client = this.clients.get(clientId);
        if (!client || client.ws.readyState !== WebSocket.OPEN)
            return;
        try {
            client.ws.send(JSON.stringify(message));
        }
        catch (error) {
            console.error(`[WebSocket] Error sending message to ${clientId}:`, error);
        }
    }
    /**
     * Broadcast message to all connected clients
     */
    broadcastMessage(message) {
        this.clients.forEach((client) => {
            if (client.ws.readyState === WebSocket.OPEN) {
                try {
                    client.ws.send(JSON.stringify(message));
                }
                catch (error) {
                    console.error(`[WebSocket] Error broadcasting to ${client.id}:`, error);
                }
            }
        });
    }
    /**
     * Handle client disconnect
     */
    handleDisconnect(clientId) {
        const client = this.clients.get(clientId);
        if (!client)
            return;
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
        console.log(`[WebSocket] Client disconnected: ${clientId}`);
        this.emit('client_disconnected', { clientId });
    }
    /**
     * Handle WebSocket errors
     */
    handleError(clientId, error) {
        console.error(`[WebSocket] Error for client ${clientId}:`, error);
        this.emit('client_error', { clientId, error });
    }
    /**
     * Get client count
     */
    getClientCount() {
        return this.clients.size;
    }
    /**
     * Get subscription count
     */
    getSubscriptionCount() {
        let count = 0;
        this.subscriptions.forEach((subs) => {
            count += subs.length;
        });
        return count;
    }
    /**
     * Get all active subscriptions
     */
    getActiveSubscriptions() {
        const result = [];
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
    shutdown() {
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
//# sourceMappingURL=websocket-manager.js.map