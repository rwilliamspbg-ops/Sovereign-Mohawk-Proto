import axios, { AxiosInstance } from 'axios';

/**
 * Grafana API Client
 * Provides methods to interact with Grafana dashboards, alerts, and annotations
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

  constructor(
    baseUrl: string = 'http://grafana:3000',
    apiToken: string = process.env.GRAFANA_API_TOKEN || 'admin'
  ) {
    this.baseUrl = baseUrl;
    this.apiToken = apiToken;

    this.axiosInstance = axios.create({
      baseURL: baseUrl,
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      timeout: 10000,
    });
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
      return response.data;
    } catch (error) {
      console.error('[GrafanaClient] Error fetching dashboards:', error);
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
      return response.data;
    } catch (error) {
      console.error(`[GrafanaClient] Error fetching dashboard ${uid}:`, error);
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
      return response.data;
    } catch (error) {
      console.error('[GrafanaClient] Error searching dashboards:', error);
      return [];
    }
  }

  /**
   * Get all alerts
   */
  async getAlerts(): Promise<Alert[]> {
    try {
      const response = await this.axiosInstance.get<Alert[]>('/api/alerts');
      return response.data;
    } catch (error) {
      console.error('[GrafanaClient] Error fetching alerts:', error);
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
      return response.data;
    } catch (error) {
      console.error(
        `[GrafanaClient] Error fetching alerts for dashboard ${dashboardId}:`,
        error
      );
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
      return response.data;
    } catch (error) {
      console.error('[GrafanaClient] Error fetching annotations:', error);
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
      return response.data.id;
    } catch (error) {
      console.error('[GrafanaClient] Error creating annotation:', error);
      return null;
    }
  }

  /**
   * Get data sources
   */
  async getDataSources(): Promise<any[]> {
    try {
      const response = await this.axiosInstance.get('/api/datasources');
      return response.data;
    } catch (error) {
      console.error('[GrafanaClient] Error fetching datasources:', error);
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
      return response.data;
    } catch (error) {
      console.error('[GrafanaClient] Error querying datasource:', error);
      return null;
    }
  }

  /**
   * Get Grafana version and health
   */
  async getHealth(): Promise<{ version: string; status: string } | null> {
    try {
      const response = await this.axiosInstance.get('/api/health');
      return {
        version: response.data.version,
        status: response.data.status,
      };
    } catch (error) {
      console.error('[GrafanaClient] Error checking health:', error);
      return null;
    }
  }

  /**
   * Get current user
   */
  async getCurrentUser(): Promise<any> {
    try {
      const response = await this.axiosInstance.get('/api/user');
      return response.data;
    } catch (error) {
      console.error('[GrafanaClient] Error fetching current user:', error);
      return null;
    }
  }

  /**
   * Get organization info
   */
  async getOrganization(): Promise<any> {
    try {
      const response = await this.axiosInstance.get('/api/org');
      return response.data;
    } catch (error) {
      console.error('[GrafanaClient] Error fetching organization:', error);
      return null;
    }
  }

  /**
   * Test datasource connection
   */
  async testDatasource(datasourceId: number): Promise<boolean> {
    try {
      await this.axiosInstance.get(`/api/datasources/${datasourceId}`);
      return true;
    } catch (error) {
      console.error(
        `[GrafanaClient] Error testing datasource ${datasourceId}:`,
        error
      );
      return false;
    }
  }
}
