import React, { useEffect, useMemo, useState } from 'react';
import { CopilotChat } from '@copilotkit/react-ui';
import MetricsView from './components/MetricsView';
import GrafanaDashboardView from './components/GrafanaDashboardView';
import A2UIRenderer from './components/A2UIRenderer';
import { buildApiUrl, getRuntimeConfig } from './config';
import { useAgUiStream } from './hooks/useAgUiStream';
import { A2UiAction } from './types/protocol';
import '@copilotkit/react-ui/styles.css';
import './styles/app.css';

/**
 * Enhanced Operations Assistant Application
 * Integrates CopilotKit chat, real-time metrics, and Grafana dashboards
 */

type ViewType = 'chat' | 'metrics' | 'dashboards';

interface OpsSummary {
  status: 'healthy' | 'degraded' | 'down';
  uptimePercent: number;
  activeAlerts: number;
  recentActions: string[];
}

const App: React.FC = () => {
  const [activeView, setActiveView] = useState<ViewType>('chat');
  const [summary, setSummary] = useState<OpsSummary | null>(null);
  const [summaryError, setSummaryError] = useState<string | null>(null);
  const [intentMessage, setIntentMessage] = useState<string | null>(null);
  const [busyIntent, setBusyIntent] = useState<string | null>(null);

  const runtimeConfig = useMemo(() => getRuntimeConfig(), []);
  const { events, latestEnvelope, connectionStatus } = useAgUiStream();

  useEffect(() => {
    let active = true;

    const fetchSummary = async () => {
      try {
        const response = await fetch(buildApiUrl('/api/ops/summary'));
        if (!response.ok) {
          throw new Error(`Summary API returned ${response.status}`);
        }

        const data = (await response.json()) as OpsSummary;
        if (active) {
          setSummary(data);
          setSummaryError(null);
        }
      } catch (error) {
        if (active) {
          setSummaryError(error instanceof Error ? error.message : 'Failed to load summary');
        }
      }
    };

    fetchSummary();
    const interval = window.setInterval(fetchSummary, 15000);

    return () => {
      active = false;
      window.clearInterval(interval);
    };
  }, []);

  const statusClass =
    summary?.status === 'healthy'
      ? 'healthy'
      : summary?.status === 'degraded'
        ? 'warning'
        : 'alert';

  const statusText =
    summary?.status === 'healthy'
      ? 'Healthy'
      : summary?.status === 'degraded'
        ? 'Degraded'
        : 'Unavailable';

  const handleA2UiAction = async (action: A2UiAction) => {
    if (action.confirm) {
      const confirmed = window.confirm(`Run action: ${action.label}?`);
      if (!confirmed) {
        return;
      }
    }

    try {
      setBusyIntent(action.intent);
      setIntentMessage(null);
      const response = await fetch(buildApiUrl('/api/agent/intent'), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ intent: action.intent }),
      });

      const result = (await response.json()) as { message?: string; error?: string };
      if (!response.ok) {
        throw new Error(result.error || result.message || 'Intent execution failed');
      }

      setIntentMessage(result.message || 'Intent completed.');
    } catch (error) {
      setIntentMessage(error instanceof Error ? error.message : 'Intent execution failed');
    } finally {
      setBusyIntent(null);
    }
  };

  return (
    <div className="app-container">
      <nav className="app-navbar">
        <div className="navbar-content">
          <h1 className="app-title">
            <span className="title-icon">⚙️</span>
            Operations Assistant
          </h1>
          <div className="nav-links">
            <button
              className={`nav-link ${activeView === 'chat' ? 'active' : ''}`}
              onClick={() => setActiveView('chat')}
              aria-label="Chat View"
            >
              <span className="nav-icon">💬</span>
              Chat
            </button>
            <button
              className={`nav-link ${activeView === 'metrics' ? 'active' : ''}`}
              onClick={() => setActiveView('metrics')}
              aria-label="Metrics View"
            >
              <span className="nav-icon">📊</span>
              Metrics
            </button>
            <button
              className={`nav-link ${activeView === 'dashboards' ? 'active' : ''}`}
              onClick={() => setActiveView('dashboards')}
              aria-label="Grafana Dashboards"
            >
              <span className="nav-icon">📈</span>
              Dashboards
            </button>
          </div>
        </div>
      </nav>

      <div className="app-main">
        <div className="view-container">
          {activeView === 'chat' && (
            <div className="view-content chat-view">
              <div className="chat-header">
                <h2>AI Operations Assistant</h2>
                <p>Ask questions about your metrics, dashboards, and system health</p>
              </div>
              <div className="chat-container">
                <CopilotChat
                  instructions="You are an expert network operations assistant. Help users monitor and analyze their infrastructure using real-time metrics from Prometheus and Grafana dashboards. Provide actionable insights and recommendations for system optimization."
                  labels={{
                    initial: "Hi! I'm your operations assistant. How can I help you today?",
                    placeholder: "Ask about metrics, dashboards, or system health...",
                  }}
                />
              </div>
              <div className="agent-workflow-panel">
                <div className="agent-workflow-header">
                  <h3>Agent Workflow Surface</h3>
                  <span className={`stream-status ${connectionStatus}`}>
                    Stream: {connectionStatus}
                  </span>
                </div>
                <A2UIRenderer
                  envelope={latestEnvelope}
                  busyIntent={busyIntent}
                  onAction={handleA2UiAction}
                />
                {intentMessage && <p className="intent-message">{intentMessage}</p>}
                <p className="event-count">AG-UI events received: {events.length}</p>
              </div>
            </div>
          )}

          {activeView === 'metrics' && (
            <div className="view-content metrics-view-wrapper">
              <MetricsView
                wsUrl={runtimeConfig.wsUrl}
                pollInterval={5000}
              />
            </div>
          )}

          {activeView === 'dashboards' && (
            <div className="view-content dashboards-view-wrapper">
              <GrafanaDashboardView apiUrl={buildApiUrl('/api/grafana')} />
            </div>
          )}
        </div>

        <aside className="app-sidebar">
          <div className="sidebar-panel">
            <h3>Quick Stats</h3>
            <div className="stats-grid">
              <div className="stat-item">
                <span className="stat-label">Status</span>
                <span className={`stat-value ${statusClass}`}>● {statusText}</span>
              </div>
              <div className="stat-item">
                <span className="stat-label">Uptime</span>
                <span className="stat-value">
                  {summary ? `${summary.uptimePercent.toFixed(2)}%` : 'Loading...'}
                </span>
              </div>
              <div className="stat-item">
                <span className="stat-label">Alerts</span>
                <span className={`stat-value ${summary?.activeAlerts ? 'alert' : 'healthy'}`}>
                  {summary ? `${summary.activeAlerts} Active` : 'Loading...'}
                </span>
              </div>
            </div>
            {summaryError && <p className="panel-error">Summary sync error: {summaryError}</p>}
          </div>

          <div className="sidebar-panel">
            <h3>Recent Actions</h3>
            <ul className="action-history">
              {(summary?.recentActions || ['Loading recent actions...']).map((action, index) => (
                <li key={`${index}-${action}`}>{action}</li>
              ))}
            </ul>
          </div>

          <div className="sidebar-panel help">
            <h3>Help & Docs</h3>
            <p>Use the chat to ask questions about:</p>
            <ul className="help-topics">
              <li>Real-time metrics</li>
              <li>Dashboard analysis</li>
              <li>System performance</li>
              <li>Alert management</li>
            </ul>
          </div>
        </aside>
      </div>

      <footer className="app-footer">
        <div className="footer-content">
          <span>Operations Assistant powered by CopilotKit</span>
          <span className="version">v1.1.0</span>
        </div>
      </footer>
    </div>
  );
};

export default App;
