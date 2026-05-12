import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import axios from 'axios';
import { WebSocketManager } from './websocket-manager.js';
import { GrafanaClient } from './grafana-client.js';
import { advancedActions } from './actions.js';
import {
  getFederatedOverview,
  getIntelligenceScoreboard,
  getRoundStatus,
} from './federated-intelligence.js';
import {
  queryPrometheus,
  queryPrometheusRange,
  queryPrometheusHealth,
  parseRelativeTime,
  KEY_METRICS,
} from './prometheus-client.js';
import http from 'http';
import WebSocket, { WebSocketServer } from 'ws';
import { AgUiEvent, AgUiEventSchema, A2UiEnvelope, A2UiEnvelopeSchema } from './protocol/types.js';

/**
 * Enhanced CopilotKit Operations Assistant Server
 * Provides real-time metrics, Grafana integration, and advanced AI actions
 */

const app: Express = express();
const port = process.env.PORT || 3000;
const prometheusUrl = process.env.PROMETHEUS_URL || 'http://prometheus:9090';
const grafanaUrl = process.env.GRAFANA_URL || 'http://grafana:3000';
const corsOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
const corsMethods = (process.env.CORS_METHODS || 'GET,POST,OPTIONS')
  .split(',')
  .map((method) => method.trim())
  .filter(Boolean);

// Middleware
app.use(
  cors({
    origin: corsOrigins.length > 0 ? corsOrigins : false,
    methods: corsMethods,
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  })
);
app.use(express.json());

// Create HTTP server for WebSocket support
const server = http.createServer(app);

// WebSocket Manager
const wsManager = new WebSocketManager(prometheusUrl);
const wss = new WebSocketServer({ server });

// Grafana Client
const grafanaClient = new GrafanaClient(grafanaUrl);

function createAgUiEvent(
  kind: AgUiEvent['kind'],
  payload: Record<string, unknown>,
  sessionId?: string
): AgUiEvent {
  return {
    version: '1.0',
    eventId: `evt_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    timestamp: new Date().toISOString(),
    sessionId,
    kind,
    payload,
  };
}

function emitSseEvent(res: Response, event: AgUiEvent) {
  const validated = AgUiEventSchema.safeParse(event);
  if (!validated.success) {
    return;
  }

  res.write(`event: ag-ui\n`);
  res.write(`data: ${JSON.stringify(validated.data)}\n\n`);
}

/**
 * WebSocket Connection Handler
 */
wss.on('connection', (ws: WebSocket, _req: http.IncomingMessage) => {
  const clientId = `client_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  const remoteAddress = _req.socket.remoteAddress || 'unknown';

  console.log(`[Server] New WebSocket connection: ${clientId} from ${remoteAddress}`);
  ws.on('error', (error) => {
    console.error(`[Server] WebSocket error for ${clientId}:`, error);
  });
  ws.on('close', (code, reason) => {
    const closeReason = reason.toString() || 'no reason provided';
    console.log(`[Server] WebSocket closed: ${clientId} code=${code} reason=${closeReason}`);
  });
  ws.on('message', (message) => {
    const preview = message.toString().slice(0, 160);
    console.log(`[Server] WebSocket message from ${clientId}: ${preview}`);
  });
  wsManager.registerClient(clientId, ws, remoteAddress);

  // Send welcome message
  ws.send(
    JSON.stringify({
      type: 'connected',
      clientId,
      message: 'Connected to Operations Assistant',
      timestamp: Date.now(),
    })
  );
});

/**
 * Health Check Endpoint
 */
app.get(['/health', '/api/health'], (req: Request, res: Response) => {
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
app.get('/api/prometheus/health', async (req: Request, res: Response) => {
  try {
    const isHealthy = await queryPrometheusHealth();
    res.json({
      healthy: isHealthy,
      message: isHealthy ? 'Prometheus is healthy' : 'Prometheus is unreachable',
    });
  } catch (error) {
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
app.get('/api/prometheus/key-metrics', (req: Request, res: Response) => {
  res.json({
    keyMetrics: KEY_METRICS,
  });
});

/**
 * Prometheus Query Endpoint
 */
app.post('/api/query', async (req: Request, res: Response) => {
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
  } catch (error) {
    console.error('[Server] Query error:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Query failed',
    });
  }
});

/**
 * Prometheus Instant Query Endpoint
 */
app.get('/api/query/instant', async (req: Request, res: Response) => {
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
  } catch (error) {
    console.error('[Server] Instant query error:', error);
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Query failed',
    });
  }
});

/**
 * Grafana Dashboards Endpoint
 */
app.get('/api/grafana/dashboards', async (req: Request, res: Response) => {
  try {
    const dashboards = await grafanaClient.getDashboards();
    res.json({
      success: true,
      dashboards,
    });
  } catch (error) {
    console.error('[Server] Dashboard fetch error:', error);
    res.status(500).json({ error: 'Failed to fetch dashboards' });
  }
});

/**
 * Grafana Dashboard Detail Endpoint
 */
app.get('/api/grafana/dashboards/:uid', async (req: Request, res: Response) => {
  const { uid } = req.params;

  try {
    const dashboard = await grafanaClient.getDashboardByUid(uid);
    if (!dashboard) {
      return res.status(404).json({ error: 'Dashboard not found' });
    }
    res.json(dashboard);
  } catch (error) {
    console.error('[Server] Dashboard detail error:', error);
    res.status(500).json({ error: 'Failed to fetch dashboard details' });
  }
});

/**
 * Grafana Search Endpoint
 */
app.get('/api/grafana/search', async (req: Request, res: Response) => {
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
  } catch (error) {
    console.error('[Server] Grafana search error:', error);
    res.status(500).json({ error: 'Search failed' });
  }
});

/**
 * Grafana Alerts Endpoint
 */
app.get('/api/grafana/alerts', async (req: Request, res: Response) => {
  try {
    const alerts = await grafanaClient.getAlerts();
    res.json({
      success: true,
      alerts,
    });
  } catch (error) {
    console.error('[Server] Alerts fetch error:', error);
    res.status(500).json({ error: 'Failed to fetch alerts' });
  }
});

/**
 * Grafana Annotations Endpoint
 */
app.get('/api/grafana/annotations', async (req: Request, res: Response) => {
  const { dashboardId, panelId, tags } = req.query;

  try {
      const annotationTags =
        typeof tags === 'string'
          ? [tags]
          : Array.isArray(tags)
            ? tags.filter((tag): tag is string => typeof tag === 'string')
            : undefined;
      const annotations = await grafanaClient.getAnnotations(
        dashboardId ? parseInt(dashboardId as string) : undefined,
        panelId ? parseInt(panelId as string) : undefined,
        annotationTags
      );
    res.json({
      success: true,
      annotations,
    });
  } catch (error) {
    console.error('[Server] Annotations fetch error:', error);
    res.status(500).json({ error: 'Failed to fetch annotations' });
  }
});

/**
 * WebSocket Subscriptions Endpoint
 */
app.get('/api/subscriptions', (req: Request, res: Response) => {
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
app.get('/api/actions', (req: Request, res: Response) => {
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
 * Ops Summary Endpoint
 * Provides a lightweight status summary for app sidebar cards.
 */
app.get('/api/ops/summary', async (_req: Request, res: Response) => {
  try {
    const federatedOverviewPromise = getFederatedOverview();
    const [promHealthy, grafanaHealth, alertsResponse, uptimeResponse, errorRateResponse, federatedOverview] =
      await Promise.all([
        queryPrometheusHealth(),
        grafanaClient.getHealth(),
        grafanaClient.getAlerts(),
        axios.get(`${prometheusUrl}/api/v1/query`, {
          params: {
            query: 'avg(up)',
          },
          timeout: 5000,
        }),
        axios.get(`${prometheusUrl}/api/v1/query`, {
          params: {
            query: 'sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))',
          },
          timeout: 5000,
        }),
        federatedOverviewPromise,
      ]);

    const uptimeRaw = parseFloat(uptimeResponse.data?.data?.result?.[0]?.value?.[1] || '0');
    const errorRateRaw = parseFloat(
      errorRateResponse.data?.data?.result?.[0]?.value?.[1] || '0'
    );

    const uptimePercent = Math.max(0, Math.min(100, uptimeRaw * 100));
    const errorRatePercent = Math.max(0, errorRateRaw * 100);
    const activeAlerts = Array.isArray(alertsResponse)
      ? alertsResponse.filter((alert) => alert.state !== 'ok').length
      : 0;

    const status: 'healthy' | 'degraded' | 'down' =
      promHealthy && grafanaHealth && activeAlerts < 5 && errorRatePercent < 1
        ? 'healthy'
        : promHealthy || grafanaHealth
          ? 'degraded'
          : 'down';

    const recentActions = [
      `Prometheus: ${promHealthy ? 'reachable' : 'unreachable'}`,
      `Grafana: ${grafanaHealth ? grafanaHealth.status : 'unreachable'}`,
      `HTTP error rate (5m): ${errorRatePercent.toFixed(2)}%`,
      `WebSocket clients: ${wsManager.getClientCount()}`,
    ];

    res.json({
      status,
      uptimePercent,
      activeAlerts,
      recentActions,
      federatedIntelligence: {
        roundId: federatedOverview.roundId,
        phase: federatedOverview.phase,
        progress: federatedOverview.progress,
        modelConfidence: federatedOverview.modelConfidence,
        driftScore: federatedOverview.driftScore,
        convergenceTrend: federatedOverview.convergenceTrend,
        participatingNodes: federatedOverview.participatingNodes,
        honestNodeRatio: federatedOverview.honestNodeRatio,
        topContributors: federatedOverview.topContributors,
        anomalies: federatedOverview.anomalies,
        recommendedAction: federatedOverview.recommendedAction,
        requiresConfirmation: federatedOverview.requiresConfirmation,
        reasoningTrail: federatedOverview.supportingEvidence,
      },
    });
  } catch (error) {
    console.error('[Server] Ops summary error:', error);
    res.status(500).json({
      status: 'down',
      uptimePercent: 0,
      activeAlerts: 0,
      recentActions: ['Summary unavailable'],
      federatedIntelligence: {
        roundId: 'round-unknown',
        phase: 'failure',
        progress: 0,
        modelConfidence: 0,
        driftScore: 0,
        convergenceTrend: 'degrading',
        participatingNodes: 0,
        honestNodeRatio: 0,
        topContributors: [],
        anomalies: [],
        recommendedAction: 'Restore federation connectivity before executing FL operations.',
        requiresConfirmation: false,
        reasoningTrail: ['Federated intelligence summary unavailable.'],
      },
    });
  }
});

/**
 * Federated Intelligence Scoreboard Endpoint
 */
app.get('/api/fl/intelligence/scoreboard', async (_req: Request, res: Response) => {
  try {
    const scoreboard = await getIntelligenceScoreboard();
    res.json({ success: true, scoreboard });
  } catch (error) {
    console.error('[Server] FL scoreboard error:', error);
    res.status(500).json({ success: false, error: 'Failed to build federated intelligence scoreboard' });
  }
});

/**
 * Federated Learning Round Status Endpoint
 */
app.get('/api/fl/round/status', async (_req: Request, res: Response) => {
  try {
    const status = await getRoundStatus();
    res.json({ success: true, status });
  } catch (error) {
    console.error('[Server] FL round status error:', error);
    res.status(500).json({ success: false, error: 'Failed to resolve federated round status' });
  }
});

/**
 * AG-UI Runtime Stream Endpoint
 * Emits protocol-typed events to drive frontend interactive UIs.
 */
app.get('/api/agent/events', async (req: Request, res: Response) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache, no-transform');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  const sessionId = typeof req.query.sessionId === 'string' ? req.query.sessionId : undefined;

  const summary = {
    activeAlerts: 3,
    errorBudgetBurnRate: 1.7,
    impactedServices: ['api-gateway', 'orders-service'],
  };

  const triageEnvelope: A2UiEnvelope = {
    version: '1.0',
    surface: 'main',
    layout: {
      type: 'stack',
      components: [
        {
          id: 'alert-triage-title',
          kind: 'text',
          props: {
            title: 'Alert Triage Workflow',
            body: 'Prioritize active alerts, identify blast radius, and execute first response.',
          },
        },
        {
          id: 'alert-triage-kpi',
          kind: 'metric',
          props: {
            label: 'Active Alerts',
            value: summary.activeAlerts,
            trend: 'up',
            severity: 'warning',
          },
        },
        {
          id: 'alert-triage-services',
          kind: 'table',
          props: {
            columns: ['service', 'status', 'suggestedAction'],
            rows: summary.impactedServices.map((service) => ({
              service,
              status: 'degraded',
              suggestedAction: 'Open runbook and inspect latency panel',
            })),
          },
        },
      ],
    },
    actions: [
      {
        id: 'ack-alerts',
        label: 'Acknowledge Alerts',
        intent: 'alerts.acknowledge',
        confirm: true,
      },
      {
        id: 'open-dashboard',
        label: 'Open Service Dashboard',
        intent: 'dashboard.open.orders',
      },
    ],
  };

  const validEnvelope = A2UiEnvelopeSchema.safeParse(triageEnvelope);
  if (!validEnvelope.success) {
    res.status(500).end();
    return;
  }

  emitSseEvent(
    res,
    createAgUiEvent(
      'agent.message.delta',
      {
        text: 'Collecting incident context and preparing triage surface...',
      },
      sessionId
    )
  );

  const timers: NodeJS.Timeout[] = [];
  timers.push(
    setTimeout(() => {
      emitSseEvent(
        res,
        createAgUiEvent(
          'agent.ui.replace',
          {
            envelope: validEnvelope.data,
          },
          sessionId
        )
      );
    }, 300)
  );

  timers.push(
    setTimeout(() => {
      emitSseEvent(
        res,
        createAgUiEvent(
          'agent.state.changed',
          {
            phase: 'triage.ready',
            errorBudgetBurnRate: summary.errorBudgetBurnRate,
          },
          sessionId
        )
      );
      emitSseEvent(
        res,
        createAgUiEvent(
          'agent.message.final',
          {
            text: 'Triage surface ready. Review impacted services and execute a response action.',
          },
          sessionId
        )
      );
    }, 600)
  );

  const heartbeat = setInterval(() => {
    res.write(`: keepalive\n\n`);
  }, 15000);

  req.on('close', () => {
    timers.forEach((timer) => clearTimeout(timer));
    clearInterval(heartbeat);
    res.end();
  });
});

/**
 * Agent Intent Endpoint
 * Executes first response intents triggered from A2UI action buttons.
 */
app.post('/api/agent/intent', (req: Request, res: Response) => {
  const { intent } = req.body as { intent?: string };

  if (!intent) {
    return res.status(400).json({ error: 'Intent is required' });
  }

  if (intent === 'alerts.acknowledge') {
    return res.json({
      success: true,
      message: 'Alerts acknowledged and incident timer started.',
      next: 'Run latency and dependency checks for impacted services.',
    });
  }

  if (intent === 'dashboard.open.orders') {
    return res.json({
      success: true,
      message: 'Orders service dashboard selected.',
      dashboardUid: 'orders-overview',
    });
  }

  res.status(400).json({
    success: false,
    message: `Unsupported intent: ${intent}`,
  });
});

/**
 * Acknowledge/confirm an anomaly for manual review.
 */
app.post('/api/fl/anomalies/ack', async (req: Request, res: Response) => {
  const { nodeId } = req.body as { nodeId?: string };
  if (!nodeId) return res.status(400).json({ success: false, error: 'nodeId required' });

  try {
    // Update metrics counter if available
    try {
      const { anomaliesCounter } = await import('./federated-intelligence.js');
      anomaliesCounter.inc({ category: 'acknowledge', severity: 'info' }, 1);
    } catch (e) {
      // ignore metric update errors
    }

    // In real system: persist acknowledgment, trigger audit workflow
    res.json({ success: true, message: `Anomaly ${nodeId} acknowledged` });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Failed to acknowledge anomaly' });
  }
});

/**
 * Test Metric Generation Endpoint (for demo purposes)
 */
app.get('/api/test-metrics', async (req: Request, res: Response) => {
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
  } catch (error) {
    res.status(500).json({ error: 'Failed to generate test metrics' });
  }
});

/**
 * Prometheus metrics endpoint
 */
app.get('/metrics', async (_req: Request, res: Response) => {
  try {
    // dynamic import to avoid errors if prom-client missing during some builds
    const { getMetrics } = await import('./federated-intelligence.js');
    const metrics = await getMetrics();
    res.setHeader('Content-Type', 'text/plain; version=0.0.4');
    res.send(metrics);
  } catch (error) {
    res.status(500).send('# metrics unavailable\n');
  }
});

/**
 * Parse time range string (e.g., "1h" -> seconds)
 */
function parseTimeRange(timeRange: string): number {
  const unitMap: { [key: string]: number } = {
    m: 60,
    h: 3600,
    d: 86400,
    w: 604800,
  };

  const match = timeRange.match(/^(\d+)([mhdw])$/);
  if (!match) return 3600; // Default to 1 hour

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
