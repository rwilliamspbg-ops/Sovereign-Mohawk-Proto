/**
 * Query custom metrics with aggregation
 */
export declare const queryMetricAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            query: {
                type: string;
                description: string;
            };
            timeRange: {
                type: string;
                description: string;
                default: string;
            };
            step: {
                type: string;
                description: string;
                default: string;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        error: string;
        success?: undefined;
        data?: undefined;
        query?: undefined;
    } | {
        success: boolean;
        data: any;
        query: any;
        error?: undefined;
    }>;
};
/**
 * Get and explain Grafana dashboard
 */
export declare const explainDashboardAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            dashboardUid: {
                type: string;
                description: string;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        error: string;
        success?: undefined;
        dashboard?: undefined;
    } | {
        success: boolean;
        dashboard: {
            title: string;
            description: string | undefined;
            panelCount: number;
            panels: {
                id: number;
                title: string;
                type: string;
                targets: number;
            }[];
            tags: string[];
        };
        error?: undefined;
    }>;
};
/**
 * Identify anomalies in metrics
 */
export declare const identifyAnomalyAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            query: {
                type: string;
                description: string;
            };
            threshold: {
                type: string;
                description: string;
                default: number;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        error: string;
        success?: undefined;
        anomaliesCount?: undefined;
        anomalies?: undefined;
    } | {
        success: boolean;
        anomaliesCount: number;
        anomalies: any[];
        error?: undefined;
    }>;
};
/**
 * Compare multiple metrics side-by-side
 */
export declare const compareMetricsAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            queries: {
                type: string;
                items: {
                    type: string;
                };
                description: string;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        success: boolean;
        comparisons: any[];
        error?: undefined;
    } | {
        error: string;
        success?: undefined;
        comparisons?: undefined;
    }>;
};
/**
 * Predict metric trends
 */
export declare const predictTrendAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            query: {
                type: string;
                description: string;
            };
            hoursToPredict: {
                type: string;
                description: string;
                default: number;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        error: string;
        success?: undefined;
        predictions?: undefined;
    } | {
        success: boolean;
        predictions: any[];
        error?: undefined;
    }>;
};
/**
 * Search for events in dashboards
 */
export declare const searchEventsAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            query: {
                type: string;
                description: string;
            };
            dashboardId: {
                type: string;
                description: string;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        success: boolean;
        annotations: import("./grafana-client.js").Annotation[];
        alerts: import("./grafana-client.js").Alert[];
        error?: undefined;
    } | {
        error: string;
        success?: undefined;
        annotations?: undefined;
        alerts?: undefined;
    }>;
};
/**
 * Get network topology view
 */
export declare const getNetworkTopologyAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            scope: {
                type: string;
                description: string;
                default: string;
            };
        };
    };
    handler: (params: any) => Promise<{
        success: boolean;
        nodes: any;
        edges: any;
        error?: undefined;
    } | {
        error: string;
        success?: undefined;
        nodes?: undefined;
        edges?: undefined;
    }>;
};
/**
 * Create alert on condition
 */
export declare const alertOnConditionAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            query: {
                type: string;
                description: string;
            };
            threshold: {
                type: string;
                description: string;
            };
            operator: {
                type: string;
                enum: string[];
                description: string;
            };
            alertName: {
                type: string;
                description: string;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        error: string;
        success?: undefined;
        alert?: undefined;
    } | {
        success: boolean;
        alert: {
            name: any;
            query: any;
            condition: string;
            status: string;
        };
        error?: undefined;
    }>;
};
/**
 * Analyze component performance
 */
export declare const analyzePerformanceAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            component: {
                type: string;
                description: string;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        success: boolean;
        component: any;
        metrics: any;
        error?: undefined;
    } | {
        error: string;
        success?: undefined;
        component?: undefined;
        metrics?: undefined;
    }>;
};
/**
 * Get federated learning round status
 */
export declare const getRoundStatusAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            includeEvidence: {
                type: string;
                default: boolean;
            };
        };
    };
    handler: () => Promise<{
        success: boolean;
        status: import("./federated-intelligence.js").FLRoundStatus;
        reasoning: string[];
        requiresConfirmation: boolean;
    }>;
};
/**
 * Explain model drift
 */
export declare const explainModelDriftAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            objective: {
                type: string;
                default: string;
            };
        };
    };
    handler: () => Promise<{
        reasoning: string[];
        requiresConfirmation: boolean;
        objective: string;
        driftScore: number;
        confidenceDelta: number;
        affectedNodes: string[];
        recommendation: string;
        success: boolean;
    }>;
};
/**
 * List contributing nodes
 */
export declare const listContributingNodesAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            objective: {
                type: string;
                default: string;
            };
        };
    };
    handler: () => Promise<{
        success: boolean;
        nodes: import("./federated-intelligence.js").FLContributor[];
        reasoning: string[];
        requiresConfirmation: boolean;
    }>;
};
/**
 * Detect federated anomalies
 */
export declare const detectAnomaliesAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            severityThreshold: {
                type: string;
                enum: string[];
                default: string;
            };
        };
    };
    handler: () => Promise<{
        success: boolean;
        anomalies: import("./federated-intelligence.js").FLAnomaly[];
        reasoning: string[];
        requiresConfirmation: boolean;
    }>;
};
/**
 * Get federated intelligence scoreboard
 */
export declare const getIntelligenceScoreboardAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {};
    };
    handler: () => Promise<{
        success: boolean;
        scoreboard: import("./federated-intelligence.js").FLIntelligenceScoreboard;
        reasoning: string[];
        requiresConfirmation: boolean;
    }>;
};
/**
 * Get network statistics and health overview
 */
export declare const getNetworkStatsAction: {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            timeRange: {
                type: string;
                description: string;
                default: string;
            };
        };
    };
    handler: (params: any) => Promise<{
        success: boolean;
        stats: {
            uptime: string;
            errorRate: string;
            timestamp: Date;
            healthy: boolean;
        };
        error?: undefined;
    } | {
        error: string;
        success?: undefined;
        stats?: undefined;
    }>;
};
/**
 * Export all actions as array for CopilotKit registration
 */
export declare const advancedActions: ({
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            query: {
                type: string;
                description: string;
            };
            timeRange: {
                type: string;
                description: string;
                default: string;
            };
            step: {
                type: string;
                description: string;
                default: string;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        error: string;
        success?: undefined;
        data?: undefined;
        query?: undefined;
    } | {
        success: boolean;
        data: any;
        query: any;
        error?: undefined;
    }>;
} | {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            dashboardUid: {
                type: string;
                description: string;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        error: string;
        success?: undefined;
        dashboard?: undefined;
    } | {
        success: boolean;
        dashboard: {
            title: string;
            description: string | undefined;
            panelCount: number;
            panels: {
                id: number;
                title: string;
                type: string;
                targets: number;
            }[];
            tags: string[];
        };
        error?: undefined;
    }>;
} | {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            query: {
                type: string;
                description: string;
            };
            threshold: {
                type: string;
                description: string;
                default: number;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        error: string;
        success?: undefined;
        anomaliesCount?: undefined;
        anomalies?: undefined;
    } | {
        success: boolean;
        anomaliesCount: number;
        anomalies: any[];
        error?: undefined;
    }>;
} | {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            queries: {
                type: string;
                items: {
                    type: string;
                };
                description: string;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        success: boolean;
        comparisons: any[];
        error?: undefined;
    } | {
        error: string;
        success?: undefined;
        comparisons?: undefined;
    }>;
} | {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            query: {
                type: string;
                description: string;
            };
            hoursToPredict: {
                type: string;
                description: string;
                default: number;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        error: string;
        success?: undefined;
        predictions?: undefined;
    } | {
        success: boolean;
        predictions: any[];
        error?: undefined;
    }>;
} | {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            query: {
                type: string;
                description: string;
            };
            dashboardId: {
                type: string;
                description: string;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        success: boolean;
        annotations: import("./grafana-client.js").Annotation[];
        alerts: import("./grafana-client.js").Alert[];
        error?: undefined;
    } | {
        error: string;
        success?: undefined;
        annotations?: undefined;
        alerts?: undefined;
    }>;
} | {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            scope: {
                type: string;
                description: string;
                default: string;
            };
        };
    };
    handler: (params: any) => Promise<{
        success: boolean;
        nodes: any;
        edges: any;
        error?: undefined;
    } | {
        error: string;
        success?: undefined;
        nodes?: undefined;
        edges?: undefined;
    }>;
} | {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            query: {
                type: string;
                description: string;
            };
            threshold: {
                type: string;
                description: string;
            };
            operator: {
                type: string;
                enum: string[];
                description: string;
            };
            alertName: {
                type: string;
                description: string;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        error: string;
        success?: undefined;
        alert?: undefined;
    } | {
        success: boolean;
        alert: {
            name: any;
            query: any;
            condition: string;
            status: string;
        };
        error?: undefined;
    }>;
} | {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            component: {
                type: string;
                description: string;
            };
        };
        required: string[];
    };
    handler: (params: any) => Promise<{
        success: boolean;
        component: any;
        metrics: any;
        error?: undefined;
    } | {
        error: string;
        success?: undefined;
        component?: undefined;
        metrics?: undefined;
    }>;
} | {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            includeEvidence: {
                type: string;
                default: boolean;
            };
        };
    };
    handler: () => Promise<{
        success: boolean;
        status: import("./federated-intelligence.js").FLRoundStatus;
        reasoning: string[];
        requiresConfirmation: boolean;
    }>;
} | {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            objective: {
                type: string;
                default: string;
            };
        };
    };
    handler: () => Promise<{
        reasoning: string[];
        requiresConfirmation: boolean;
        objective: string;
        driftScore: number;
        confidenceDelta: number;
        affectedNodes: string[];
        recommendation: string;
        success: boolean;
    }>;
} | {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            objective: {
                type: string;
                default: string;
            };
        };
    };
    handler: () => Promise<{
        success: boolean;
        nodes: import("./federated-intelligence.js").FLContributor[];
        reasoning: string[];
        requiresConfirmation: boolean;
    }>;
} | {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            severityThreshold: {
                type: string;
                enum: string[];
                default: string;
            };
        };
    };
    handler: () => Promise<{
        success: boolean;
        anomalies: import("./federated-intelligence.js").FLAnomaly[];
        reasoning: string[];
        requiresConfirmation: boolean;
    }>;
} | {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {};
    };
    handler: () => Promise<{
        success: boolean;
        scoreboard: import("./federated-intelligence.js").FLIntelligenceScoreboard;
        reasoning: string[];
        requiresConfirmation: boolean;
    }>;
} | {
    name: string;
    description: string;
    parameters: {
        type: string;
        properties: {
            timeRange: {
                type: string;
                description: string;
                default: string;
            };
        };
    };
    handler: (params: any) => Promise<{
        success: boolean;
        stats: {
            uptime: string;
            errorRate: string;
            timestamp: Date;
            healthy: boolean;
        };
        error?: undefined;
    } | {
        error: string;
        success?: undefined;
        stats?: undefined;
    }>;
})[];
//# sourceMappingURL=actions.d.ts.map