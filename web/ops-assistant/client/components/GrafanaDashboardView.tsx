import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { buildApiUrl } from '../config';
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
  apiUrl = buildApiUrl('/api/grafana'),
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
      console.log('[GrafanaDashboard] Fetching dashboards from:', `${apiUrl}/dashboards`);

      const response = await axios.get(`${apiUrl}/dashboards`, {
        timeout: 5000,
      });
      
      console.log('[GrafanaDashboard] Response:', response.data);
      
      // Handle both { dashboards: [...] } and { success: true, dashboards: [...] }
      const dashboardsData = response.data?.dashboards || response.data;
      
      if (Array.isArray(dashboardsData)) {
        setDashboards(dashboardsData);
        console.log('[GrafanaDashboard] Loaded', dashboardsData.length, 'dashboards');
      } else {
        console.warn('[GrafanaDashboard] Unexpected response structure:', response.data);
        setError('Invalid dashboard response format');
        setDashboards([]);
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Failed to fetch dashboards';
      console.error('[GrafanaDashboard] Error:', err);
      setError(errorMsg);
      setDashboards([]);
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
      console.log('[GrafanaDashboard] Fetching dashboard:', uid);
      
      const response = await axios.get(`${apiUrl}/dashboards/${uid}`, {
        timeout: 5000,
      });
      
      console.log('[GrafanaDashboard] Dashboard response:', response.data);
      
      const dashData = response.data?.dashboard || response.data;
      
      if (dashData) {
        setDashboardDetail({
          title: dashData.title || 'Untitled',
          description: dashData.description || '',
          panels: (dashData.panels || []).map((p: any) => ({
            id: p.id || 0,
            title: p.title || 'Untitled Panel',
            type: p.type || 'unknown',
          })),
        });
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Failed to fetch dashboard';
      console.error('[GrafanaDashboard] Dashboard fetch error:', err);
      setError(errorMsg);
      setDashboardDetail(null);
    } finally {
      setLoading(false);
    }
  };

  /**
   * Handle dashboard selection
   */
  const handleSelectDashboard = (dashboard: Dashboard): void => {
    console.log('[GrafanaDashboard] Selecting dashboard:', dashboard.title);
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
      console.log('[GrafanaDashboard] Searching for:', query);
      
      const response = await axios.get(`${apiUrl}/search`, {
        params: { query },
        timeout: 5000,
      });
      
      console.log('[GrafanaDashboard] Search results:', response.data);
      
      const results = response.data?.results || response.data;
      if (Array.isArray(results)) {
        setDashboards(results);
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Search failed';
      console.error('[GrafanaDashboard] Search error:', err);
      setError(errorMsg);
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
          <button onClick={fetchDashboards} className="refresh-btn" title="Refresh">
            ↻
          </button>
        </div>
      </div>

      {error && <div className="grafana-error">⚠️ {error}</div>}

      <div className="grafana-content">
        <div className="dashboards-list">
          <h3>Available Dashboards ({dashboards.length})</h3>
          {loading && dashboards.length === 0 ? (
            <div className="loading">Loading dashboards...</div>
          ) : dashboards.length === 0 ? (
            <div className="empty-state">
              <p>No dashboards found</p>
              <p className="hint">Try connecting to your Grafana instance</p>
            </div>
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
