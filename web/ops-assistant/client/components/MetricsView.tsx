import React, { useEffect, useState } from 'react';
import { LineChart, Line, AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { useWebSocket } from '../hooks/useWebSocket';
import { getRuntimeConfig, buildApiUrl } from '../config';
import '../styles/metrics.css';

interface Metric {
  name: string;
  value: number;
  unit: string;
  type: 'cpu' | 'memory' | 'network' | 'latency' | 'requests';
  trend: 'up' | 'down' | 'stable';
  chartData?: Array<{ time: string; value: number }>;
}

interface MetricsViewProps {
  wsUrl?: string;
  pollInterval?: number;
}

const MetricsView: React.FC<MetricsViewProps> = ({
  wsUrl = getRuntimeConfig().wsUrl,
  pollInterval = 5000,
}) => {
  const [metrics, setMetrics] = useState<Metric[]>([]);
  const [selectedMetric, setSelectedMetric] = useState<Metric | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const { isConnected, subscribe, unsubscribe } = useWebSocket(wsUrl);

  const generateChartData = (currentValue: number, seed: number) => {
    const data: Array<{ time: string; value: number }> = [];
    for (let i = 10; i >= 0; i--) {
      const variance = (Math.sin(seed + i) + 1) * currentValue * 0.2;
      data.push({
        time: new Date(Date.now() - i * 1000).toLocaleTimeString(),
        value: Math.max(0, currentValue + variance),
      });
    }
    return data;
  };

  const updateMetric = (query: string, data: any, index: number): void => {
    const metricLabels = ['Request Rate', 'CPU Usage', 'Memory Available', 'Network Receive'];
    const metricTypes: Array<'cpu' | 'memory' | 'network' | 'latency' | 'requests'> = [
      'requests', 'cpu', 'memory', 'network',
    ];
    const metricUnits = ['req/s', '%', 'MB', 'MB/s'];

    let value = 0;
    if (data?.data?.result && Array.isArray(data.data.result) && data.data.result[0]) {
      const v = data.data.result[0].value;
      if (Array.isArray(v) && v.length > 1) value = parseFloat(v[1]);
    }

    const metric: Metric = {
      name: metricLabels[index] || `Metric ${index}`,
      value,
      unit: metricUnits[index] || '',
      type: metricTypes[index] || 'requests',
      trend: Math.random() > 0.5 ? 'up' : 'stable',
      chartData: generateChartData(value, index),
    };

    setMetrics((prev) => {
      const updated = [...prev];
      updated[index] = metric;
      return updated;
    });
  };

  useEffect(() => {
    let apiInterval: NodeJS.Timeout | null = null;

    const fetchMetricsFromApi = async () => {
      try {
        setLoading(true);
        const response = await fetch(buildApiUrl('/api/test-metrics'));
        if (!response.ok) throw new Error(`API returned ${response.status}`);
        const data = await response.json();

        const apiMetrics: Metric[] = [
          {
            name: 'Request Rate', value: data.metrics?.request_rate || 0, unit: 'req/s', type: 'requests', trend: 'stable',
            chartData: generateChartData(data.metrics?.request_rate || 0, 0),
          },
          {
            name: 'CPU Usage', value: data.metrics?.cpu_usage || 0, unit: '%', type: 'cpu', trend: 'stable',
            chartData: generateChartData(data.metrics?.cpu_usage || 0, 1),
          },
          {
            name: 'Memory Available', value: data.metrics?.memory_usage || 0, unit: 'MB', type: 'memory', trend: 'stable',
            chartData: generateChartData(data.metrics?.memory_usage || 0, 2),
          },
          {
            name: 'Network Latency', value: data.metrics?.network_latency || 0, unit: 'ms', type: 'latency', trend: 'stable',
            chartData: generateChartData(data.metrics?.network_latency || 0, 3),
          },
        ];

        setMetrics(apiMetrics);
        setError(null);
      } catch (err) {
        console.error('[MetricsView] API fetch error:', err);
        setError(err instanceof Error ? err.message : 'Failed to fetch metrics');
      } finally {
        setLoading(false);
      }
    };

    if (isConnected) {
      const queries = [
        'rate(http_requests_total[5m])',
        'avg(node_cpu_seconds_total)',
        'avg(node_memory_MemAvailable_bytes)',
        'avg(instance:node_network_receive_bytes_excluding_lo:rate1m)',
      ];

      queries.forEach((q, i) => subscribe(q, pollInterval, (d) => updateMetric(q, d, i)));

      return () => queries.forEach((q) => unsubscribe(q));
    }

    // fallback
    fetchMetricsFromApi();
    apiInterval = setInterval(fetchMetricsFromApi, pollInterval);
    return () => { if (apiInterval) clearInterval(apiInterval); };
  }, [isConnected, subscribe, unsubscribe, pollInterval]);

  if (loading && metrics.length === 0) return <div className="metrics-loading">Loading metrics...</div>;

  return (
    <div className="metrics-view">
      <div className="metrics-header">
        <h2>System Metrics</h2>
        <div className="metrics-status">
          <span className={`status-indicator ${isConnected ? 'connected' : 'disconnected'}`} />
          <span>{isConnected ? 'Connected (WebSocket)' : 'Connected (API Fallback)'}</span>
        </div>
      </div>

      {error && <div className="metrics-error">⚠️ {error}</div>}

      <div className="metrics-grid">
        {metrics.map((metric, idx) => (
          <div key={idx} className={`metric-card ${(selectedMetric === metric) ? 'selected' : ''}`} onClick={() => setSelectedMetric(metric)}>
            <div className="metric-header">
              <h3>{metric.name}</h3>
              <span className={`trend ${metric.trend}`}>{metric.trend === 'up' ? '↑' : metric.trend === 'down' ? '↓' : '→'}</span>
            </div>
            <div className="metric-value">{metric.value.toFixed(2)} <span className="unit">{metric.unit}</span></div>
            {metric.chartData && (
              <ResponsiveContainer width="100%" height={80}>
                <AreaChart data={metric.chartData}>
                  <Area type="monotone" dataKey="value" stroke="#3b82f6" fill="#3b82f6" isAnimationActive={false} />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </div>
        ))}
      </div>

      {selectedMetric?.chartData && (
        <div className="metrics-detail">
          <h3>{selectedMetric.name} - Detailed View</h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={selectedMetric.chartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis label={{ value: selectedMetric.unit, angle: -90, position: 'insideLeft' }} />
              <Tooltip />
              <Legend />
              <Line type="monotone" dataKey="value" stroke="#3b82f6" name={selectedMetric.name} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  );
};

export default MetricsView;
