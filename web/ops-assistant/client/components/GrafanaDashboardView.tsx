import React, { useEffect, useState } from 'react';
import axios from 'axios';
import '../styles/grafana.css';

/**
 * Grafana Dashboard Integration Component
 * Displays Grafana dashboards and allows browsing, searching, and interaction
 */

interface Dashboard {
  id: number;
  uid: string;
  title: string;
  tags: string[];
  url: string;
  starred?: boolean;
}

interface DashboardDetail {
  title: string;
  description?: string;
  panels: Panel[];
}

interface Panel {
  id: number;
  title: string;
  type: string;
}

interface GrafanaDashboardViewProps {
  apiUrl?: string;
}

const GrafanaDashboardView: React.FC<GrafanaDashboardViewProps> = ({
  apiUrl = 'http://localhost:3000/api/grafana',
}) => {
  const [dashboards, setDashboards] = useState<Dashboard[]>([]);
  const [selectedDashboard, setSelectedDashboard] = useState<Dashboard | null>(null);
  const [dashboardDetail, setDashboardDetail] = useState<DashboardDetail | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  /**
   * Fetch all dashboards on mount
   */
  useEffect(() => {
    fetchDashboards();
  }, []);

  /**
   * Fetch dashboards from API
   */
  const fetchDashboards = async (): Promise<void> => {
    try {
      setLoading(true);
      setError(null);

      const response = await axios.get(`${apiUrl}/dashboards`);
      if (response.data.dashboards) {
        setDashboards(response.data.dashboards);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch dashboards');
      console.error('[GrafanaDashboard] Error:', err);
    } finally {
      setLoading(false);
    }
  };

  /**
   * Fetch dashboard details
   */
  const fetchDashboardDetail = async (uid: string): Promise<void> => {
    try {
      setLoading(true);
      const response = await axios.get(`${apiUrl}/dashboards/${uid}`);
      if (response.data.dashboard) {
        setDashboardDetail({
          title: response.data.dashboard.title,
          description: response.data.dashboard.description,
          panels: response.data.dashboard.panels || [],
        });
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch dashboard');
    } finally {
      setLoading(false);
    }
  };

  /**
   * Handle dashboard selection
   */
  const handleSelectDashboard = (dashboard: Dashboard): void => {
    setSelectedDashboard(dashboard);
    fetchDashboardDetail(dashboard.uid);
  };

  /**
   * Search dashboards
   */
  const handleSearch = async (query: string): Promise<void> => {
    setSearchQuery(query);

    if (!query.trim()) {
      fetchDashboards();
      return;
    }

    try {
      setLoading(true);
      const response = await axios.get(`${apiUrl}/search?query=${encodeURIComponent(query)}`);
      if (response.data.results) {
        setDashboards(response.data.results);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Search failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="grafana-view">
      <div className="grafana-header">
        <h2>Grafana Dashboards</h2>
        <div className="search-box">
          <input
            type="text"
            placeholder="Search dashboards..."
            value={searchQuery}
            onChange={(e) => handleSearch(e.target.value)}
            className="search-input"
          />
          <button onClick={fetchDashboards} className="refresh-btn">
            ↻
          </button>
        </div>
      </div>

      <div className="grafana-content">
        <div className="dashboards-list">
          <h3>Available Dashboards</h3>
          {loading && dashboards.length === 0 ? (
            <div className="loading">Loading dashboards...</div>
          ) : dashboards.length === 0 ? (
            <div className="empty-state">No dashboards found</div>
          ) : (
            <ul className="dashboard-items">
              {dashboards.map((dashboard) => (
                <li
                  key={dashboard.uid}
                  className={`dashboard-item ${
                    selectedDashboard?.uid === dashboard.uid ? 'selected' : ''
                  }`}
                  onClick={() => handleSelectDashboard(dashboard)}
                >
                  <div className="dashboard-title">{dashboard.title}</div>
                  {dashboard.tags && dashboard.tags.length > 0 && (
                    <div className="dashboard-tags">
                      {dashboard.tags.map((tag) => (
                        <span key={tag} className="tag">
                          {tag}
                        </span>
                      ))}
                    </div>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="dashboard-detail">
          {selectedDashboard && dashboardDetail ? (
            <div>
              <h3>{dashboardDetail.title}</h3>
              {dashboardDetail.description && (
                <p className="description">{dashboardDetail.description}</p>
              )}

              {dashboardDetail.panels.length > 0 ? (
                <div>
                  <h4>Panels ({dashboardDetail.panels.length})</h4>
                  <div className="panels-grid">
                    {dashboardDetail.panels.map((panel) => (
                      <div key={panel.id} className="panel-card">
                        <div className="panel-title">{panel.title}</div>
                        <div className="panel-type">{panel.type}</div>
                      </div>
                    ))}
                  </div>
                </div>
              ) : (
                <div className="empty-panels">No panels in dashboard</div>
              )}

              <div className="dashboard-actions">
                <a
                  href={`${selectedDashboard.url}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="btn-primary"
                >
                  Open in Grafana
                </a>
              </div>
            </div>
          ) : (
            <div className="empty-state">Select a dashboard to view details</div>
          )}
        </div>
      </div>

      {error && <div className="error-message">{error}</div>}
    </div>
  );
};

export default GrafanaDashboardView;
