# CopilotKit Operations Assistant - Advanced Enhancement Plan

**A2UI + AG-UI Integration with Grafana Enhancement**  
**Status**: Ready for Implementation  
**Target**: Top-tier network operations platform  
**Date**: May 11, 2026  

---

## 🎯 Enhancement Overview

Transform the ops-assistant from a basic chat interface into a sophisticated, multi-modal AI-powered operations platform by integrating:

1. **A2UI (Google DeepMind)** - Interactive UI patterns for agent-driven interactions
2. **AG-UI (CopilotKit)** - Enhanced transport layer for agent communication
3. **Advanced CopilotKit Actions** - Rich toolset for network operations
4. **Grafana Deep Integration** - Bidirectional dashboard synchronization
5. **Real-time Network Monitoring** - Live metric streaming and alerts
6. **Interactive Visualizations** - Charts, gauges, and network topology

---

## 📐 Architecture Enhancement

### Current vs. Enhanced

```
CURRENT ARCHITECTURE:
Browser → CopilotKit Frontend ↔ Express Backend → Prometheus
              (basic chat)              (REST API)

ENHANCED ARCHITECTURE:
┌─ A2UI UI Framework (Interactive patterns)
│  └─ CopilotKit Provider (Agent orchestration)
│     ├─ Chat Interface (Natural language)
│     ├─ Interactive Widgets (UI from agents)
│     ├─ Grafana Panels (Real dashboards)
│     └─ Network Topology (Visual system)
│
├─ AG-UI Transport Layer (Bidirectional)
│  ├─ WebSocket (Real-time updates)
│  ├─ Server-Sent Events (Streaming)
│  └─ REST API (Standard queries)
│
└─ Enhanced Backend (Rich actions)
   ├─ Prometheus Client (Metrics)
   ├─ Grafana Client (Dashboards)
   ├─ Alert Manager (Incidents)
   ├─ Network Analyzer (Topology)
   └─ ML Predictor (Anomalies)
```

---

## 🔧 Implementation Plan (3-Phase)

### PHASE 1: Foundation (Week 1)
- [ ] Add A2UI and AG-UI packages
- [ ] Implement WebSocket server
- [ ] Create interactive widget system
- [ ] Set up Grafana API client

### PHASE 2: Core Features (Week 2)
- [ ] Implement 10+ advanced actions
- [ ] Build interactive visualizations
- [ ] Add Grafana integration
- [ ] Real-time metric streaming

### PHASE 3: Polish (Week 3)
- [ ] Network topology visualization
- [ ] Anomaly detection
- [ ] Alert integration
- [ ] Performance optimization

---

## 📦 Phase 1: Foundation Setup (Week 1)

### 1.1: Update Dependencies

**File**: `web/ops-assistant/package.json`

Add these packages:

```json
{
  "dependencies": {
    "@copilotkit/react-core": "^1.57.1",
    "@copilotkit/react-ui": "^1.57.1",
    "@copilotkit/react-actions": "^1.57.1",
    "a2ui": "^0.1.0",
    "ag-ui": "^0.2.0",
    "ws": "^8.14.0",
    "socket.io": "^4.7.0",
    "socket.io-client": "^4.7.0",
    "recharts": "^2.10.0",
    "react-flow-renderer": "^11.0.0",
    "axios": "^1.6.2",
    "zod": "^3.22.0",
    "react-query": "^3.39.0",
    "@tanstack/react-query": "^5.0.0",
    "dayjs": "^1.11.0",
    "lodash-es": "^4.17.0"
  },
  "devDependencies": {
    "@types/ws": "^8.5.0",
    "@types/socket.io": "^3.0.0",
    "@types/lodash-es": "^4.17.0"
  }
}
```

---

### 1.2: Enhanced Backend Structure

**New File**: `web/ops-assistant/server/websocket-manager.ts`

```typescript
import { WebSocketServer, WebSocket } from 'ws';
import { Server as SocketIOServer } from 'socket.io';
import { createServer } from 'http';

export class WebSocketManager {
  private wss: WebSocketServer;
  private io: SocketIOServer;
  private clients: Map<string, WebSocket> = new Map();

  constructor(httpServer: any) {
    // WebSocket for real-time metric streaming
    this.wss = new WebSocketServer({ server: httpServer });
    
    // Socket.io for bidirectional communication
    this.io = new SocketIOServer(httpServer, {
      cors: { origin: '*', methods: ['GET', 'POST'] }
    });

    this.setupHandlers();
  }

  private setupHandlers() {
    // WebSocket: Raw metric streams
    this.wss.on('connection', (ws: WebSocket) => {
      const clientId = this.generateClientId();
      this.clients.set(clientId, ws);

      ws.on('message', (data) => {
        this.handleMetricStream(data, clientId);
      });

      ws.on('close', () => {
        this.clients.delete(clientId);
      });
    });

    // Socket.io: Bidirectional events
    this.io.on('connection', (socket) => {
      console.log(`Client ${socket.id} connected`);

      socket.on('subscribe_metrics', (metrics) => {
        this.subscribeToMetrics(socket, metrics);
      });

      socket.on('query_dashboard', (params) => {
        this.queryDashboard(socket, params);
      });

      socket.on('trigger_action', (action) => {
        this.triggerAction(socket, action);
      });
    });
  }

  async handleMetricStream(data: any, clientId: string) {
    // Stream metrics in real-time
    const ws = this.clients.get(clientId);
    if (!ws) return;

    try {
      const metrics = await this.fetchMetrics(data);
      ws.send(JSON.stringify(metrics));
    } catch (error) {
      ws.send(JSON.stringify({ error: error.message }));
    }
  }

  async subscribeToMetrics(socket: any, metrics: string[]) {
    // Emit metric updates every second
    const interval = setInterval(async () => {
      const data = await this.fetchMetrics(metrics);
      socket.emit('metrics_update', data);
    }, 1000);

    socket.on('disconnect', () => clearInterval(interval));
  }

  async queryDashboard(socket: any, params: any) {
    // Query specific dashboard data
    try {
      const dashboard = await this.getDashboardData(params);
      socket.emit('dashboard_data', dashboard);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  }

  async triggerAction(socket: any, action: any) {
    // Execute CopilotKit action
    try {
      const result = await this.executeAction(action);
      socket.emit('action_result', result);
    } catch (error) {
      socket.emit('error', { message: error.message });
    }
  }

  private async fetchMetrics(queries: string[]): Promise<any> {
    // Implementation: fetch from Prometheus
    return {};
  }

  private async getDashboardData(params: any): Promise<any> {
    // Implementation: fetch from Grafana
    return {};
  }

  private async executeAction(action: any): Promise<any> {
    // Implementation: execute action
    return {};
  }

  private generateClientId(): string {
    return `client_${Date.now()}_${Math.random().toString(36)}`;
  }
}
```

---

### 1.3: Grafana API Client

**New File**: `web/ops-assistant/server/grafana-client.ts`

```typescript
import axios, { AxiosInstance } from 'axios';

export class GrafanaClient {
  private client: AxiosInstance;
  private baseUrl: string;
  private apiKey: string;

  constructor(baseUrl: string = 'http://grafana:3000', apiKey: string = '') {
    this.baseUrl = baseUrl;
    this.apiKey = apiKey;
    this.client = axios.create({
      baseURL: this.baseUrl,
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      }
    });
  }

  async getDashboards(): Promise<any[]> {
    const response = await this.client.get('/api/search?type=dash-db');
    return response.data;
  }

  async getDashboardById(dashboardId: string): Promise<any> {
    const response = await this.client.get(`/api/dashboards/uid/${dashboardId}`);
    return response.data;
  }

  async getDashboardPanels(dashboardId: string): Promise<any[]> {
    const dashboard = await this.getDashboardById(dashboardId);
    return dashboard.dashboard.panels;
  }

  async getAnnotations(dashboardId: string, from: number, to: number): Promise<any[]> {
    const response = await this.client.get('/api/annotations', {
      params: { dashboardId, from, to }
    });
    return response.data;
  }

  async searchDashboards(query: string): Promise<any[]> {
    const response = await this.client.get('/api/search', {
      params: { query }
    });
    return response.data;
  }

  async getPanelData(dashboardId: string, panelId: number): Promise<any> {
    const response = await this.client.post('/api/ds/query', {
      dashboardId,
      panelId,
      from: Date.now() - 3600000,
      to: Date.now()
    });
    return response.data;
  }

  async getAlerts(): Promise<any[]> {
    const response = await this.client.get('/api/alerts');
    return response.data;
  }

  async getAlertStates(): Promise<any[]> {
    const response = await this.client.get('/api/alertmanager/alerts');
    return response.data;
  }

  async createAnnotation(dashboardId: string, text: string, tags: string[]): Promise<any> {
    const response = await this.client.post('/api/annotations', {
      dashboardId,
      text,
      tags,
      time: Date.now()
    });
    return response.data;
  }
}
```

---

### 1.4: Enhanced CopilotKit Actions

**New File**: `web/ops-assistant/server/actions/advanced-actions.ts`

```typescript
import { CopilotAction } from '@copilotkit/react-core';
import { GrafanaClient } from '../grafana-client';

const grafana = new GrafanaClient();

export const advancedActions: CopilotAction[] = [
  {
    name: 'queryMetric',
    description: 'Query any Prometheus metric with custom aggregation',
    parameters: [
      { name: 'metric', type: 'string', description: 'Prometheus metric name' },
      { name: 'timeRange', type: 'string', description: 'Time range (e.g., 5m, 1h)' },
      { name: 'aggregation', type: 'string', description: 'Aggregation function (avg, max, sum)' }
    ],
    handler: async (metric, timeRange, aggregation) => {
      // Implementation
      return { metric, value: 0, unit: '' };
    }
  },

  {
    name: 'explainDashboard',
    description: 'Explain a specific Grafana dashboard with panel breakdown',
    parameters: [
      { name: 'dashboardId', type: 'string', description: 'Dashboard UID' }
    ],
    handler: async (dashboardId) => {
      const dashboard = await grafana.getDashboardById(dashboardId);
      const panels = dashboard.dashboard.panels;
      
      return {
        title: dashboard.dashboard.title,
        description: dashboard.dashboard.description,
        panels: panels.map(p => ({
          title: p.title,
          description: p.description,
          type: p.type
        }))
      };
    }
  },

  {
    name: 'identifyAnomaly',
    description: 'Detect anomalies in metric time series',
    parameters: [
      { name: 'metric', type: 'string', description: 'Metric name' },
      { name: 'threshold', type: 'number', description: 'Anomaly threshold (0-1)' },
      { name: 'windowSize', type: 'number', description: 'Window size in minutes' }
    ],
    handler: async (metric, threshold, windowSize) => {
      // Implementation: Use ML model
      return { anomalies: [], severity: 'low' };
    }
  },

  {
    name: 'compareMetrics',
    description: 'Compare two metrics side by side',
    parameters: [
      { name: 'metric1', type: 'string', description: 'First metric' },
      { name: 'metric2', type: 'string', description: 'Second metric' },
      { name: 'timeRange', type: 'string', description: 'Time range' }
    ],
    handler: async (metric1, metric2, timeRange) => {
      // Implementation
      return { comparison: {}, correlation: 0.0 };
    }
  },

  {
    name: 'predictTrend',
    description: 'Predict future metric values based on historical data',
    parameters: [
      { name: 'metric', type: 'string', description: 'Metric to predict' },
      { name: 'forecastHours', type: 'number', description: 'Hours ahead to forecast' }
    ],
    handler: async (metric, forecastHours) => {
      // Implementation: Use time series forecasting
      return { forecast: [], confidence: 0.85 };
    }
  },

  {
    name: 'searchEvents',
    description: 'Search for events and incidents across dashboards',
    parameters: [
      { name: 'keywords', type: 'string', description: 'Search keywords' },
      { name: 'timeRange', type: 'string', description: 'Time range to search' }
    ],
    handler: async (keywords, timeRange) => {
      // Implementation
      return { events: [], totalCount: 0 };
    }
  },

  {
    name: 'getNetworkTopology',
    description: 'Visualize network topology and connections',
    parameters: [
      { name: 'depth', type: 'number', description: 'Topology depth (1-5)' }
    ],
    handler: async (depth) => {
      // Implementation
      return { nodes: [], edges: [] };
    }
  },

  {
    name: 'alertOnCondition',
    description: 'Create a custom alert for a specific condition',
    parameters: [
      { name: 'metric', type: 'string', description: 'Metric to monitor' },
      { name: 'operator', type: 'string', description: 'Condition (>, <, ==, !=)' },
      { name: 'value', type: 'number', description: 'Threshold value' },
      { name: 'duration', type: 'string', description: 'Alert duration (e.g., 5m)' }
    ],
    handler: async (metric, operator, value, duration) => {
      // Implementation
      return { alertId: '', status: 'created' };
    }
  },

  {
    name: 'analyzePerformance',
    description: 'Analyze system performance metrics comprehensively',
    parameters: [
      { name: 'component', type: 'string', description: 'Component to analyze' },
      { name: 'timeRange', type: 'string', description: 'Analysis time range' }
    ],
    handler: async (component, timeRange) => {
      // Implementation
      return {
        component,
        cpu: 0,
        memory: 0,
        latency: 0,
        throughput: 0,
        health: 'healthy'
      };
    }
  },

  {
    name: 'getNetworkStats',
    description: 'Get comprehensive network statistics and health',
    parameters: [
      { name: 'includeNodeStats', type: 'boolean', description: 'Include per-node stats' }
    ],
    handler: async (includeNodeStats) => {
      // Implementation
      return {
        totalNodes: 0,
        healthyNodes: 0,
        latency: { p50: 0, p95: 0, p99: 0 },
        throughput: 0
      };
    }
  }
];
```

---

### 1.5: Interactive Widget System

**New File**: `web/ops-assistant/client/components/InteractiveWidget.tsx`

```typescript
import React, { useEffect, useState } from 'react';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip } from 'recharts';

interface WidgetConfig {
  type: 'chart' | 'gauge' | 'stat' | 'table' | 'alert';
  title: string;
  data?: any;
  metric?: string;
  color?: string;
}

export const InteractiveWidget: React.FC<{ config: WidgetConfig }> = ({ config }) => {
  const [data, setData] = useState<any>(null);

  useEffect(() => {
    if (config.metric) {
      fetchWidgetData(config.metric);
    }
  }, [config.metric]);

  const fetchWidgetData = async (metric: string) => {
    try {
      const response = await fetch('/api/widget-data', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ metric, timeRange: '1h' })
      });
      const result = await response.json();
      setData(result);
    } catch (error) {
      console.error('Error fetching widget data:', error);
    }
  };

  const renderWidget = () => {
    switch (config.type) {
      case 'chart':
        return (
          <LineChart width={400} height={250} data={data?.series || []}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="time" />
            <YAxis />
            <Tooltip />
            <Line type="monotone" dataKey="value" stroke={config.color || '#8884d8'} />
          </LineChart>
        );

      case 'gauge':
        return (
          <div className="gauge-widget">
            <div className="gauge-value">{data?.value || 0}</div>
            <div className="gauge-label">{config.title}</div>
            <div className="gauge-progress" style={{ width: `${(data?.value || 0) * 10}%` }}></div>
          </div>
        );

      case 'stat':
        return (
          <div className="stat-widget">
            <div className="stat-value">{data?.value || '--'}</div>
            <div className="stat-label">{config.title}</div>
            <div className="stat-change">{data?.change >= 0 ? '↑' : '↓'} {Math.abs(data?.change || 0)}%</div>
          </div>
        );

      case 'alert':
        return (
          <div className={`alert-widget alert-${data?.severity || 'info'}`}>
            <div className="alert-icon">⚠️</div>
            <div className="alert-content">
              <div className="alert-title">{config.title}</div>
              <div className="alert-message">{data?.message}</div>
            </div>
          </div>
        );

      default:
        return null;
    }
  };

  return (
    <div className="interactive-widget">
      {renderWidget()}
    </div>
  );
};
```

---

### 1.6: Enhanced App Component with A2UI

**New File**: `web/ops-assistant/client/App.tsx` (Enhanced)

```typescript
import React, { useState, useCallback } from 'react';
import { CopilotKit } from '@copilotkit/react-core';
import { CopilotSidebar } from '@copilotkit/react-ui';
import io from 'socket.io-client';
import { ChatInterface } from './components/ChatInterface';
import { InteractiveWidget } from './components/InteractiveWidget';
import { GrafanaDashboardView } from './components/GrafanaDashboardView';
import { NetworkTopology } from './components/NetworkTopology';
import './styles/app.css';

export const App: React.FC = () => {
  const [activeView, setActiveView] = useState<'chat' | 'dashboard' | 'topology' | 'metrics'>('chat');
  const [widgets, setWidgets] = useState<any[]>([]);
  const [socket, setSocket] = useState<any>(null);
  const [metrics, setMetrics] = useState<any>({});

  React.useEffect(() => {
    const newSocket = io(window.location.origin, {
      transports: ['websocket', 'polling']
    });

    newSocket.on('metrics_update', (data) => {
      setMetrics(data);
    });

    newSocket.on('action_result', (result) => {
      handleActionResult(result);
    });

    setSocket(newSocket);

    return () => newSocket.close();
  }, []);

  const handleActionResult = useCallback((result: any) => {
    if (result.type === 'widget') {
      setWidgets(prev => [...prev, result.config]);
    }
  }, []);

  const subscribeToMetrics = (metrics: string[]) => {
    if (socket) {
      socket.emit('subscribe_metrics', metrics);
    }
  };

  return (
    <CopilotKit publicApiKey={process.env.REACT_APP_COPILOT_API_KEY}>
      <div className="app-layout">
        <header className="app-header">
          <h1>🚀 Sovereign Mohawk Operations Center</h1>
          <nav className="view-switcher">
            <button onClick={() => setActiveView('chat')} className={activeView === 'chat' ? 'active' : ''}>
              💬 Chat
            </button>
            <button onClick={() => setActiveView('dashboard')} className={activeView === 'dashboard' ? 'active' : ''}>
              📊 Dashboards
            </button>
            <button onClick={() => setActiveView('topology')} className={activeView === 'topology' ? 'active' : ''}>
              🔗 Network
            </button>
            <button onClick={() => setActiveView('metrics')} className={activeView === 'metrics' ? 'active' : ''}>
              📈 Metrics
            </button>
          </nav>
        </header>

        <main className="app-content">
          {activeView === 'chat' && <ChatInterface onMetricsSubscribe={subscribeToMetrics} />}
          {activeView === 'dashboard' && <GrafanaDashboardView socket={socket} />}
          {activeView === 'topology' && <NetworkTopology socket={socket} />}
          {activeView === 'metrics' && (
            <div className="metrics-grid">
              {widgets.map((widget, idx) => (
                <InteractiveWidget key={idx} config={widget} />
              ))}
            </div>
          )}
        </main>

        <CopilotSidebar
          instructions="You are an expert network operations assistant. Help users understand their infrastructure and solve problems using Prometheus metrics, Grafana dashboards, and network topology."
          labels={{
            initial: "Hi! 👋 I'm your Operations Assistant. Ask me about metrics, dashboards, or network health."
          }}
        />
      </div>
    </CopilotKit>
  );
};
```

---

### 1.7: Styling

**New File**: `web/ops-assistant/client/styles/app.css`

```css
.app-layout {
  display: grid;
  grid-template-columns: 1fr;
  grid-template-rows: auto 1fr;
  height: 100vh;
  background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
  color: #f1f5f9;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

.app-header {
  background: rgba(15, 23, 42, 0.95);
  backdrop-filter: blur(10px);
  border-bottom: 1px solid rgba(148, 163, 184, 0.1);
  padding: 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.app-header h1 {
  margin: 0;
  font-size: 1.5rem;
  background: linear-gradient(135deg, #60a5fa 0%, #3b82f6 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.view-switcher {
  display: flex;
  gap: 0.5rem;
}

.view-switcher button {
  background: rgba(100, 116, 139, 0.1);
  border: 1px solid rgba(148, 163, 184, 0.2);
  color: #cbd5e1;
  padding: 0.5rem 1rem;
  border-radius: 0.375rem;
  cursor: pointer;
  transition: all 0.3s;
  font-weight: 500;
}

.view-switcher button:hover {
  background: rgba(100, 116, 139, 0.2);
  border-color: rgba(148, 163, 184, 0.4);
}

.view-switcher button.active {
  background: linear-gradient(135deg, #60a5fa 0%, #3b82f6 100%);
  border-color: #3b82f6;
  color: white;
}

.app-content {
  overflow: auto;
  padding: 2rem;
  background: linear-gradient(to bottom, rgba(15, 23, 42, 0.95), rgba(30, 41, 59, 0.95));
}

.metrics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1.5rem;
  padding: 1rem;
}

.interactive-widget {
  background: rgba(30, 41, 59, 0.8);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(148, 163, 184, 0.2);
  border-radius: 0.5rem;
  padding: 1.5rem;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
  transition: all 0.3s;
}

.interactive-widget:hover {
  border-color: rgba(148, 163, 184, 0.4);
  box-shadow: 0 8px 16px rgba(0, 0, 0, 0.3);
}

.gauge-widget {
  text-align: center;
}

.gauge-value {
  font-size: 2.5rem;
  font-weight: bold;
  color: #60a5fa;
  margin-bottom: 0.5rem;
}

.gauge-label {
  color: #94a3b8;
  font-size: 0.875rem;
  margin-bottom: 1rem;
}

.gauge-progress {
  height: 6px;
  background: #334155;
  border-radius: 3px;
  overflow: hidden;
}

.gauge-progress::after {
  content: '';
  display: block;
  height: 100%;
  background: linear-gradient(90deg, #60a5fa, #3b82f6);
  transition: width 0.3s;
}

.stat-widget {
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
}

.stat-value {
  font-size: 2rem;
  font-weight: bold;
  color: #60a5fa;
}

.stat-label {
  color: #94a3b8;
  font-size: 0.875rem;
  margin-top: 0.5rem;
}

.stat-change {
  color: #22c55e;
  font-size: 0.875rem;
  margin-top: 0.25rem;
}

.stat-change:first-child:nth-child(-n+0) { color: #ef4444; }

.alert-widget {
  display: flex;
  gap: 1rem;
  padding: 1rem;
  border-radius: 0.375rem;
}

.alert-widget.alert-critical {
  background: rgba(239, 68, 68, 0.1);
  border-left: 4px solid #ef4444;
}

.alert-widget.alert-warning {
  background: rgba(245, 158, 11, 0.1);
  border-left: 4px solid #f59e0b;
}

.alert-widget.alert-info {
  background: rgba(59, 130, 246, 0.1);
  border-left: 4px solid #3b82f6;
}

.alert-icon {
  font-size: 1.5rem;
}

.alert-content {
  flex: 1;
}

.alert-title {
  font-weight: 600;
  margin-bottom: 0.25rem;
}

.alert-message {
  font-size: 0.875rem;
  color: #cbd5e1;
}
```

---

### Summary: Phase 1 Deliverables

✅ **WebSocket/Socket.io server** - Real-time metric streaming  
✅ **Grafana API client** - Dashboard integration  
✅ **10+ advanced actions** - AI agent capabilities  
✅ **Interactive widget system** - Dynamic UI generation  
✅ **Enhanced App component** - Multi-view interface  
✅ **Professional styling** - Modern dark theme  

---

## 📊 PHASE 2: Core Features (Week 2)

### 2.1: Grafana Dashboard Integration

**New File**: `web/ops-assistant/client/components/GrafanaDashboardView.tsx`

```typescript
import React, { useEffect, useState } from 'react';

export const GrafanaDashboardView: React.FC<{ socket: any }> = ({ socket }) => {
  const [dashboards, setDashboards] = useState<any[]>([]);
  const [selectedDashboard, setSelectedDashboard] = useState<any>(null);
  const [panels, setPanels] = useState<any[]>([]);

  useEffect(() => {
    fetchDashboards();
  }, []);

  useEffect(() => {
    if (selectedDashboard && socket) {
      socket.emit('query_dashboard', { dashboardId: selectedDashboard.id });
      socket.on('dashboard_data', (data) => {
        setPanels(data.panels);
      });
    }
  }, [selectedDashboard, socket]);

  const fetchDashboards = async () => {
    try {
      const response = await fetch('/api/grafana/dashboards');
      const data = await response.json();
      setDashboards(data);
    } catch (error) {
      console.error('Error fetching dashboards:', error);
    }
  };

  return (
    <div className="grafana-dashboard-view">
      <div className="dashboard-selector">
        <h2>Select Dashboard</h2>
        <select onChange={(e) => setSelectedDashboard(dashboards[e.target.selectedIndex])}>
          <option>Choose a dashboard...</option>
          {dashboards.map(d => (
            <option key={d.id} value={d.id}>{d.title}</option>
          ))}
        </select>
      </div>

      {selectedDashboard && (
        <div className="dashboard-content">
          <h1>{selectedDashboard.title}</h1>
          <p>{selectedDashboard.description}</p>
          
          <div className="panels-grid">
            {panels.map(panel => (
              <div key={panel.id} className="panel">
                <h3>{panel.title}</h3>
                <iframe src={`/api/grafana/panel/${selectedDashboard.id}/${panel.id}`} />
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
```

---

### 2.2: Network Topology Visualization

**New File**: `web/ops-assistant/client/components/NetworkTopology.tsx`

```typescript
import React, { useEffect, useState } from 'react';
import ReactFlow, { MiniMap, Controls, Background } from 'react-flow-renderer';

export const NetworkTopology: React.FC<{ socket: any }> = ({ socket }) => {
  const [nodes, setNodes] = useState<any[]>([]);
  const [edges, setEdges] = useState<any[]>([]);
  const [nodeMetrics, setNodeMetrics] = useState<any>({});

  useEffect(() => {
    if (socket) {
      socket.emit('trigger_action', {
        name: 'getNetworkTopology',
        parameters: { depth: 3 }
      });

      socket.on('action_result', (result) => {
        if (result.name === 'getNetworkTopology') {
          setNodes(result.nodes);
          setEdges(result.edges);
        }
      });
    }
  }, [socket]);

  useEffect(() => {
    const metricsInterval = setInterval(() => {
      if (socket) {
        socket.emit('subscribe_metrics', ['node_up', 'node_cpu', 'node_memory']);
      }
    }, 1000);

    return () => clearInterval(metricsInterval);
  }, [socket]);

  return (
    <div className="network-topology" style={{ width: '100%', height: '100%' }}>
      <ReactFlow nodes={nodes} edges={edges}>
        <Background />
        <Controls />
        <MiniMap />
      </ReactFlow>
    </div>
  );
};
```

---

### 2.3: Real-time Metric Streaming

**New File**: `web/ops-assistant/server/actions/metric-streaming.ts`

```typescript
import { PrometheusClient } from '../prometheus-client';

const prometheus = new PrometheusClient();

export async function streamMetrics(socket: any, metrics: string[]) {
  // Stream metrics every second
  const interval = setInterval(async () => {
    try {
      const data: Record<string, any> = {};
      
      for (const metric of metrics) {
        const result = await prometheus.instantQuery(metric);
        data[metric] = result.data.result[0]?.value[1] || null;
      }

      socket.emit('metrics_update', {
        timestamp: new Date(),
        metrics: data
      });
    } catch (error) {
      console.error('Error streaming metrics:', error);
      clearInterval(interval);
    }
  }, 1000);

  socket.on('disconnect', () => clearInterval(interval));
}
```

---

## 🔬 PHASE 3: Advanced Features (Week 3)

### 3.1: Anomaly Detection

**New File**: `web/ops-assistant/server/anomaly-detector.ts`

```typescript
export class AnomalyDetector {
  private windowSize: number = 60; // minutes

  async detectAnomalies(
    timeSeries: Array<[number, number]>,
    threshold: number = 0.9
  ): Promise<Array<{timestamp: number; value: number; zScore: number}>> {
    const mean = this.calculateMean(timeSeries);
    const stdDev = this.calculateStdDev(timeSeries, mean);

    const anomalies = timeSeries
      .map(([ts, value]) => ({
        timestamp: ts,
        value,
        zScore: Math.abs((value - mean) / stdDev)
      }))
      .filter(point => point.zScore > threshold);

    return anomalies;
  }

  private calculateMean(data: Array<[number, number]>): number {
    return data.reduce((sum, [_, val]) => sum + val, 0) / data.length;
  }

  private calculateStdDev(data: Array<[number, number]>, mean: number): number {
    const variance = data.reduce((sum, [_, val]) => sum + Math.pow(val - mean, 2), 0) / data.length;
    return Math.sqrt(variance);
  }
}
```

---

### 3.2: Alert Integration

**New File**: `web/ops-assistant/server/alert-manager.ts`

```typescript
import { GrafanaClient } from './grafana-client';

export class AlertManager {
  private grafana: GrafanaClient;

  constructor(grafana: GrafanaClient) {
    this.grafana = grafana;
  }

  async getActiveAlerts(): Promise<any[]> {
    return await this.grafana.getAlertStates();
  }

  async createCustomAlert(
    metric: string,
    operator: string,
    threshold: number,
    duration: string
  ): Promise<any> {
    // Create alert rule
    return {
      id: `alert_${Date.now()}`,
      metric,
      operator,
      threshold,
      duration,
      status: 'active'
    };
  }

  async acknowledgeAlert(alertId: string): Promise<void> {
    // Mark alert as acknowledged
  }
}
```

---

## 🎨 Enhanced UI Components

### Better Data Visualization

```typescript
// Time series chart with multiple metrics
<ComparativeChart metrics={['metric1', 'metric2']} timeRange="1h" />

// Heatmap for correlation analysis
<CorrelationHeatmap metrics={allMetrics} />

// Network flow diagram
<NetworkFlowDiagram nodes={nodes} edges={edges} />

// Real-time alert list
<AlertStream socket={socket} />

// Metric prediction chart
<PredictionChart metric="cpu_usage" hoursAhead={24} />
```

---

## 📋 Complete Implementation Checklist

### Phase 1: Foundation ✅
- [ ] WebSocket server setup
- [ ] Socket.io integration
- [ ] Grafana API client
- [ ] 10+ advanced actions
- [ ] Interactive widget system
- [ ] Enhanced UI components
- [ ] Professional styling

### Phase 2: Core Features
- [ ] Grafana dashboard integration
- [ ] Network topology visualization
- [ ] Real-time metric streaming
- [ ] Multi-view interface
- [ ] Advanced charting
- [ ] Performance optimization

### Phase 3: Polish
- [ ] Anomaly detection ML
- [ ] Alert integration
- [ ] Prediction models
- [ ] Dark/light theme
- [ ] Mobile responsiveness
- [ ] Accessibility (WCAG)

---

## 🚀 Deployment Instructions

```bash
# 1. Install enhanced dependencies
cd web/ops-assistant
npm install

# 2. Build enhanced version
npm run build

# 3. Build Docker image
docker build -t ops-assistant:enhanced .

# 4. Update docker-compose
docker-compose up -d

# 5. Verify new features
curl http://localhost:3001/api/health
```

---

## 📊 Expected Outcomes

### User Experience
✅ Natural language queries for any metric  
✅ Real-time interactive dashboards  
✅ Visual network topology  
✅ Instant anomaly alerts  
✅ Predictive insights  

### Operational Efficiency
✅ 50% faster incident detection  
✅ 70% reduction in dashboard hopping  
✅ Automated anomaly identification  
✅ Predictive maintenance capabilities  

### Business Value
✅ Reduced MTTR (Mean Time To Recovery)  
✅ Improved system reliability  
✅ Better resource utilization  
✅ Competitive advantage in network ops  

---

**Status**: 🟢 READY TO IMPLEMENT  
**Created**: May 11, 2026  
**Next Step**: Begin Phase 1 implementation
