import React, { useCallback, useMemo } from 'react';
import { CopilotKit } from '@copilotkit/react-core';
import { CopilotSidebar } from '@copilotkit/react-ui';
import ChatInterface from './components/ChatInterface';
import HealthStatus from './components/HealthStatus';
import '@copilotkit/react-ui/styles.css';

const App: React.FC = () => {
  // CopilotKit custom actions
  const actions = useMemo(
    () => [
      {
        name: 'queryPrometheus',
        description: 'Query Prometheus for metrics. Examples: "What is the current gradient throughput?", "Show me the last 30 minutes of proof verification rate"',
        parameters: [
          {
            name: 'query',
            type: 'string',
            description: 'PromQL expression or natural language description of what to query'
          },
          {
            name: 'rangeMinutes',
            type: 'number',
            description: 'Optional: time range in minutes for range queries (default: instant query)'
          }
        ],
        handler: async (context: any) => {
          const response = await fetch('/api/prometheus/query', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              query: context.query,
              rangeMinutes: context.rangeMinutes
            })
          });
          return await response.json();
        }
      },
      {
        name: 'generateIncidentSummary',
        description: 'Analyze metrics and generate a summary of cluster health, anomalies, and recommendations',
        parameters: [
          {
            name: 'startTime',
            type: 'string',
            description: 'Start time (e.g., "30m ago", "1h ago") - default: 30m ago'
          },
          {
            name: 'endTime',
            type: 'string',
            description: 'End time (e.g., "now") - default: now'
          }
        ],
        handler: async (context: any) => {
          const response = await fetch('/api/incident-summary', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              startTime: context.startTime || '30m ago',
              endTime: context.endTime || 'now'
            })
          });
          return await response.json();
        }
      },
      {
        name: 'explainDashboard',
        description: 'Explain the purpose and key metrics of a Grafana dashboard',
        parameters: [
          {
            name: 'dashboardName',
            type: 'string',
            description: 'Dashboard ID or name (e.g., v2-10-ops-overview, v2-14-ops-mrc-transport)'
          }
        ],
        handler: async (context: any) => {
          const response = await fetch('/api/dashboard/explain', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              dashboardName: context.dashboardName
            })
          });
          return await response.json();
        }
      }
    ],
    []
  );

  return (
    <CopilotKit
      runtimeUrl="/api/copilot"
      headers={{
        'Content-Type': 'application/json'
      }}
    >
      <div style={{ display: 'flex', height: '100vh', width: '100%' }}>
        {/* Main content area */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
          {/* Header */}
          <header
            style={{
              padding: '20px',
              borderBottom: '1px solid #e0e0e0',
              backgroundColor: '#f8f9fa'
            }}
          >
            <h1 style={{ fontSize: '24px', fontWeight: 'bold', margin: '0 0 10px 0' }}>
              🚀 Sovereign Mohawk Operations Assistant
            </h1>
            <p style={{ fontSize: '14px', color: '#666', margin: 0 }}>
              Powered by CopilotKit | Ask about metrics, dashboards, and cluster health
            </p>
          </header>

          {/* Health status */}
          <div style={{ padding: '16px 20px', borderBottom: '1px solid #f0f0f0' }}>
            <HealthStatus />
          </div>

          {/* Chat interface */}
          <div style={{ flex: 1, overflow: 'hidden' }}>
            <ChatInterface />
          </div>
        </div>

        {/* CopilotKit sidebar with custom actions */}
        <CopilotSidebar
          instructions={`You are an expert DevOps assistant for the Sovereign Mohawk federated learning system. 

Your responsibilities:
1. Help operators understand system metrics and dashboards
2. Analyze cluster health and identify anomalies
3. Suggest PromQL queries for investigation
4. Provide incident recommendations

When answering:
- Be concise and actionable
- Reference specific metrics and time windows
- Suggest next steps for troubleshooting
- Use available tools (queryPrometheus, generateIncidentSummary, explainDashboard)`}
          
        />
      </div>
    </CopilotKit>
  );
};

export default App;
