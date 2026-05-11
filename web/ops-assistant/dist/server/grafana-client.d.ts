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
export declare class GrafanaClient {
    private axiosInstance;
    private baseUrl;
    private apiToken;
    constructor(baseUrl?: string, apiToken?: string);
    /**
     * Get all dashboards
     */
    getDashboards(tags?: string[]): Promise<Dashboard[]>;
    /**
     * Get dashboard by UID
     */
    getDashboardByUid(uid: string): Promise<DashboardDetail | null>;
    /**
     * Search dashboards by query
     */
    searchDashboards(query: string): Promise<Dashboard[]>;
    /**
     * Get all alerts
     */
    getAlerts(): Promise<Alert[]>;
    /**
     * Get alerts for specific dashboard
     */
    getDashboardAlerts(dashboardId: number): Promise<Alert[]>;
    /**
     * Get annotations
     */
    getAnnotations(dashboardId?: number, panelId?: number, tags?: string[]): Promise<Annotation[]>;
    /**
     * Create annotation
     */
    createAnnotation(dashboardId: number, panelId: number, text: string, tags?: string[]): Promise<number | null>;
    /**
     * Get data sources
     */
    getDataSources(): Promise<any[]>;
    /**
     * Query Grafana datasource
     */
    queryDatasource(datasourceId: number, targets: any[]): Promise<any>;
    /**
     * Get Grafana version and health
     */
    getHealth(): Promise<{
        version: string;
        status: string;
    } | null>;
    /**
     * Get current user
     */
    getCurrentUser(): Promise<any>;
    /**
     * Get organization info
     */
    getOrganization(): Promise<any>;
    /**
     * Test datasource connection
     */
    testDatasource(datasourceId: number): Promise<boolean>;
}
//# sourceMappingURL=grafana-client.d.ts.map