import axios from 'axios';
export class GrafanaClient {
    constructor(baseUrl = 'http://grafana:3000', apiToken = process.env.GRAFANA_API_TOKEN || 'admin') {
        Object.defineProperty(this, "axiosInstance", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "baseUrl", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "apiToken", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
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
    async getDashboards(tags) {
        try {
            let url = '/api/search?type=dash-db';
            if (tags && tags.length > 0) {
                tags.forEach((tag) => {
                    url += `&tag=${tag}`;
                });
            }
            const response = await this.axiosInstance.get(url);
            return response.data;
        }
        catch (error) {
            console.error('[GrafanaClient] Error fetching dashboards:', error);
            return [];
        }
    }
    /**
     * Get dashboard by UID
     */
    async getDashboardByUid(uid) {
        try {
            const response = await this.axiosInstance.get(`/api/dashboards/uid/${uid}`);
            return response.data;
        }
        catch (error) {
            console.error(`[GrafanaClient] Error fetching dashboard ${uid}:`, error);
            return null;
        }
    }
    /**
     * Search dashboards by query
     */
    async searchDashboards(query) {
        try {
            const response = await this.axiosInstance.get('/api/search', {
                params: { query, type: 'dash-db' },
            });
            return response.data;
        }
        catch (error) {
            console.error('[GrafanaClient] Error searching dashboards:', error);
            return [];
        }
    }
    /**
     * Get all alerts
     */
    async getAlerts() {
        try {
            const response = await this.axiosInstance.get('/api/alerts');
            return response.data;
        }
        catch (error) {
            console.error('[GrafanaClient] Error fetching alerts:', error);
            return [];
        }
    }
    /**
     * Get alerts for specific dashboard
     */
    async getDashboardAlerts(dashboardId) {
        try {
            const response = await this.axiosInstance.get(`/api/alerts?dashboardId=${dashboardId}`);
            return response.data;
        }
        catch (error) {
            console.error(`[GrafanaClient] Error fetching alerts for dashboard ${dashboardId}:`, error);
            return [];
        }
    }
    /**
     * Get annotations
     */
    async getAnnotations(dashboardId, panelId, tags) {
        try {
            const params = {};
            if (dashboardId)
                params.dashboardId = dashboardId;
            if (panelId)
                params.panelId = panelId;
            if (tags)
                params.tags = tags;
            const response = await this.axiosInstance.get('/api/annotations', { params });
            return response.data;
        }
        catch (error) {
            console.error('[GrafanaClient] Error fetching annotations:', error);
            return [];
        }
    }
    /**
     * Create annotation
     */
    async createAnnotation(dashboardId, panelId, text, tags = []) {
        try {
            const response = await this.axiosInstance.post('/api/annotations', {
                dashboardId,
                panelId,
                text,
                tags,
                time: Date.now(),
            });
            return response.data.id;
        }
        catch (error) {
            console.error('[GrafanaClient] Error creating annotation:', error);
            return null;
        }
    }
    /**
     * Get data sources
     */
    async getDataSources() {
        try {
            const response = await this.axiosInstance.get('/api/datasources');
            return response.data;
        }
        catch (error) {
            console.error('[GrafanaClient] Error fetching datasources:', error);
            return [];
        }
    }
    /**
     * Query Grafana datasource
     */
    async queryDatasource(datasourceId, targets) {
        try {
            const response = await this.axiosInstance.post(`/api/datasources/${datasourceId}/query`, { targets });
            return response.data;
        }
        catch (error) {
            console.error('[GrafanaClient] Error querying datasource:', error);
            return null;
        }
    }
    /**
     * Get Grafana version and health
     */
    async getHealth() {
        try {
            const response = await this.axiosInstance.get('/api/health');
            return {
                version: response.data.version,
                status: response.data.status,
            };
        }
        catch (error) {
            console.error('[GrafanaClient] Error checking health:', error);
            return null;
        }
    }
    /**
     * Get current user
     */
    async getCurrentUser() {
        try {
            const response = await this.axiosInstance.get('/api/user');
            return response.data;
        }
        catch (error) {
            console.error('[GrafanaClient] Error fetching current user:', error);
            return null;
        }
    }
    /**
     * Get organization info
     */
    async getOrganization() {
        try {
            const response = await this.axiosInstance.get('/api/org');
            return response.data;
        }
        catch (error) {
            console.error('[GrafanaClient] Error fetching organization:', error);
            return null;
        }
    }
    /**
     * Test datasource connection
     */
    async testDatasource(datasourceId) {
        try {
            await this.axiosInstance.get(`/api/datasources/${datasourceId}`);
            return true;
        }
        catch (error) {
            console.error(`[GrafanaClient] Error testing datasource ${datasourceId}:`, error);
            return false;
        }
    }
}
//# sourceMappingURL=grafana-client.js.map