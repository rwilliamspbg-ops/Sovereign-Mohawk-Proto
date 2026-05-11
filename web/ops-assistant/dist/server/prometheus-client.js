import axios from 'axios';
const PROMETHEUS_URL = process.env.PROMETHEUS_URL || 'http://prometheus:9090';
export async function queryPrometheus(query, time) {
    try {
        const params = { query };
        if (time)
            params.time = time;
        const response = await axios.get(`${PROMETHEUS_URL}/api/v1/query`, { params });
        return response.data;
    }
    catch (error) {
        console.error('Prometheus instant query error:', error);
        throw new Error(`Failed to query Prometheus: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
}
export async function queryPrometheusRange(query, startTime, endTime, step = '60s') {
    try {
        const params = {
            query,
            start: startTime,
            end: endTime,
            step
        };
        const response = await axios.get(`${PROMETHEUS_URL}/api/v1/query_range`, { params });
        return response.data;
    }
    catch (error) {
        console.error('Prometheus range query error:', error);
        throw new Error(`Failed to query Prometheus range: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
}
export async function queryPrometheusHealth() {
    try {
        const response = await axios.get(`${PROMETHEUS_URL}/-/healthy`, {
            timeout: 5000
        });
        return response.status === 200;
    }
    catch {
        return false;
    }
}
/**
 * Convert relative time like "30m ago" to Unix timestamp
 */
export function parseRelativeTime(timeStr) {
    if (timeStr === 'now') {
        return Math.floor(Date.now() / 1000);
    }
    const match = timeStr.match(/(\d+)([smhd])\s?(?:ago)?/);
    if (!match) {
        throw new Error(`Invalid time format: ${timeStr}`);
    }
    const value = parseInt(match[1], 10);
    const unit = match[2];
    let seconds = 0;
    switch (unit) {
        case 's':
            seconds = value;
            break;
        case 'm':
            seconds = value * 60;
            break;
        case 'h':
            seconds = value * 3600;
            break;
        case 'd':
            seconds = value * 86400;
            break;
    }
    return Math.floor(Date.now() / 1000) - seconds;
}
export const KEY_METRICS = {
    throughput: 'rate(mohawk:gradient_submit:total[1m])',
    verifications: 'rate(mohawk:proof_verifications:rate1m[1m])',
    acceleratorOps: 'rate(mohawk:accelerator_ops:rate1m[1m])',
    failures: 'rate(mohawk:gradient_submit:failure_rate_5m[1m])',
    byzantineRejects: 'increase(mohawk_fedavg_byzantine_filtered_total[5m])',
    roundLatencyP95: 'histogram_quantile(0.95, mohawk_fedavg_round_latency_quantile_ms)',
    proofLatencyP95: 'histogram_quantile(0.95, mohawk_operator_op_latency_ms)'
};
//# sourceMappingURL=prometheus-client.js.map