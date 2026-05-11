import express from 'express';
import cors from 'cors';
import axios from 'axios';
import { WebSocketManager } from './websocket-manager.js';
import { GrafanaClient } from './grafana-client.js';
import { advancedActions } from './actions.js';
import { queryPrometheusHealth, KEY_METRICS, } from './prometheus-client.js';
import http from 'http';
import { WebSocketServer } from 'ws';
/**
 * Enhanced CopilotKit Operations Assistant Server
 * Provides real-time metrics, Grafana integration, and advanced AI actions
 */
const app = express();
const port = process.env.PORT || 3000;
const prometheusUrl = process.env.PROMETHEUS_URL || 'http://prometheus:9090';
const grafanaUrl = process.env.GRAFANA_URL || 'http://grafana:3000';
// Middleware
app.use(cors());
app.use(express.json());
// Create HTTP server for WebSocket support
const server = http.createServer(app);
// WebSocket Manager
const wsManager = new WebSocketManager(prometheusUrl);
const wss = new WebSocketServer({ server });
// Grafana Client
const grafanaClient = new GrafanaClient(grafanaUrl);
/**
 * WebSocket Connection Handler
 */
wss.on('connection', (ws, _req) => {
    const clientId = `client_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    console.log(`[Server] New WebSocket connection: ${clientId}`);
    wsManager.registerClient(clientId, ws);
    // Send welcome message
    ws.send(JSON.stringify({
        type: 'connected',
        clientId,
        message: 'Connected to Operations Assistant',
        timestamp: Date.now(),
    }));
});
/**
 * Health Check Endpoint
 */
app.get(['/health', '/api/health'], (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date(),
        uptime: process.uptime(),
        wsClients: wsManager.getClientCount(),
        wsSubscriptions: wsManager.getSubscriptionCount(),
    });
});
/**
 * Prometheus Health Check Endpoint
 * Uses prometheus-client module to verify Prometheus connectivity
 */
app.get('/api/prometheus/health', async (req, res) => {
    try {
        const isHealthy = await queryPrometheusHealth();
        res.json({
            healthy: isHealthy,
            message: isHealthy ? 'Prometheus is healthy' : 'Prometheus is unreachable',
        });
    }
    catch (error) {
        res.status(500).json({
            healthy: false,
            error: error instanceof Error ? error.message : 'Health check failed',
        });
    }
});
/**
 * Key Metrics Endpoint
 * Returns pre-configured key metrics for Sovereign Mohawk
 */
app.get('/api/prometheus/key-metrics', (req, res) => {
    res.json({
        keyMetrics: KEY_METRICS,
    });
});
/**
 * Prometheus Query Endpoint
 */
app.post('/api/query', async (req, res) => {
    const { query, timeRange = '1h', step = '1m' } = req.body;
    if (!query) {
        return res.status(400).json({ error: 'Query parameter required' });
    }
    try {
        const end = Math.floor(Date.now() / 1000);
        const start = end - parseTimeRange(timeRange);
        const response = await axios.get(`${prometheusUrl}/api/v1/query_range`, {
            params: {
                query,
                start,
                end,
                step,
            },
            timeout: 10000,
        });
        res.json(response.data);
    }
    catch (error) {
        console.error('[Server] Query error:', error);
        res.status(500).json({
            error: error instanceof Error ? error.message : 'Query failed',
        });
    }
});
/**
 * Prometheus Instant Query Endpoint
 */
app.get('/api/query/instant', async (req, res) => {
    const { query } = req.query;
    if (!query || typeof query !== 'string') {
        return res.status(400).json({ error: 'Query parameter required' });
    }
    try {
        const response = await axios.get(`${prometheusUrl}/api/v1/query`, {
            params: { query },
            timeout: 10000,
        });
        res.json(response.data);
    }
    catch (error) {
        console.error('[Server] Instant query error:', error);
        res.status(500).json({
            error: error instanceof Error ? error.message : 'Query failed',
        });
    }
});
/**
 * Grafana Dashboards Endpoint
 */
app.get('/api/grafana/dashboards', async (req, res) => {
    try {
        const dashboards = await grafanaClient.getDashboards();
        res.json({
            success: true,
            dashboards,
        });
    }
    catch (error) {
        console.error('[Server] Dashboard fetch error:', error);
        res.status(500).json({ error: 'Failed to fetch dashboards' });
    }
});
/**
 * Grafana Dashboard Detail Endpoint
 */
app.get('/api/grafana/dashboards/:uid', async (req, res) => {
    const { uid } = req.params;
    try {
        const dashboard = await grafanaClient.getDashboardByUid(uid);
        if (!dashboard) {
            return res.status(404).json({ error: 'Dashboard not found' });
        }
        res.json(dashboard);
    }
    catch (error) {
        console.error('[Server] Dashboard detail error:', error);
        res.status(500).json({ error: 'Failed to fetch dashboard details' });
    }
});
/**
 * Grafana Search Endpoint
 */
app.get('/api/grafana/search', async (req, res) => {
    const { query } = req.query;
    if (!query || typeof query !== 'string') {
        return res.status(400).json({ error: 'Query parameter required' });
    }
    try {
        const results = await grafanaClient.searchDashboards(query);
        res.json({
            success: true,
            results,
        });
    }
    catch (error) {
        console.error('[Server] Grafana search error:', error);
        res.status(500).json({ error: 'Search failed' });
    }
});
/**
 * Grafana Alerts Endpoint
 */
app.get('/api/grafana/alerts', async (req, res) => {
    try {
        const alerts = await grafanaClient.getAlerts();
        res.json({
            success: true,
            alerts,
        });
    }
    catch (error) {
        console.error('[Server] Alerts fetch error:', error);
        res.status(500).json({ error: 'Failed to fetch alerts' });
    }
});
/**
 * Grafana Annotations Endpoint
 */
app.get('/api/grafana/annotations', async (req, res) => {
    const { dashboardId, panelId, tags } = req.query;
    try {
        const annotationTags = typeof tags === 'string'
            ? [tags]
            : Array.isArray(tags)
                ? tags.filter((tag) => typeof tag === 'string')
                : undefined;
        const annotations = await grafanaClient.getAnnotations(dashboardId ? parseInt(dashboardId) : undefined, panelId ? parseInt(panelId) : undefined, annotationTags);
        res.json({
            success: true,
            annotations,
        });
    }
    catch (error) {
        console.error('[Server] Annotations fetch error:', error);
        res.status(500).json({ error: 'Failed to fetch annotations' });
    }
});
/**
 * WebSocket Subscriptions Endpoint
 */
app.get('/api/subscriptions', (req, res) => {
    const subscriptions = wsManager.getActiveSubscriptions();
    res.json({
        totalClients: wsManager.getClientCount(),
        totalSubscriptions: wsManager.getSubscriptionCount(),
        subscriptions,
    });
});
/**
 * Advanced Actions Info Endpoint
 */
app.get('/api/actions', (req, res) => {
    const actionMetadata = advancedActions.map((action) => ({
        name: action.name,
        description: action.description,
        parameters: action.parameters,
    }));
    res.json({
        totalActions: actionMetadata.length,
        actions: actionMetadata,
    });
});
/**
 * Test Metric Generation Endpoint (for demo purposes)
 */
app.get('/api/test-metrics', async (req, res) => {
    try {
        // Return mock metrics for testing
        const metrics = {
            timestamp: Date.now(),
            metrics: {
                cpu_usage: Math.random() * 100,
                memory_usage: Math.random() * 100,
                network_latency: Math.random() * 100,
                request_rate: Math.floor(Math.random() * 10000),
                error_rate: Math.random() * 5,
            },
        };
        res.json(metrics);
    }
    catch (error) {
        res.status(500).json({ error: 'Failed to generate test metrics' });
    }
});
/**
 * Parse time range string (e.g., "1h" -> seconds)
 */
function parseTimeRange(timeRange) {
    const unitMap = {
        m: 60,
        h: 3600,
        d: 86400,
        w: 604800,
    };
    const match = timeRange.match(/^(\d+)([mhdw])$/);
    if (!match)
        return 3600; // Default to 1 hour
    const [, value, unit] = match;
    return parseInt(value) * unitMap[unit];
}
/**
 * Graceful Shutdown
 */
process.on('SIGINT', () => {
    console.log('\n[Server] Shutting down gracefully...');
    wsManager.shutdown();
    server.close(() => {
        console.log('[Server] Server closed');
        process.exit(0);
    });
});
/**
 * Start Server
 */
server.listen(port, () => {
    console.log(`[Server] Operations Assistant running on port ${port}`);
    console.log(`[Server] WebSocket: ws://localhost:${port}`);
    console.log(`[Server] Health: http://localhost:${port}/health`);
    console.log(`[Server] Prometheus: ${prometheusUrl}`);
    console.log(`[Server] Grafana: ${grafanaUrl}`);
    console.log(`[Server] Available Actions: ${advancedActions.length}`);
});
export default app;
//# sourceMappingURL=index.js.map