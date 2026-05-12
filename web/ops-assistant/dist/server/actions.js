import axios from 'axios';
import { GrafanaClient } from './grafana-client.js';
import { detectAnomalies, explainModelDrift, getIntelligenceScoreboard, getRoundStatus, listContributingNodes, } from './federated-intelligence.js';
/**
 * Advanced CopilotKit Actions for Network Operations
 * Provides sophisticated operations for network monitoring and analysis
 */
const prometheusUrl = process.env.PROMETHEUS_URL || 'http://prometheus:9090';
const grafanaClient = new GrafanaClient();
// Validation schemas
const validatePromQL = (query) => {
    // Basic PromQL validation - ensure it's not empty and doesn't contain dangerous characters
    return Boolean(query && query.length > 0 && !query.includes(';') && !query.includes('--'));
};
/**
 * Query custom metrics with aggregation
 */
export const queryMetricAction = {
    name: 'queryMetric',
    description: 'Query Prometheus metrics with custom PromQL. Advanced metric queries with aggregation, filters, and time series analysis.',
    parameters: {
        type: 'object',
        properties: {
            query: {
                type: 'string',
                description: 'PromQL query (e.g., "rate(http_requests_total[5m])" or "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))")',
            },
            timeRange: {
                type: 'string',
                description: 'Time range back from now (e.g., "1h", "24h", "7d")',
                default: '1h',
            },
            step: {
                type: 'string',
                description: 'Resolution of the query results (e.g., "30s", "1m", "5m")',
                default: '1m',
            },
        },
        required: ['query'],
    },
    handler: async (params) => {
        if (!validatePromQL(params.query)) {
            return { error: 'Invalid PromQL query' };
        }
        try {
            const response = await axios.get(`${prometheusUrl}/api/v1/query_range`, {
                params: {
                    query: params.query,
                    start: `${Math.floor(Date.now() / 1000) - 3600}`,
                    end: Math.floor(Date.now() / 1000),
                    step: params.step || '1m',
                },
            });
            return {
                success: true,
                data: response.data.data.result,
                query: params.query,
            };
        }
        catch (error) {
            return {
                error: error instanceof Error ? error.message : 'Query failed',
            };
        }
    },
};
/**
 * Get and explain Grafana dashboard
 */
export const explainDashboardAction = {
    name: 'explainDashboard',
    description: 'Analyze and explain a Grafana dashboard, including panels, metrics, and data sources used.',
    parameters: {
        type: 'object',
        properties: {
            dashboardUid: {
                type: 'string',
                description: 'Dashboard UID',
            },
        },
        required: ['dashboardUid'],
    },
    handler: async (params) => {
        try {
            const dashboard = await grafanaClient.getDashboardByUid(params.dashboardUid);
            if (!dashboard) {
                return { error: 'Dashboard not found' };
            }
            const analysis = {
                title: dashboard.dashboard.title,
                description: dashboard.dashboard.description,
                panelCount: dashboard.dashboard.panels.length,
                panels: dashboard.dashboard.panels.map((panel) => ({
                    id: panel.id,
                    title: panel.title,
                    type: panel.type,
                    targets: panel.targets?.length || 0,
                })),
                tags: dashboard.dashboard.tags,
            };
            return {
                success: true,
                dashboard: analysis,
            };
        }
        catch (error) {
            return {
                error: error instanceof Error ? error.message : 'Failed to fetch dashboard',
            };
        }
    },
};
/**
 * Identify anomalies in metrics
 */
export const identifyAnomalyAction = {
    name: 'identifyAnomaly',
    description: 'Use statistical analysis to identify anomalies in metric data.',
    parameters: {
        type: 'object',
        properties: {
            query: {
                type: 'string',
                description: 'PromQL query to analyze',
            },
            threshold: {
                type: 'number',
                description: 'Standard deviations from mean to flag as anomaly (default: 2)',
                default: 2,
            },
        },
        required: ['query'],
    },
    handler: async (params) => {
        if (!validatePromQL(params.query)) {
            return { error: 'Invalid PromQL query' };
        }
        try {
            const response = await axios.get(`${prometheusUrl}/api/v1/query_range`, {
                params: {
                    query: params.query,
                    start: `${Math.floor(Date.now() / 1000) - 86400}`, // 24h
                    end: Math.floor(Date.now() / 1000),
                    step: '5m',
                },
            });
            const results = response.data.data.result;
            const anomalies = [];
            for (const series of results) {
                const values = series.values.map((v) => parseFloat(v[1]));
                const mean = values.reduce((a, b) => a + b, 0) / values.length;
                const variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) /
                    values.length;
                const stdDev = Math.sqrt(variance);
                series.values.forEach((v, idx) => {
                    const value = parseFloat(v[1]);
                    const zScore = Math.abs((value - mean) / stdDev);
                    if (zScore > (params.threshold || 2)) {
                        anomalies.push({
                            timestamp: new Date(parseInt(v[0]) * 1000),
                            value,
                            zScore,
                            labels: series.metric,
                        });
                    }
                });
            }
            return {
                success: true,
                anomaliesCount: anomalies.length,
                anomalies: anomalies.slice(-10), // Return last 10
            };
        }
        catch (error) {
            return {
                error: error instanceof Error ? error.message : 'Anomaly detection failed',
            };
        }
    },
};
/**
 * Compare multiple metrics side-by-side
 */
export const compareMetricsAction = {
    name: 'compareMetrics',
    description: 'Compare multiple metrics side-by-side to identify patterns and correlations.',
    parameters: {
        type: 'object',
        properties: {
            queries: {
                type: 'array',
                items: { type: 'string' },
                description: 'Array of PromQL queries to compare',
            },
        },
        required: ['queries'],
    },
    handler: async (params) => {
        try {
            const comparisons = [];
            for (const query of params.queries || []) {
                if (!validatePromQL(query)) {
                    comparisons.push({ query, error: 'Invalid PromQL' });
                    continue;
                }
                const response = await axios.get(`${prometheusUrl}/api/v1/query`, {
                    params: { query },
                });
                comparisons.push({
                    query,
                    results: response.data.data.result,
                });
            }
            return {
                success: true,
                comparisons,
            };
        }
        catch (error) {
            return {
                error: error instanceof Error ? error.message : 'Comparison failed',
            };
        }
    },
};
/**
 * Predict metric trends
 */
export const predictTrendAction = {
    name: 'predictTrend',
    description: 'Analyze historical data and predict future metric trends using linear regression.',
    parameters: {
        type: 'object',
        properties: {
            query: {
                type: 'string',
                description: 'PromQL query for trend analysis',
            },
            hoursToPredict: {
                type: 'number',
                description: 'Hours into the future to predict',
                default: 24,
            },
        },
        required: ['query'],
    },
    handler: async (params) => {
        if (!validatePromQL(params.query)) {
            return { error: 'Invalid PromQL query' };
        }
        try {
            const hoursBack = Math.max(params.hoursToPredict * 2, 48);
            const response = await axios.get(`${prometheusUrl}/api/v1/query_range`, {
                params: {
                    query: params.query,
                    start: `${Math.floor(Date.now() / 1000) - hoursBack * 3600}`,
                    end: Math.floor(Date.now() / 1000),
                    step: '1h',
                },
            });
            const results = response.data.data.result;
            const predictions = [];
            for (const series of results) {
                const values = series.values.map((v) => parseFloat(v[1]));
                // Simple linear regression
                const n = values.length;
                const sumX = (n * (n - 1)) / 2;
                const sumY = values.reduce((a, b) => a + b, 0);
                const sumXY = values.reduce((sum, val, idx) => sum + idx * val, 0);
                const sumX2 = ((n - 1) * n * (2 * n - 1)) / 6;
                const slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
                const intercept = (sumY - slope * sumX) / n;
                // Predict next hoursToPredict hours
                const predictedValues = [];
                for (let i = 1; i <= (params.hoursToPredict || 24); i++) {
                    const predicted = intercept + slope * (n + i);
                    predictedValues.push({
                        hour: i,
                        value: Math.max(0, predicted),
                    });
                }
                predictions.push({
                    labels: series.metric,
                    currentValue: values[values.length - 1],
                    trend: slope > 0 ? 'increasing' : 'decreasing',
                    predictions: predictedValues,
                });
            }
            return {
                success: true,
                predictions,
            };
        }
        catch (error) {
            return {
                error: error instanceof Error ? error.message : 'Prediction failed',
            };
        }
    },
};
/**
 * Search for events in dashboards
 */
export const searchEventsAction = {
    name: 'searchEvents',
    description: 'Search for events, annotations, and alerts across dashboards.',
    parameters: {
        type: 'object',
        properties: {
            query: {
                type: 'string',
                description: 'Search query for events',
            },
            dashboardId: {
                type: 'number',
                description: 'Optional dashboard ID to limit search',
            },
        },
        required: ['query'],
    },
    handler: async (params) => {
        try {
            const annotations = await grafanaClient.getAnnotations(params.dashboardId);
            const alerts = await grafanaClient.getAlerts();
            const filteredAnnotations = annotations.filter((a) => a.text.toLowerCase().includes(params.query.toLowerCase()));
            const filteredAlerts = alerts.filter((a) => a.name.toLowerCase().includes(params.query.toLowerCase()) ||
                a.message.toLowerCase().includes(params.query.toLowerCase()));
            return {
                success: true,
                annotations: filteredAnnotations,
                alerts: filteredAlerts,
            };
        }
        catch (error) {
            return {
                error: error instanceof Error ? error.message : 'Event search failed',
            };
        }
    },
};
/**
 * Get network topology view
 */
export const getNetworkTopologyAction = {
    name: 'getNetworkTopology',
    description: 'Visualize network topology and component relationships based on metrics.',
    parameters: {
        type: 'object',
        properties: {
            scope: {
                type: 'string',
                description: 'Scope for topology (e.g., "kubernetes", "services", "hosts")',
                default: 'services',
            },
        },
    },
    handler: async (params) => {
        try {
            // Get services from metrics
            const response = await axios.get(`${prometheusUrl}/api/v1/query`, {
                params: {
                    query: `count by (job) (up)`,
                },
            });
            const nodes = response.data.data.result.map((r) => ({
                id: r.metric.job,
                label: r.metric.job,
                status: parseInt(r.value[1]) === 1 ? 'up' : 'down',
            }));
            return {
                success: true,
                nodes,
                edges: nodes.length > 1
                    ? nodes.slice(0, -1).map((n, i) => ({
                        from: n.id,
                        to: nodes[i + 1].id,
                    }))
                    : [],
            };
        }
        catch (error) {
            return {
                error: error instanceof Error ? error.message : 'Topology generation failed',
            };
        }
    },
};
/**
 * Create alert on condition
 */
export const alertOnConditionAction = {
    name: 'alertOnCondition',
    description: 'Create a custom alert that triggers when a metric crosses a threshold.',
    parameters: {
        type: 'object',
        properties: {
            query: {
                type: 'string',
                description: 'PromQL query for alert condition',
            },
            threshold: {
                type: 'number',
                description: 'Threshold value',
            },
            operator: {
                type: 'string',
                enum: ['>', '<', '==', '!=', '>=', '<='],
                description: 'Comparison operator',
            },
            alertName: {
                type: 'string',
                description: 'Name for the alert',
            },
        },
        required: ['query', 'threshold', 'operator', 'alertName'],
    },
    handler: async (params) => {
        if (!validatePromQL(params.query)) {
            return { error: 'Invalid PromQL query' };
        }
        // In production, this would create an actual alert rule in Prometheus/Grafana
        return {
            success: true,
            alert: {
                name: params.alertName,
                query: params.query,
                condition: `${params.operator} ${params.threshold}`,
                status: 'created',
            },
        };
    },
};
/**
 * Analyze component performance
 */
export const analyzePerformanceAction = {
    name: 'analyzePerformance',
    description: 'Comprehensive performance analysis of system components including latency, throughput, and resource usage.',
    parameters: {
        type: 'object',
        properties: {
            component: {
                type: 'string',
                description: 'Component name to analyze (e.g., "api-gateway", "database")',
            },
        },
        required: ['component'],
    },
    handler: async (params) => {
        try {
            const queries = [
                `rate(http_request_duration_seconds_sum{job="${params.component}"}[5m])`,
                `rate(http_requests_total{job="${params.component}"}[5m])`,
                `node_memory_MemAvailable_bytes{job="${params.component}"}`,
                `rate(node_cpu_seconds_total{job="${params.component}"}[5m])`,
            ];
            const results = {};
            for (const query of queries) {
                try {
                    const response = await axios.get(`${prometheusUrl}/api/v1/query`, {
                        params: { query },
                    });
                    const label = query.split('(')[0];
                    results[label] = response.data.data.result;
                }
                catch (e) {
                    // Metric not available
                }
            }
            return {
                success: true,
                component: params.component,
                metrics: results,
            };
        }
        catch (error) {
            return {
                error: error instanceof Error ? error.message : 'Performance analysis failed',
            };
        }
    },
};
/**
 * Get federated learning round status
 */
export const getRoundStatusAction = {
    name: 'get_round_status',
    description: 'Get the current federated learning round status, including phase, progress, confidence, drift, and reasoning.',
    parameters: {
        type: 'object',
        properties: {
            includeEvidence: {
                type: 'boolean',
                default: true,
            },
        },
    },
    handler: async () => {
        const status = await getRoundStatus();
        const scoreboard = await getIntelligenceScoreboard();
        return {
            success: true,
            status,
            reasoning: scoreboard.supportingEvidence,
            requiresConfirmation: scoreboard.requiresConfirmation,
        };
    },
};
/**
 * Explain model drift
 */
export const explainModelDriftAction = {
    name: 'explain_model_drift',
    description: 'Explain why model drift is changing, which nodes are affected, and what operator action is recommended.',
    parameters: {
        type: 'object',
        properties: {
            objective: {
                type: 'string',
                default: 'Objective Z',
            },
        },
    },
    handler: async () => {
        const drift = await explainModelDrift();
        return {
            success: true,
            ...drift,
            reasoning: [drift.reasoning, drift.recommendation],
            requiresConfirmation: false,
        };
    },
};
/**
 * List contributing nodes
 */
export const listContributingNodesAction = {
    name: 'list_contributing_nodes',
    description: 'Rank contributing federated nodes by their value to the current objective and return reasoning for each.',
    parameters: {
        type: 'object',
        properties: {
            objective: {
                type: 'string',
                default: 'Objective Z',
            },
        },
    },
    handler: async () => {
        const nodes = await listContributingNodes();
        return {
            success: true,
            nodes,
            reasoning: nodes.map((node) => node.reasoning),
            requiresConfirmation: false,
        };
    },
};
/**
 * Detect federated anomalies
 */
export const detectAnomaliesAction = {
    name: 'detect_anomalies',
    description: 'Detect drift, poisoning, Byzantine, attestation, or latency anomalies in the current federated round.',
    parameters: {
        type: 'object',
        properties: {
            severityThreshold: {
                type: 'string',
                enum: ['low', 'medium', 'high'],
                default: 'medium',
            },
        },
    },
    handler: async () => {
        const anomalies = await detectAnomalies();
        const filtered = anomalies.filter((anomaly) => anomaly.severity !== 'low');
        return {
            success: true,
            anomalies: filtered,
            reasoning: filtered.map((anomaly) => anomaly.evidence),
            requiresConfirmation: filtered.some((anomaly) => anomaly.severity === 'high'),
        };
    },
};
/**
 * Get federated intelligence scoreboard
 */
export const getIntelligenceScoreboardAction = {
    name: 'get_intelligence_scoreboard',
    description: 'Return the current federated intelligence scoreboard with confidence, drift, contributors, and anomaly summary.',
    parameters: {
        type: 'object',
        properties: {},
    },
    handler: async () => {
        const scoreboard = await getIntelligenceScoreboard();
        return {
            success: true,
            scoreboard,
            reasoning: scoreboard.supportingEvidence,
            requiresConfirmation: scoreboard.requiresConfirmation,
        };
    },
};
/**
 * Get network statistics and health overview
 */
export const getNetworkStatsAction = {
    name: 'getNetworkStats',
    description: 'Get comprehensive network statistics including uptime, error rates, and health indicators.',
    parameters: {
        type: 'object',
        properties: {
            timeRange: {
                type: 'string',
                description: 'Time range for statistics (e.g., "1h", "24h")',
                default: '24h',
            },
        },
    },
    handler: async (params) => {
        try {
            const upResponse = await axios.get(`${prometheusUrl}/api/v1/query`, {
                params: { query: `count(up == 1) / count(up)` },
            });
            const uptime = parseFloat(upResponse.data.data.result[0]?.value[1] || 0) * 100;
            const errorResponse = await axios.get(`${prometheusUrl}/api/v1/query`, {
                params: {
                    query: `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))`,
                },
            });
            const errorRate = parseFloat(errorResponse.data.data.result[0]?.value[1] || 0) * 100;
            return {
                success: true,
                stats: {
                    uptime: `${uptime.toFixed(2)}%`,
                    errorRate: `${errorRate.toFixed(2)}%`,
                    timestamp: new Date(),
                    healthy: uptime > 99 && errorRate < 1,
                },
            };
        }
        catch (error) {
            return {
                error: error instanceof Error ? error.message : 'Stats retrieval failed',
            };
        }
    },
};
/**
 * Export all actions as array for CopilotKit registration
 */
export const advancedActions = [
    queryMetricAction,
    explainDashboardAction,
    identifyAnomalyAction,
    compareMetricsAction,
    predictTrendAction,
    searchEventsAction,
    getNetworkTopologyAction,
    alertOnConditionAction,
    analyzePerformanceAction,
    getNetworkStatsAction,
    getRoundStatusAction,
    explainModelDriftAction,
    listContributingNodesAction,
    detectAnomaliesAction,
    getIntelligenceScoreboardAction,
];
//# sourceMappingURL=actions.js.map