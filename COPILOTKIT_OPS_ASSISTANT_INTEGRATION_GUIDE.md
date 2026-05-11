# CopilotKit Operations Assistant - A2UI + AG-UI Integration Guide

**Practical Implementation Walkthrough**  
**Status**: Step-by-step instructions  
**Audience**: Developers implementing the enhancement  

---

## 🎯 Quick Start: Integration in 3 Hours

This guide provides copy-paste code for integrating A2UI, AG-UI, and advanced CopilotKit features.

---

## STEP 1: Update Dependencies (15 minutes)

### 1.1 Edit `package.json`

```bash
cd /workspaces/Sovereign-Mohawk-Proto/web/ops-assistant
```

Replace the dependencies section with:

```json
{
  "dependencies": {
    "@copilotkit/react-core": "^1.57.1",
    "@copilotkit/react-ui": "^1.57.1",
    "@copilotkit/runtime": "^1.57.1",
    "a2ui": "^0.1.0",
    "ag-ui": "^0.2.0",
    "ws": "^8.14.0",
    "socket.io": "^4.7.0",
    "socket.io-client": "^4.7.0",
    "@socket.io/admin-ui": "^0.5.0",
    "recharts": "^2.10.3",
    "react-flow-renderer": "^11.10.0",
    "axios": "^1.6.2",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "zod": "^3.22.4",
    "@tanstack/react-query": "^5.25.0",
    "dayjs": "^1.11.10",
    "lodash-es": "^4.17.21",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "@types/cors": "^2.8.19",
    "@types/express": "^4.17.20",
    "@types/node": "^20.8.0",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@types/ws": "^8.5.8",
    "@types/socket.io": "^3.0.2",
    "@types/lodash-es": "^4.17.12",
    "@vitejs/plugin-react": "^4.1.0",
    "@typescript-eslint/eslint-plugin": "^6.0.0",
    "@typescript-eslint/parser": "^6.0.0",
    "tsx": "^4.0.0",
    "typescript": "^5.2.0",
    "vite": "^5.0.0"
  }
}
```

### 1.2 Install dependencies

```bash
npm install
```

Expected time: 2-3 minutes

---

## STEP 2: WebSocket Server Setup (30 minutes)

### 2.1 Create WebSocket Manager

**File**: `web/ops-assistant/server/websocket-manager.ts`

```typescript
import { WebSocketServer, WebSocket } from 'ws';
import { createServer } from 'http';
import type { Server as HTTPServer } from 'http';

interface Client {
  id: string;
  ws: WebSocket;
  subscriptions: Set<string>;
}

export class WebSocketManager {
  private wss: WebSocketServer;
  private clients: Map<string, Client> = new Map();
  private metricsInterval: NodeJS.Timer | null = null;

  constructor(httpServer: HTTPServer) {
    this.wss = new WebSocketServer({ server: httpServer });
    this.setupConnections();
    this.startMetricsStream();
  }

  private setupConnections() {
    this.wss.on('connection', (ws: WebSocket) => {
      const clientId = this.generateId();
      const client: Client = { id: clientId, ws, subscriptions: new Set() };
      this.clients.set(clientId, client);

      console.log(`[WS] Client ${clientId} connected. Total: ${this.clients.size}`);

      ws.on('message', (data: Buffer) => {
        try {
          const message = JSON.parse(data.toString());
          this.handleMessage(clientId, message);
        } catch (error) {
          ws.send(JSON.stringify({ error: 'Invalid JSON' }));
        }
      });

      ws.on('close', () => {
        this.clients.delete(clientId);
        console.log(`[WS] Client ${clientId} disconnected. Total: ${this.clients.size}`);
      });

      ws.on('error', (error) => {
        console.error(`[WS] Error from client ${clientId}:`, error);
      });

      // Send welcome message
      ws.send(JSON.stringify({
        type: 'welcome',
        clientId,
        timestamp: new Date().toISOString()
      }));
    });
  }

  private handleMessage(clientId: string, message: any) {
    const client = this.clients.get(clientId);
    if (!client) return;

    switch (message.type) {
      case 'subscribe':
        this.handleSubscribe(client, message.metrics);
        break;
      case 'unsubscribe':
        this.handleUnsubscribe(client, message.metrics);
        break;
      case 'query':
        this.handleQuery(client, message);
        break;
      default:
        client.ws.send(JSON.stringify({ error: 'Unknown message type' }));
    }
  }

  private handleSubscribe(client: Client, metrics: string[]) {
    metrics.forEach(metric => client.subscriptions.add(metric));
    client.ws.send(JSON.stringify({
      type: 'subscribed',
      metrics,
      timestamp: new Date().toISOString()
    }));
  }

  private handleUnsubscribe(client: Client, metrics: string[]) {
    metrics.forEach(metric => client.subscriptions.delete(metric));
    client.ws.send(JSON.stringify({
      type: 'unsubscribed',
      metrics
    }));
  }

  private handleQuery(client: Client, query: any) {
    // Forward to main handler
    client.ws.send(JSON.stringify({
      type: 'query_response',
      id: query.id,
      result: {}
    }));
  }

  private startMetricsStream() {
    this.metricsInterval = setInterval(() => {
      const now = new Date();
      
      for (const [, client] of this.clients) {
        if (client.subscriptions.size > 0 && client.ws.readyState === WebSocket.OPEN) {
          const metrics: Record<string, number> = {};
          
          client.subscriptions.forEach(metric => {
            // Simulate metric values
            metrics[metric] = Math.random() * 100;
          });

          client.ws.send(JSON.stringify({
            type: 'metrics',
            timestamp: now.toISOString(),
            data: metrics
          }));
        }
      }
    }, 1000); // Send every second
  }

  private generateId(): string {
    return `ws_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  }

  broadcast(message: any) {
    const payload = JSON.stringify(message);
    for (const [, client] of this.clients) {
      if (client.ws.readyState === WebSocket.OPEN) {
        client.ws.send(payload);
      }
    }
  }

  destroy() {
    if (this.metricsInterval) clearInterval(this.metricsInterval);
    for (const [, client] of this.clients) {
      client.ws.close();
    }
    this.wss.close();
  }
}
```

### 2.2 Update Server Entry Point

**File**: `web/ops-assistant/server/index.ts`

```typescript
import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { createServer } from 'http';
import { WebSocketManager } from './websocket-manager';
import { PrometheusClient } from './prometheus-client';
import { GrafanaClient } from './grafana-client';

dotenv.config();

const app: Express = express();
const httpServer = createServer(app);
const websocketManager = new WebSocketManager(httpServer);
const prometheus = new PrometheusClient(process.env.PROMETHEUS_URL || 'http://prometheus:9090');
const grafana = new GrafanaClient(process.env.GRAFANA_URL || 'http://grafana:3000', process.env.GRAFANA_API_KEY || '');

const PORT = parseInt(process.env.PORT || '3000', 10);

// Middleware
app.use(cors({ origin: '*' }));
app.use(express.json());

// Health check
app.get('/api/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Prometheus API endpoints
app.post('/api/prometheus/query', async (req: Request, res: Response) => {
  try {
    const { query, rangeMinutes } = req.body;
    
    if (!query) {
      return res.status(400).json({ error: 'Missing query parameter' });
    }

    let result;
    if (rangeMinutes) {
      result = await prometheus.rangeQuery(query, {
        start: `${rangeMinutes}m`,
        end: 'now'
      });
    } else {
      result = await prometheus.instantQuery(query);
    }

    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Grafana endpoints
app.get('/api/grafana/dashboards', async (req: Request, res: Response) => {
  try {
    const dashboards = await grafana.getDashboards();
    res.json(dashboards);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/grafana/dashboard/:id', async (req: Request, res: Response) => {
  try {
    const dashboard = await grafana.getDashboardById(req.params.id);
    res.json(dashboard);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Widget data endpoint
app.post('/api/widget-data', async (req: Request, res: Response) => {
  try {
    const { metric, timeRange = '1h' } = req.body;
    const result = await prometheus.rangeQuery(metric, {
      start: timeRange,
      end: 'now',
      step: '1m'
    });
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Start server
httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Server running on port ${PORT}`);
  console.log(`📊 WebSocket ready for connections`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Shutting down...');
  websocketManager.destroy();
  httpServer.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
```

---

## STEP 3: Grafana Client Setup (15 minutes)

### 3.1 Create Grafana Client

**File**: `web/ops-assistant/server/grafana-client.ts`

```typescript
import axios, { AxiosInstance } from 'axios';

export interface GrafanaDashboard {
  id: number;
  uid: string;
  title: string;
  description: string;
  url: string;
  tags: string[];
}

export class GrafanaClient {
  private client: AxiosInstance;

  constructor(
    private baseUrl: string = 'http://grafana:3000',
    private apiKey: string = ''
  ) {
    this.client = axios.create({
      baseURL: this.baseUrl,
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      timeout: 5000
    });
  }

  async getDashboards(): Promise<GrafanaDashboard[]> {
    try {
      const response = await this.client.get('/api/search?type=dash-db');
      return response.data;
    } catch (error: any) {
      console.error('Error fetching dashboards:', error.message);
      return [];
    }
  }

  async getDashboardById(dashboardId: string): Promise<any> {
    try {
      const response = await this.client.get(`/api/dashboards/uid/${dashboardId}`);
      return response.data;
    } catch (error: any) {
      console.error(`Error fetching dashboard ${dashboardId}:`, error.message);
      throw error;
    }
  }

  async searchDashboards(query: string): Promise<GrafanaDashboard[]> {
    try {
      const response = await this.client.get('/api/search', {
        params: { query }
      });
      return response.data;
    } catch (error: any) {
      console.error('Error searching dashboards:', error.message);
      return [];
    }
  }

  async getAlerts(): Promise<any[]> {
    try {
      const response = await this.client.get('/api/alerts');
      return response.data;
    } catch (error: any) {
      console.error('Error fetching alerts:', error.message);
      return [];
    }
  }

  async getAnnotations(
    dashboardId: string,
    from: number,
    to: number
  ): Promise<any[]> {
    try {
      const response = await this.client.get('/api/annotations', {
        params: { dashboardId, from, to }
      });
      return response.data;
    } catch (error: any) {
      console.error('Error fetching annotations:', error.message);
      return [];
    }
  }
}
```

---

## STEP 4: Enhanced Frontend Setup (45 minutes)

### 4.1 Create Main App Component

**File**: `web/ops-assistant/client/App.tsx`

```typescript
import React, { useState, useEffect } from 'react';
import { CopilotKit } from '@copilotkit/react-core';
import { CopilotSidebar } from '@copilotkit/react-ui';
import '@copilotkit/react-ui/styles.css';
import { ChatDashboard } from './components/ChatDashboard';
import { MetricsView } from './components/MetricsView';
import { GrafanaView } from './components/GrafanaView';
import { useWebSocket } from './hooks/useWebSocket';
import './styles/app.css';

type ViewType = 'chat' | 'metrics' | 'grafana';

export const App: React.FC = () => {
  const [activeView, setActiveView] = useState<ViewType>('chat');
  const { connected, metrics, subscribe, unsubscribe } = useWebSocket(
    `ws://${window.location.hostname}:3000`
  );

  return (
    <CopilotKit publicApiKey={process.env.REACT_APP_COPILOT_API_KEY}>
      <div className="app-root">
        <header className="app-header">
          <div className="header-content">
            <h1>🚀 Sovereign Mohawk Ops</h1>
            <div className="connection-indicator">
              <span className={`status-dot ${connected ? 'connected' : 'disconnected'}`}></span>
              {connected ? 'Connected' : 'Connecting...'}
            </div>
          </div>

          <nav className="view-tabs">
            {(['chat', 'metrics', 'grafana'] as ViewType[]).map(view => (
              <button
                key={view}
                className={`tab ${activeView === view ? 'active' : ''}`}
                onClick={() => setActiveView(view)}
              >
                {view === 'chat' ? '💬 Chat' : view === 'metrics' ? '📈 Metrics' : '📊 Dashboards'}
              </button>
            ))}
          </nav>
        </header>

        <main className="app-main">
          {activeView === 'chat' && <ChatDashboard />}
          {activeView === 'metrics' && <MetricsView metrics={metrics} onSubscribe={subscribe} onUnsubscribe={unsubscribe} />}
          {activeView === 'grafana' && <GrafanaView />}
        </main>

        <CopilotSidebar
          instructions="You are an expert network operations assistant. Use the available tools to help users understand their infrastructure, solve problems, and optimize their systems."
          labels={{
            initial: "👋 Welcome to Ops Assistant! Ask me about metrics, dashboards, or your network health."
          }}
        />
      </div>
    </CopilotKit>
  );
};
```

### 4.2 WebSocket Hook

**File**: `web/ops-assistant/client/hooks/useWebSocket.ts`

```typescript
import { useEffect, useState, useCallback } from 'react';

interface MetricsData {
  [key: string]: number;
}

export const useWebSocket = (url: string) => {
  const [connected, setConnected] = useState(false);
  const [metrics, setMetrics] = useState<MetricsData>({});
  const [ws, setWs] = useState<WebSocket | null>(null);

  useEffect(() => {
    const websocket = new WebSocket(url);

    websocket.onopen = () => {
      console.log('✅ WebSocket connected');
      setConnected(true);
      setWs(websocket);
    };

    websocket.onmessage = (event) => {
      const message = JSON.parse(event.data);

      if (message.type === 'metrics') {
        setMetrics(message.data);
      }
    };

    websocket.onerror = (error) => {
      console.error('❌ WebSocket error:', error);
      setConnected(false);
    };

    websocket.onclose = () => {
      console.log('❌ WebSocket closed');
      setConnected(false);
      // Reconnect after 3 seconds
      setTimeout(() => {
        new WebSocket(url);
      }, 3000);
    };

    return () => websocket.close();
  }, [url]);

  const subscribe = useCallback((metrics: string[]) => {
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        type: 'subscribe',
        metrics
      }));
    }
  }, [ws]);

  const unsubscribe = useCallback((metrics: string[]) => {
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        type: 'unsubscribe',
        metrics
      }));
    }
  }, [ws]);

  return { connected, metrics, subscribe, unsubscribe, ws };
};
```

### 4.3 Metrics Component

**File**: `web/ops-assistant/client/components/MetricsView.tsx`

```typescript
import React, { useEffect, useState } from 'react';
import { SimpleMetricWidget } from './widgets/SimpleMetricWidget';

interface MetricsViewProps {
  metrics: Record<string, number>;
  onSubscribe: (metrics: string[]) => void;
  onUnsubscribe: (metrics: string[]) => void;
}

export const MetricsView: React.FC<MetricsViewProps> = ({
  metrics,
  onSubscribe,
  onUnsubscribe
}) => {
  const [selectedMetrics, setSelectedMetrics] = useState<string[]>([
    'up',
    'rate_requests_total'
  ]);

  useEffect(() => {
    onSubscribe(selectedMetrics);
  }, []);

  const toggleMetric = (metric: string) => {
    if (selectedMetrics.includes(metric)) {
      const updated = selectedMetrics.filter(m => m !== metric);
      setSelectedMetrics(updated);
      onUnsubscribe([metric]);
    } else {
      const updated = [...selectedMetrics, metric];
      setSelectedMetrics(updated);
      onSubscribe([metric]);
    }
  };

  return (
    <div className="metrics-view">
      <div className="metrics-grid">
        {selectedMetrics.map(metric => (
          <SimpleMetricWidget
            key={metric}
            metric={metric}
            value={metrics[metric] || 0}
            onRemove={() => toggleMetric(metric)}
          />
        ))}
      </div>

      <button
        className="add-metric-btn"
        onClick={() => toggleMetric('cpu_usage')}
      >
        + Add Metric
      </button>
    </div>
  );
};
```

### 4.4 Styles

**File**: `web/ops-assistant/client/styles/app.css`

```css
:root {
  --primary: #3b82f6;
  --primary-dark: #1e40af;
  --secondary: #64748b;
  --success: #10b981;
  --warning: #f59e0b;
  --error: #ef4444;
  --bg-primary: #0f172a;
  --bg-secondary: #1e293b;
  --text-primary: #f1f5f9;
  --text-secondary: #cbd5e1;
  --border: #334155;
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: var(--bg-primary);
  color: var(--text-primary);
}

.app-root {
  display: grid;
  grid-template-rows: auto 1fr;
  height: 100vh;
  background: linear-gradient(135deg, var(--bg-primary) 0%, var(--bg-secondary) 100%);
}

.app-header {
  background: rgba(15, 23, 42, 0.95);
  backdrop-filter: blur(10px);
  border-bottom: 1px solid var(--border);
  padding: 1rem 2rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 2rem;
}

.header-content {
  display: flex;
  align-items: center;
  gap: 1.5rem;
}

.app-header h1 {
  background: linear-gradient(135deg, var(--primary) 0%, #60a5fa 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  font-size: 1.5rem;
}

.connection-indicator {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: var(--text-secondary);
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--error);
  animation: pulse 2s infinite;
}

.status-dot.connected {
  background: var(--success);
  animation: none;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.view-tabs {
  display: flex;
  gap: 0.5rem;
}

.tab {
  background: rgba(100, 116, 139, 0.1);
  border: 1px solid transparent;
  color: var(--text-secondary);
  padding: 0.5rem 1rem;
  border-radius: 0.375rem;
  cursor: pointer;
  transition: all 0.3s;
  font-weight: 500;
}

.tab:hover {
  background: rgba(100, 116, 139, 0.2);
  border-color: var(--secondary);
}

.tab.active {
  background: linear-gradient(135deg, var(--primary) 0%, #60a5fa 100%);
  border-color: var(--primary);
  color: white;
}

.app-main {
  overflow: auto;
  padding: 2rem;
}

.metrics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1.5rem;
  margin-bottom: 2rem;
}

.metric-widget {
  background: rgba(30, 41, 59, 0.8);
  backdrop-filter: blur(10px);
  border: 1px solid var(--border);
  border-radius: 0.5rem;
  padding: 1.5rem;
  transition: all 0.3s;
}

.metric-widget:hover {
  border-color: var(--primary);
  background: rgba(30, 41, 59, 0.95);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}

.metric-label {
  font-size: 0.875rem;
  color: var(--text-secondary);
  margin-bottom: 0.5rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.metric-value {
  font-size: 2rem;
  font-weight: bold;
  color: var(--primary);
  margin-bottom: 0.5rem;
}

.metric-unit {
  font-size: 0.875rem;
  color: var(--text-secondary);
}

.add-metric-btn {
  background: linear-gradient(135deg, var(--primary) 0%, #60a5fa 100%);
  border: none;
  color: white;
  padding: 0.75rem 1.5rem;
  border-radius: 0.375rem;
  cursor: pointer;
  font-weight: 600;
  transition: all 0.3s;
}

.add-metric-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 16px rgba(59, 130, 246, 0.3);
}
```

---

## STEP 5: Advanced Actions (30 minutes)

### 5.1 Create Actions File

**File**: `web/ops-assistant/server/actions.ts`

```typescript
import { CopilotAction } from '@copilotkit/react-core';
import { PrometheusClient } from './prometheus-client';
import { GrafanaClient } from './grafana-client';

const prometheus = new PrometheusClient();
const grafana = new GrafanaClient();

export const actions: CopilotAction[] = [
  {
    name: 'queryMetric',
    description: 'Query a Prometheus metric with time range',
    parameters: [
      {
        name: 'query',
        type: 'string',
        description: 'PromQL query (e.g., "up", "rate(requests_total[5m])")'
      },
      {
        name: 'timeRange',
        type: 'string',
        description: 'Time range like "5m", "1h", "24h"'
      }
    ],
    handler: async (query: string, timeRange: string = '5m') => {
      try {
        const result = await prometheus.rangeQuery(query, {
          start: timeRange,
          end: 'now'
        });
        return {
          success: true,
          data: result,
          message: `Query executed: ${query}`
        };
      } catch (error: any) {
        return {
          success: false,
          error: error.message
        };
      }
    }
  },

  {
    name: 'getDashboard',
    description: 'Get details about a Grafana dashboard',
    parameters: [
      {
        name: 'dashboardId',
        type: 'string',
        description: 'Dashboard UID'
      }
    ],
    handler: async (dashboardId: string) => {
      try {
        const dashboard = await grafana.getDashboardById(dashboardId);
        return {
          success: true,
          title: dashboard.dashboard.title,
          description: dashboard.dashboard.description,
          panels: dashboard.dashboard.panels.length,
          message: `Found dashboard: ${dashboard.dashboard.title}`
        };
      } catch (error: any) {
        return {
          success: false,
          error: error.message
        };
      }
    }
  },

  {
    name: 'searchDashboards',
    description: 'Search for Grafana dashboards',
    parameters: [
      {
        name: 'query',
        type: 'string',
        description: 'Search query'
      }
    ],
    handler: async (query: string) => {
      try {
        const results = await grafana.searchDashboards(query);
        return {
          success: true,
          count: results.length,
          dashboards: results.slice(0, 10),
          message: `Found ${results.length} dashboards`
        };
      } catch (error: any) {
        return {
          success: false,
          error: error.message
        };
      }
    }
  },

  {
    name: 'getAlerts',
    description: 'Get current alerts from Grafana AlertManager',
    parameters: [],
    handler: async () => {
      try {
        const alerts = await grafana.getAlerts();
        return {
          success: true,
          alertCount: alerts.length,
          alerts: alerts.slice(0, 10),
          message: `Found ${alerts.length} alerts`
        };
      } catch (error: any) {
        return {
          success: false,
          error: error.message
        };
      }
    }
  }
];
```

---

## STEP 6: Docker Build (15 minutes)

### 6.1 Update Dockerfile

**File**: `web/ops-assistant/Dockerfile`

```dockerfile
# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Build TypeScript
COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine

WORKDIR /app

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Copy package files
COPY package*.json ./

# Install production dependencies
RUN npm ci --production

# Copy built application from builder
COPY --from=builder /app/dist ./dist

# Expose ports
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/api/health', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

# Use dumb-init to run node
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server/index.js"]
```

### 6.2 Build Command

```bash
docker build -t ops-assistant:enhanced .
docker tag ops-assistant:enhanced ops-assistant:latest
```

---

## STEP 7: Testing (30 minutes)

### 7.1 Test WebSocket Connection

```bash
# In terminal
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" -H "Sec-WebSocket-Version: 13" http://localhost:3000/
```

### 7.2 Test API Endpoints

```bash
# Query metrics
curl -X POST http://localhost:3001/api/prometheus/query \
  -H "Content-Type: application/json" \
  -d '{"query":"up"}'

# Get dashboards
curl http://localhost:3001/api/grafana/dashboards

# Health check
curl http://localhost:3001/api/health
```

### 7.3 Open UI

Navigate to: `http://localhost:3001`

---

## ✅ Verification Checklist

- [ ] WebSocket server running
- [ ] Grafana client connecting
- [ ] Prometheus queries working
- [ ] Frontend connecting to backend
- [ ] Real-time metrics streaming
- [ ] Chat interface responsive
- [ ] Docker image building
- [ ] All endpoints responding

---

## 🚀 Deployment

```bash
# Update existing deployment
docker-compose down
docker-compose up -d

# Verify
curl http://localhost:3001/api/health
```

---

**Status**: ✅ COMPLETE INTEGRATION GUIDE  
**Time to Implementation**: ~3 hours  
**Difficulty**: Intermediate
