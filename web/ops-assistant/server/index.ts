import express from 'express';
import cors from 'cors';
import { queryPrometheusHealth } from './prometheus-client';
import {
  handleQueryPrometheus,
  handleIncidentSummary,
  handleExplainDashboard
} from './actions';

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Health check
app.get('/api/health', async (req, res) => {
  const prometheusOk = await queryPrometheusHealth();
  res.json({
    status: prometheusOk ? 'healthy' : 'degraded',
    prometheus: prometheusOk ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString()
  });
});

// Query Prometheus endpoint
app.post('/api/prometheus/query', handleQueryPrometheus);

// Incident summary endpoint
app.post('/api/incident-summary', handleIncidentSummary);

// Dashboard explanation endpoint
app.post('/api/dashboard/explain', handleExplainDashboard);

// CopilotKit actions (accessible via REST)
app.get('/api/copilotkit/actions', (req, res) => {
  res.json({
    actions: [
      {
        name: 'queryPrometheus',
        description: 'Execute a PromQL query and get time-series data'
      },
      {
        name: 'generateIncidentSummary',
        description: 'Analyze metrics and generate incident summary'
      },
      {
        name: 'explainDashboard',
        description: 'Explain a Grafana dashboard'
      }
    ]
  });
});

// Serve React frontend in production
if (process.env.NODE_ENV === 'production') {
  app.use(express.static('dist/client'));

  // SPA fallback
  app.get('*', (req, res) => {
    res.sendFile('dist/client/index.html');
  });
}

// Start server
app.listen(PORT, () => {
  console.log(`CopilotKit Ops Assistant running on port ${PORT}`);
  console.log(`Prometheus URL: ${process.env.PROMETHEUS_URL || 'http://prometheus:9090'}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});
