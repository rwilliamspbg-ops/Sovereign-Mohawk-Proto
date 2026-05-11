import React, { useState, useEffect } from 'react';

const HealthStatus: React.FC = () => {
  const [health, setHealth] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchHealth = async () => {
      try {
        const response = await fetch('/api/health');
        const data = await response.json();
        setHealth(data);
      } catch (error) {
        console.error('Failed to fetch health status:', error);
        setHealth({ status: 'error', error: 'Failed to connect' });
      } finally {
        setLoading(false);
      }
    };

    fetchHealth();
    const interval = setInterval(fetchHealth, 30000); // Refresh every 30s

    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return <div style={{ color: '#999' }}>Loading health status...</div>;
  }

  const isHealthy = health?.status === 'healthy';
  const statusColor = isHealthy ? '#22c55e' : '#ef4444';
  const statusLabel = isHealthy ? 'Healthy' : 'Degraded';

  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
        fontSize: '14px'
      }}
    >
      <div
        style={{
          width: '12px',
          height: '12px',
          borderRadius: '50%',
          backgroundColor: statusColor
        }}
      />
      <span>
        <strong>System Status:</strong> {statusLabel}
      </span>
      <span style={{ color: '#666', marginLeft: 'auto' }}>
        Prometheus: {health?.prometheus ? '✓ Connected' : '✗ Disconnected'}
      </span>
    </div>
  );
};

export default HealthStatus;
