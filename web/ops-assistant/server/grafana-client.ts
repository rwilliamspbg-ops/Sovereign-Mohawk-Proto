import axios, { AxiosInstance, AxiosError } from 'axios';
import { getAuthManager, type AuthManager } from './auth-manager.js';

/**
 * Grafana API Client
 * Provides methods to interact with Grafana dashboards, alerts, and annotations
 * 
 * Enhanced with:
 * - Unified authentication management via AuthManager
 * - Automatic 401 detection and re-authentication
 * - Request tracing for audit and debugging
 * - Detailed error reporting
 */

export interface Dashboard {
  id: number;
  uid: string;
  title: string;
  tags: string[];
  starred: boolean;
  url: string;
}

export interface DashboardDetail {
  dashboard: {
    id: number;
    uid: string;
    title: string;
    description?: string;
    tags: string[];
    panels: Panel[];
  };
  meta: {
    created: string;
    updated: string;
  };
}

export interface Panel {
  id: number;
  title: string;
  type: string;
  gridPos: {
    h: number;
    w: number;
    x: number;
    y: number;
  };
  targets: any[];
}

export interface Alert {
  id: number;
  dashboardId: number;
  panelId: number;
  name: string;
  message: string;
  state: string;
  noDataState?: string;
  executionErrorState?: string;
}

export interface Annotation {
  id: number;
  time: number;
  text: string;
  tags: string[];
  dashboardId?: number;
}

export class GrafanaClient {
  private axiosInstance: AxiosInstance;
  private baseUrl: string;
  private apiToken: string;
  private authManager: AuthManager;
  private isReauthenticating: boolean = false;

  constructor(
    baseUrl: string = 'http://grafana:3000',
    apiToken?: string
  ) {
    this.baseUrl = baseUrl;
    this.apiToken = apiToken || process.env.GRAFANA_API_TOKEN || 'admin';
    this.authManager = getAuthManager();

    if (this.apiToken === 'admin') {
      console.warn(
        '[GrafanaClient] ⚠️ WARNING: Using default "admin" token. ' +
        'Set GRAFANA_API_TOKEN environment variable or /run/secrets/grafana_api_token file'
      );
    }

    // Create axios instance with interceptors for auth handling
    this.axiosInstance = axios.create({
      baseURL: baseUrl,
      headers: {
        Authorization: `Bearer ${this.apiToken}`,
        'Content-Type': 'application/json',
      },
      timeout: 10000,
    });

    // Add response interceptor for 401 handling
    this.axiosInstance.interceptors.response.use(
      (response) => response,
      async (error: AxiosError) => {
        if (error.response?.status === 401 && !this.isReauthenticating) {
          console.warn('[GrafanaClient] 🔄 Received 401 Unauthorized, attempting re-authentication...');
          
          // Trace the auth failure
          this.authManager.addRequestTrace(
            'ops-assistant',
            'grafana',
            error.config?.method || 'GET',
            401,
            'Unauthorized - token may be invalid'
          );

          this.isReauthenticating = true;
          try {
            // Attempt to refresh/validate token
            await this.revalidateAndRefreshToken();
            
            // Retry the original request with new token
            if (error.config) {
              error.config.headers.Authorization = `Bearer ${this.apiToken}`;
              this.isReauthenticating = false;
              return this.axiosInstance(error.config);
            }
          } catch (refreshError) {
            console.error('[GrafanaClient] ✗ Re-authentication failed:', refreshError);
            this.authManager.addRequestTrace(
              'ops-assistant',
              'grafana',
              're-auth',
              401,
              refreshError instanceof Error ? refreshError.message : 'Re-auth failed'
            );
          }
          this.isReauthenticating = false;
        }

        // Trace all non-2xx responses
        if (error.response?.status && error.response.status >= 400) {
          this.authManager.addRequestTrace(
            'ops-assistant',
            'grafana',
            error.config?.method || 'GET',
            error.response.status,
            error.message
          );
        }

        return Promise.reject(error);
      }
    );
  }

  /**
   * Revalidate and refresh Grafana token
   * Called when a 401 is received
   */
  private async revalidateAndRefreshToken(): Promise<void> {
    try {
      const token = await this.authManager.getGrafanaToken();
      this.apiToken = token;
      
      // Update axios instance headers
      this.axiosInstance.defaults.headers.Authorization = `Bearer ${token}`;
      
      console.log('[GrafanaClient] ✓ Token refreshed successfully');
    } catch (error) {
      console.error('[GrafanaClient] ✗ Token refresh failed:', error);
      throw error;
    }
  }

  /**
   * Handle Grafana API errors with detailed diagnostics
   */
  private handleError(operation: string, error: any, endpoint: string): void {
    const axiosError = error as AxiosError;
    const statusCode = axiosError.response?.status;
    const errorData = axiosError.response?.data as any;

    let errorMessage = `${operation} failed`;
    if (statusCode === 401) {
      errorMessage += ' (Unauthorized - invalid or expired token)';
    } else if (statusCode === 403) {
      errorMessage += ' (Forbidden - insufficient permissions)';
    } else if (statusCode === 404) {
      errorMessage += ' (Not Found)';
    } else if (statusCode && statusCode >= 500) {
      errorMessage += ` (Server error: ${statusCode})`;
    }

    console.error(`[GrafanaClient] ✗ ${errorMessage}`, {
      endpoint,
      statusCode,
      errorMessage: errorData?.message,
      tokenLength: this.apiToken.length,
    });

    this.authManager.addRequestTrace(
      'ops-assistant',
      'grafana',
      'GET',
      statusCode,
      errorMessage
    );
  }

  /**
   * Get all dashboards
   */
  async getDashboards(tags?: string[]): Promise<Dashboard[]> {
    try {
      let url = '/api/search?type=dash-db';
      if (tags && tags.length > 0) {
        tags.forEach((tag) => {
          url += `&tag=${tag}`;
        });
      }

      const response = await this.axiosInstance.get<Dashboard[]>(url);
      this.authManager.addRequestTrace('ops-assistant', 'grafana', 'GET', 200);
      return response.data;
    } catch (error) {
      this.handleError('getDashboards', error, '/api/search?type=dash-db');
      return [];
    }
  }

  /**
   * Get dashboard by UID
   */
  async getDashboardByUid(uid: string): Promise<DashboardDetail | null> {
    try {
      const response = await this.axiosInstance.get<DashboardDetail>(
        `/api/dashboards/uid/${uid}`
      );
      this.authManager.addRequestTrace('ops-assistant', 'grafana', 'GET', 200);
      return response.data;
    } catch (error) {
      this.handleError(`getDashboardByUid(${uid})`, error, `/api/dashboards/uid/${uid}`);
      return null;
    }
  }

  /**
   * Search dashboards by query
   */
  async searchDashboards(query: string): Promise<Dashboard[]> {
    try {
      const response = await this.axiosInstance.get<Dashboard[]>(
        '/api/search',
        {
          params: { query, type: 'dash-db' },
        }
      );
      this.authManager.addRequestTrace('ops-assistant', 'grafana', 'GET', 200);
      return response.data;
    } catch (error) {
      this.handleError('searchDashboards', error, '/api/search');
      return [];
    }
  }

  /**
   * Get all alerts
   */
  async getAlerts(): Promise<Alert[]> {
    try {
      const response = await this.axiosInstance.get<Alert[]>('/api/alerts');
      this.authManager.addRequestTrace('ops-assistant', 'grafana', 'GET', 200);
      return response.data;
    } catch (error) {
      this.handleError('getAlerts', error, '/api/alerts');
      return [];
    }
  }

  /**
   * Get alerts for specific dashboard
   */
  async getDashboardAlerts(dashboardId: number): Promise<Alert[]> {
    try {
      const response = await this.axiosInstance.get<Alert[]>(
        `/api/alerts?dashboardId=${dashboardId}`
      );
      this.authManager.addRequestTrace('ops-assistant', 'grafana', 'GET', 200);
      return response.data;
    } catch (error) {
      this.handleError(`getDashboardAlerts(${dashboardId})`, error, `/api/alerts`);
      return [];
    }
  }

  /**
   * Get annotations
   */
  async getAnnotations(
    dashboardId?: number,
    panelId?: number,
    tags?: string[]
  ): Promise<Annotation[]> {
    try {
      const params: any = {};
      if (dashboardId) params.dashboardId = dashboardId;
      if (panelId) params.panelId = panelId;
      if (tags) params.tags = tags;

      const response = await this.axiosInstance.get<Annotation[]>(
        '/api/annotations',
        { params }
      );
      this.authManager.addRequestTrace('ops-assistant', 'grafana', 'GET', 200);
      return response.data;
    } catch (error) {
      this.handleError('getAnnotations', error, '/api/annotations');
      return [];
    }
  }

  /**
   * Create annotation
   */
  async createAnnotation(
    dashboardId: number,
    panelId: number,
    text: string,
    tags: string[] = []
  ): Promise<number | null> {
    try {
      const response = await this.axiosInstance.post('/api/annotations', {
        dashboardId,
        panelId,
        text,
        tags,
        time: Date.now(),
      });
      this.authManager.addRequestTrace('ops-assistant', 'grafana', 'POST', 200);
      return response.data.id;
    } catch (error) {
      this.handleError('createAnnotation', error, '/api/annotations');
      return null;
    }
  }

  /**
   * Get data sources
   */
  async getDataSources(): Promise<any[]> {
    try {
      const response = await this.axiosInstance.get('/api/datasources');
      this.authManager.addRequestTrace('ops-assistant', 'grafana', 'GET', 200);
      return response.data;
    } catch (error) {
      this.handleError('getDataSources', error, '/api/datasources');
      return [];
    }
  }

  /**
   * Query Grafana datasource
   */
  async queryDatasource(datasourceId: number, targets: any[]): Promise<any> {
    try {
      const response = await this.axiosInstance.post(
        `/api/datasources/${datasourceId}/query`,
        { targets }
      );
      this.authManager.addRequestTrace('ops-assistant', 'grafana', 'POST', 200);
      return response.data;
    } catch (error) {
      this.handleError(`queryDatasource(${datasourceId})`, error, `/api/datasources/${datasourceId}/query`);
      return null;
    }
  }

  /**
   * Get Grafana version and health
   */
  async getHealth(): Promise<{ version: string; status: string } | null> {
    try {
      const response = await this.axiosInstance.get('/api/health');
      this.authManager.addRequestTrace('ops-assistant', 'grafana', 'GET', 200);
      return {
        version: response.data.version,
        status: response.data.status,
      };
    } catch (error) {
      this.handleError('getHealth', error, '/api/health');
      return null;
    }
  }

  /**
   * Get current user
   */
  async getCurrentUser(): Promise<any> {
    try {
      const response = await this.axiosInstance.get('/api/user');
      this.authManager.addRequestTrace('ops-assistant', 'grafana', 'GET', 200);
      return response.data;
    } catch (error) {
      this.handleError('getCurrentUser', error, '/api/user');
      return null;
    }
  }

  /**
   * Get organization info
   */
  async getOrganization(): Promise<any> {
    try {
      const response = await this.axiosInstance.get('/api/org');
      this.authManager.addRequestTrace('ops-assistant', 'grafana', 'GET', 200);
      return response.data;
    } catch (error) {
      this.handleError('getOrganization', error, '/api/org');
      return null;
    }
  }

  /**
   * Test datasource connection
   */
  async testDatasource(datasourceId: number): Promise<boolean> {
    try {
      await this.axiosInstance.get(`/api/datasources/${datasourceId}`);
      this.authManager.addRequestTrace('ops-assistant', 'grafana', 'GET', 200);
      return true;
    } catch (error) {
      this.handleError(`testDatasource(${datasourceId})`, error, `/api/datasources/${datasourceId}`);
      return false;
    }
  }

  /**
   * Get authentication and connection diagnostics
   */
  getDiagnostics() {
    return this.authManager.getDiagnostics();
  }
}
