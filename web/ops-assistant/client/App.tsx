import React, { useState } from 'react';
import { CopilotChat } from '@copilotkit/react-ui';
import MetricsView from './components/MetricsView';
import GrafanaDashboardView from './components/GrafanaDashboardView';
import '@copilotkit/react-ui/styles.css';
import './styles/app.css';

/**
 * Enhanced Operations Assistant Application
 * Integrates CopilotKit chat, real-time metrics, and Grafana dashboards
 */

type ViewType = 'chat' | 'metrics' | 'dashboards';

const App: React.FC = () => {
  const [activeView, setActiveView] = useState<ViewType>('chat');

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
            </div>
          )}

          {activeView === 'metrics' && (
            <div className="view-content metrics-view-wrapper">
              <MetricsView
                wsUrl="ws://localhost:3000"
                pollInterval={5000}
              />
            </div>
          )}

          {activeView === 'dashboards' && (
            <div className="view-content dashboards-view-wrapper">
              <GrafanaDashboardView apiUrl="http://localhost:3000/api/grafana" />
            </div>
          )}
        </div>

        <aside className="app-sidebar">
          <div className="sidebar-panel">
            <h3>Quick Stats</h3>
            <div className="stats-grid">
              <div className="stat-item">
                <span className="stat-label">Status</span>
                <span className="stat-value healthy">● Healthy</span>
              </div>
              <div className="stat-item">
                <span className="stat-label">Uptime</span>
                <span className="stat-value">99.9%</span>
              </div>
              <div className="stat-item">
                <span className="stat-label">Alerts</span>
                <span className="stat-value alert">2 Active</span>
              </div>
            </div>
          </div>

          <div className="sidebar-panel">
            <h3>Recent Actions</h3>
            <ul className="action-history">
              <li>✓ System health check completed</li>
              <li>✓ Grafana dashboards synced</li>
              <li>✓ Metrics updated</li>
              <li>✓ Anomaly detection run</li>
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
