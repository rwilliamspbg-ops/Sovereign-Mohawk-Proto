import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { GrafanaClient } from '../grafana-client.js';

describe('GrafanaClient', () => {
  const originalEnvToken = process.env.GRAFANA_API_TOKEN;

  beforeEach(() => {
    delete process.env.GRAFANA_API_TOKEN;
  });

  afterEach(() => {
    if (originalEnvToken !== undefined) {
      process.env.GRAFANA_API_TOKEN = originalEnvToken;
    } else {
      delete process.env.GRAFANA_API_TOKEN;
    }
  });

  it('should default token to empty string when no token is provided and env var is unset', () => {
    const client = new GrafanaClient('http://grafana:3000');
    expect((client as any).apiToken).toBe('');
    expect((client as any).apiToken).not.toBe('admin');
  });

  it('should use explicit apiToken parameter when provided', () => {
    const client = new GrafanaClient('http://grafana:3000', 'custom-token-123');
    expect((client as any).apiToken).toBe('custom-token-123');
  });

  it('should use GRAFANA_API_TOKEN environment variable when available', () => {
    process.env.GRAFANA_API_TOKEN = 'env-token-456';
    const client = new GrafanaClient('http://grafana:3000');
    expect((client as any).apiToken).toBe('env-token-456');
  });
});
