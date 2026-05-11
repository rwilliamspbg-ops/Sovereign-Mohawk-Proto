export interface PrometheusResponse {
    status: string;
    data?: {
        resultType?: string;
        result?: Array<{
            metric: Record<string, string>;
            value?: [number, string];
            values?: Array<[number, string]>;
        }>;
    };
    error?: string;
}
export declare function queryPrometheus(query: string, time?: number): Promise<PrometheusResponse>;
export declare function queryPrometheusRange(query: string, startTime: number, endTime: number, step?: string): Promise<PrometheusResponse>;
export declare function queryPrometheusHealth(): Promise<boolean>;
/**
 * Convert relative time like "30m ago" to Unix timestamp
 */
export declare function parseRelativeTime(timeStr: string): number;
export declare const KEY_METRICS: {
    throughput: string;
    verifications: string;
    acceleratorOps: string;
    failures: string;
    byzantineRejects: string;
    roundLatencyP95: string;
    proofLatencyP95: string;
};
//# sourceMappingURL=prometheus-client.d.ts.map