import WebSocket from 'ws';
import { EventEmitter } from 'events';
export declare class WebSocketManager extends EventEmitter {
    private clients;
    private subscriptions;
    private streamIntervals;
    private prometheusUrl;
    private messageQueue;
    constructor(prometheusUrl?: string);
    /**
     * Register a WebSocket client
     */
    registerClient(clientId: string, ws: WebSocket): void;
    /**
     * Handle incoming WebSocket messages
     */
    private handleMessage;
    /**
     * Subscribe to metric streaming
     */
    subscribe(clientId: string, query: string, interval?: number): void;
    /**
     * Unsubscribe from metric streaming
     */
    unsubscribe(clientId: string, query: string): void;
    /**
     * Start streaming metrics for a query
     */
    private startStreaming;
    /**
     * Stop streaming metrics for a query
     */
    private stopStreaming;
    /**
     * Handle one-off queries
     */
    private handleQuery;
    /**
     * Query Prometheus API
     */
    private queryPrometheus;
    /**
     * Send message to specific client
     */
    private sendMessage;
    /**
     * Broadcast message to all connected clients
     */
    broadcastMessage(message: any): void;
    /**
     * Handle client disconnect
     */
    private handleDisconnect;
    /**
     * Handle WebSocket errors
     */
    private handleError;
    /**
     * Get client count
     */
    getClientCount(): number;
    /**
     * Get subscription count
     */
    getSubscriptionCount(): number;
    /**
     * Get all active subscriptions
     */
    getActiveSubscriptions(): Array<{
        query: string;
        subscribers: number;
    }>;
    /**
     * Graceful shutdown
     */
    shutdown(): void;
}
//# sourceMappingURL=websocket-manager.d.ts.map