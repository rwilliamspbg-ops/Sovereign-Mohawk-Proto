import { describe, it, expect, vi, beforeEach } from 'vitest';
import axios from 'axios';
import { analyzePerformanceAction } from '../actions.js';

describe('analyzePerformanceAction', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('queries metrics for the component and returns results', async () => {
    vi.spyOn(axios, 'get').mockImplementation(async (_url: string, _config?: any) => {
      return {
        data: {
          data: {
            result: [{ metric: { job: 'test-service' }, value: [1234567890, '0.5'] }],
          },
        },
      };
    });

    const result = await analyzePerformanceAction.handler({ component: 'test-service' });

    expect(result.success).toBe(true);
    expect(result.component).toBe('test-service');
    expect(result.metrics).toBeDefined();
    expect(result.metrics['rate']).toBeDefined();
    expect(result.metrics['node_memory_MemAvailable_bytes{job="test-service"}']).toBeDefined();
  });

  it('handles partial failures gracefully without dropping other metrics', async () => {
    vi.spyOn(axios, 'get').mockImplementation(async (_url: string, config?: any) => {
      const query = config?.params?.query || '';
      if (query.includes('node_memory_MemAvailable_bytes')) {
        throw new Error('Prometheus query timeout');
      }
      return {
        data: {
          data: {
            result: [{ metric: { job: 'test-service' }, value: [1234567890, '1'] }],
          },
        },
      };
    });

    const result = await analyzePerformanceAction.handler({ component: 'test-service' });

    expect(result.success).toBe(true);
    expect(result.component).toBe('test-service');
    expect(result.metrics['rate']).toBeDefined();
    expect(result.metrics['node_memory_MemAvailable_bytes{job="test-service"}']).toBeUndefined();
  });

  it('executes requests concurrently under latency simulation', async () => {
    const delayMs = 50;
    vi.spyOn(axios, 'get').mockImplementation(async () => {
      await new Promise((resolve) => setTimeout(resolve, delayMs));
      return {
        data: {
          data: {
            result: [{ value: [1, '1'] }],
          },
        },
      };
    });

    const startTime = Date.now();
    await analyzePerformanceAction.handler({ component: 'test-service' });
    const duration = Date.now() - startTime;

    console.log(`[Optimized Concurrent Execution] Duration: ${duration}ms`);
    // 4 queries * 50ms delay = 200ms sequentially, but ~50ms concurrently.
    expect(duration).toBeLessThan(120);
  });
});
