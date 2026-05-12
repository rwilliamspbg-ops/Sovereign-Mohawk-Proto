import React, { useEffect, useState } from 'react';
import { LineChart, Line, AreaChart, Area, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { useWebSocket } from '../hooks/useWebSocket';
import { getRuntimeConfig } from '../config';
import '../styles/metrics.css';

/**
 * Real-time Metrics View Component
 * Displays live metric data with interactive charts and widgets
 */

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

  /**
   * Initialize metrics
   */
  useEffect(() => {
    if (!isConnected) return;

    setLoading(true);
    setError(null);

    // Subscribe to various metric queries
    const queries = [
      'rate(http_requests_total[5m])',
      'avg(node_cpu_seconds_total)',
      'avg(node_memory_MemAvailable_bytes)',
      'avg(instance:node_network_receive_bytes_excluding_lo:rate1m)',
    ];

    queries.forEach((query, index) => {
      subscribe(query, pollInterval, (data) => {
        updateMetric(query, data, index);
        setLoading(false);
      });
    });

    return () => {
      queries.forEach((query) => unsubscribe(query));
    };
  }, [isConnected, subscribe, unsubscribe, pollInterval]);

  /**
   * Update metric state
   */
  const updateMetric = (
    query: string,
    data: any,
    index: number
  ): void => {
    const metricLabels = [
      'Request Rate',
      'CPU Usage',
      'Memory Available',
      'Network Receive',
    ];
    const metricTypes: Array<'cpu' | 'memory' | 'network' | 'latency' | 'requests'> = [
      'requests',
      'cpu',
      'memory',
      'network',
    ];
    const metricUnits = ['req/s', '%', 'MB', 'MB/s'];

    let value = 0;
    if (
      data.data &&
      data.data.result &&
      data.data.result[0]?.value
    ) {
      value = parseFloat(data.data.result[0].value[1]);
    }

    const metric: Metric = {
      name: metricLabels[index],
      value,
      unit: metricUnits[index],
      type: metricTypes[index],
      trend: Math.random() > 0.5 ? 'up' : 'stable',
      chartData: generateChartData(value, index),
    };

    setMetrics((prev) => {
      const updated = [...prev];
      updated[index] = metric;
      return updated;
    });
  };

  /**
   * Generate mock chart data
   */
  const generateChartData = (
    currentValue: number,
    seed: number
  ): Array<{ time: string; value: number }> => {
    const data = [];
    for (let i = 10; i >= 0; i--) {
      const variance = (Math.sin(seed + i) + 1) * currentValue * 0.2;
      data.push({
        time: new Date(Date.now() - i * 1000).toLocaleTimeString(),
        value: currentValue + variance,
      });
    }
    return data;
  };

  if (loading && metrics.length === 0) {
    return <div className="metrics-loading">Loading metrics...</div>;
  }

  return (
    <div className="metrics-view">
      <div className="metrics-header">
        <h2>System Metrics</h2>
        <div className="metrics-status">
          <span className={`status-indicator ${isConnected ? 'connected' : 'disconnected'}`}></span>
          <span>{isConnected ? 'Connected' : 'Disconnected'}</span>
        </div>
      </div>

      <div className="metrics-grid">
        {metrics.map((metric, idx) => (
          <div
            key={idx}
            className={`metric-card ${selectedMetric === metric ? 'selected' : ''}`}
            onClick={() => setSelectedMetric(metric)}
          >
            <div className="metric-header">
              <h3>{metric.name}</h3>
              <span className={`trend ${metric.trend}`}>
                {metric.trend === 'up' ? '↑' : metric.trend === 'down' ? '↓' : '→'}
              </span>
            </div>
            <div className="metric-value">
              {metric.value.toFixed(2)} <span className="unit">{metric.unit}</span>
            </div>
            {metric.chartData && (
              <ResponsiveContainer width="100%" height={80}>
                <AreaChart data={metric.chartData}>
                  <Area
                    type="monotone"
                    dataKey="value"
                    stroke="#3b82f6"
                    fill="#3b82f6"
                    isAnimationActive={false}
                  />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </div>
        ))}
      </div>

      {selectedMetric && selectedMetric.chartData && (
        <div className="metrics-detail">
          <h3>{selectedMetric.name} - Detailed View</h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={selectedMetric.chartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis label={{ value: selectedMetric.unit, angle: -90, position: 'insideLeft' }} />
              <Tooltip />
              <Legend />
              <Line
                type="monotone"
                dataKey="value"
                stroke="#3b82f6"
                name={selectedMetric.name}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>
      )}

      {error && <div className="metrics-error">{error}</div>}
    </div>
  );
};

export default MetricsView;
