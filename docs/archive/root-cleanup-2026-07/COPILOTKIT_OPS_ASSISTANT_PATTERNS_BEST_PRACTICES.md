# CopilotKit Operations Assistant - Architecture Patterns & Best Practices

**Advanced Design Patterns for Network Operations AI**  
**Created**: May 11, 2026  

---

## 🏗️ Architecture Patterns

### Pattern 1: Real-Time Subscription Model

**Problem**: Users need live metric updates without constant polling

**Solution**: WebSocket subscriptions + server-side streaming

```
Client                          Server
  |                              |
  |--- subscribe(metrics) ------>|
  |                              |
  |<---- metrics_update (1/s) ---|
  |<---- metrics_update (1/s) ---|
  |<---- metrics_update (1/s) ---|
  |                              |
  |--- unsubscribe(metrics) ---->|
```

**Implementation**:
```typescript
// Client
const subscribe = (metrics: string[]) => {
  ws.send(JSON.stringify({ type: 'subscribe', metrics }));
};

// Server
socket.on('subscribe', (metrics) => {
  client.subscriptions.add(...metrics);
  // Start streaming on next interval
});

setInterval(() => {
  for (const [id, client] of clients) {
    const data = {};
    client.subscriptions.forEach(m => {
      data[m] = prometheus.query(m);
    });
    client.ws.send(JSON.stringify(data));
  }
}, 1000);
```

---

### Pattern 2: Action Composition

**Problem**: Complex operations require chaining multiple actions

**Solution**: Action factory with dependency injection

```
User Input
    ↓
Query Router (ChatGPT)
    ↓
Action Map
    ├─ queryMetric
    ├─ analyzeTrend
    ├─ predictAnomaly
    └─ recommendAction
    ↓
Result Aggregation
    ↓
UI Rendering
```

**Implementation**:
```typescript
export class ActionFactory {
  constructor(
    private prometheus: PrometheusClient,
    private grafana: GrafanaClient,
    private ml: MLPredictor
  ) {}

  async executeChain(actions: ActionRequest[]): Promise<any> {
    let context = {};
    
    for (const action of actions) {
      const handler = this.getHandler(action.name);
      const result = await handler(action.params, context);
      context = { ...context, ...result };
    }
    
    return context;
  }

  private getHandler(name: string) {
    const handlers: Record<string, Function> = {
      'queryMetric': this.queryMetric.bind(this),
      'analyzeTrend': this.analyzeTrend.bind(this),
      'predictAnomaly': this.predictAnomaly.bind(this)
    };
    
    return handlers[name] || (() => ({}));
  }
}
```

---

### Pattern 3: Multi-Level Caching

**Problem**: Repeated queries hammer Prometheus

**Solution**: Multi-tier cache strategy

```
Request
    ↓
Memory Cache (hot queries, 5 min)
    ↓
Redis Cache (historic, 1 hour)
    ↓
Database (aggregates, 24 hours)
    ↓
Prometheus (live queries)
```

**Implementation**:
```typescript
export class CacheLayer {
  private memoryCache = new Map();
  private redis: RedisClient;

  async query(metric: string, timeRange: string): Promise<any> {
    const cacheKey = `${metric}:${timeRange}`;
    
    // L1: Memory
    if (this.memoryCache.has(cacheKey)) {
      return this.memoryCache.get(cacheKey);
    }
    
    // L2: Redis
    const redisData = await this.redis.get(cacheKey);
    if (redisData) {
      this.memoryCache.set(cacheKey, redisData);
      return redisData;
    }
    
    // L3: Prometheus
    const data = await prometheus.query(metric);
    this.memoryCache.set(cacheKey, data);
    await this.redis.setex(cacheKey, 3600, JSON.stringify(data));
    
    return data;
  }
}
```

---

### Pattern 4: Error Resilience

**Problem**: One failure cascades through the system

**Solution**: Circuit breaker + fallback patterns

```typescript
export class ResilientClient {
  private circuitBreaker = new CircuitBreaker({
    failureThreshold: 5,
    resetTimeout: 60000
  });

  async safeQuery(...args): Promise<any> {
    try {
      return await this.circuitBreaker.execute(() => 
        prometheus.query(...args)
      );
    } catch (error) {
      // Fallback: Return cached data
      return this.cache.get(args[0]) || { error: 'Service unavailable' };
    }
  }
}
```

---

### Pattern 5: Stream Processing

**Problem**: Real-time analysis of large metric streams

**Solution**: Event-driven stream processing

```typescript
export class MetricStream {
  private emitter = new EventEmitter();

  async startProcessing() {
    this.emitter.on('metric', (point) => {
      this.detectAnomaly(point);
      this.updateAggregate(point);
      this.checkAlerts(point);
    });
  }

  private detectAnomaly(point: MetricPoint) {
    const zScore = this.calculateZScore(point);
    if (Math.abs(zScore) > 3) {
      this.emitter.emit('anomaly', { point, zScore });
    }
  }

  async getAnomalies(): Promise<Anomaly[]> {
    return new Promise(resolve => {
      this.emitter.once('anomaly', resolve);
    });
  }
}
```

---

## 🎯 Best Practices

### 1. API Design

**✅ DO**: Use consistent naming and structure
```typescript
// Good
{
  status: 'success' | 'error',
  data: { ... },
  timestamp: ISO8601,
  executionTime: ms
}
```

**❌ DON'T**: Return inconsistent shapes
```typescript
// Bad
{
  result: { ... },
  error: null,
  time: unixTimestamp
}
```

---

### 2. Error Handling

**✅ DO**: Return user-friendly errors
```typescript
{
  status: 'error',
  code: 'METRIC_NOT_FOUND',
  message: 'The metric "foo_bar" does not exist',
  suggestion: 'Try querying "foo_baz" instead'
}
```

**❌ DON'T**: Expose system details
```typescript
{
  error: 'TypeError: Cannot read property of undefined at PrometheusClient.ts:42'
}
```

---

### 3. Performance

**✅ DO**: Paginate large results
```typescript
GET /api/dashboards?page=1&pageSize=20
{
  data: [...],
  pagination: { page: 1, total: 342, hasMore: true }
}
```

**❌ DON'T**: Return unbounded data
```typescript
GET /api/dashboards -> [Massive array...]
```

---

### 4. Real-time Communication

**✅ DO**: Use binary frames for efficiency
```typescript
// Binary data is 3-5x smaller than JSON
ws.send(compressedBinary(data));
```

**❌ DON'T**: Send everything as JSON
```typescript
// Large overhead for frequent updates
ws.send(JSON.stringify(data));
```

---

### 5. State Management

**✅ DO**: Use immutable updates
```typescript
const newMetrics = {
  ...metrics,
  [key]: newValue
};
setMetrics(newMetrics);
```

**❌ DON'T**: Mutate state directly
```typescript
metrics[key] = newValue;
setMetrics(metrics); // May not trigger update
```

---

### 6. Security

**✅ DO**: Validate all inputs
```typescript
const schema = z.object({
  query: z.string().min(1).max(1000),
  timeRange: z.enum(['5m', '1h', '24h'])
});
const validated = schema.parse(input);
```

**❌ DON'T**: Trust user input
```typescript
const result = await prometheus.query(userInput); // SQL injection!
```

---

### 7. Logging

**✅ DO**: Log with context
```typescript
logger.info('Query executed', {
  metric: query,
  timeRange: '5m',
  duration: 245,
  resultCount: 120,
  userId: user?.id
});
```

**❌ DON'T**: Generic logs without context
```typescript
console.log('Query done');
```

---

### 8. Testing

**✅ DO**: Mock external dependencies
```typescript
beforeEach(() => {
  const mockPrometheus = {
    query: jest.fn().mockResolvedValue({ data: [] })
  };
  service = new MetricsService(mockPrometheus);
});
```

**❌ DON'T**: Test against real services
```typescript
test('queries prometheus', async () => {
  const result = await realPrometheus.query('up');
  expect(result).toBeDefined();
});
```

---

## 🔐 Security Patterns

### Input Validation Pattern

```typescript
import { z } from 'zod';

const QuerySchema = z.object({
  query: z.string()
    .min(1, 'Query required')
    .max(2000, 'Query too long')
    .refine(q => !q.includes('system'), 'Invalid query term'),
  timeRange: z.enum(['5m', '15m', '1h', '6h', '24h', '7d']),
  limit: z.number().min(1).max(10000).default(1000)
});

export async function validateQuery(input: unknown) {
  return QuerySchema.parse(input);
}
```

### Rate Limiting Pattern

```typescript
class RateLimiter {
  private requests = new Map<string, number[]>();
  private limit = 100; // requests
  private window = 60000; // ms (1 minute)

  isAllowed(userId: string): boolean {
    const now = Date.now();
    const userRequests = this.requests.get(userId) || [];
    const recent = userRequests.filter(t => now - t < this.window);
    
    if (recent.length >= this.limit) return false;
    
    recent.push(now);
    this.requests.set(userId, recent);
    return true;
  }
}

app.use((req, res, next) => {
  if (!limiter.isAllowed(req.user.id)) {
    return res.status(429).json({ error: 'Too many requests' });
  }
  next();
});
```

### CORS Pattern

```typescript
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3001'],
  credentials: true,
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

---

## 📊 Performance Optimization Patterns

### Lazy Loading Pattern

```typescript
const DashboardView = React.lazy(() => 
  import('./components/DashboardView')
);

<Suspense fallback={<Spinner />}>
  <DashboardView />
</Suspense>
```

### Memoization Pattern

```typescript
const useMemoizedMetrics = (metrics: string[]) => {
  return useMemo(() => {
    return metrics
      .filter(m => m.length > 0)
      .map(m => normalizeMetric(m));
  }, [metrics]);
};
```

### Debouncing Pattern

```typescript
const useDebounce = (value: string, delay: number) => {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
};

// Usage
const searchTerm = useDebounce(inputValue, 300);
useEffect(() => {
  if (searchTerm) {
    searchDashboards(searchTerm);
  }
}, [searchTerm]);
```

---

## 🧪 Testing Patterns

### Action Testing

```typescript
describe('Actions', () => {
  let service: MetricsService;
  let mockPrometheus: jest.Mocked<PrometheusClient>;

  beforeEach(() => {
    mockPrometheus = {
      query: jest.fn(),
      rangeQuery: jest.fn()
    };
    service = new MetricsService(mockPrometheus);
  });

  it('should execute queryMetric action', async () => {
    mockPrometheus.query.mockResolvedValue({
      data: { result: [{ value: [0, '100'] }] }
    });

    const result = await service.queryMetric('up');
    
    expect(result).toBeDefined();
    expect(mockPrometheus.query).toHaveBeenCalledWith('up');
  });

  it('should handle prometheus errors gracefully', async () => {
    mockPrometheus.query.mockRejectedValue(new Error('Connection refused'));

    const result = await service.queryMetric('up');
    
    expect(result.error).toBeDefined();
    expect(result.status).toBe('error');
  });
});
```

### Component Testing

```typescript
describe('MetricsView', () => {
  it('should render metrics grid', () => {
    const metrics = { 'up': 1, 'cpu': 42 };
    const { getByText } = render(
      <MetricsView metrics={metrics} onSubscribe={jest.fn()} />
    );
    
    expect(getByText('up')).toBeInTheDocument();
    expect(getByText('42')).toBeInTheDocument();
  });

  it('should subscribe to metrics on mount', () => {
    const onSubscribe = jest.fn();
    render(<MetricsView metrics={{}} onSubscribe={onSubscribe} />);
    
    expect(onSubscribe).toHaveBeenCalled();
  });
});
```

---

## 📈 Scalability Patterns

### Load Balancing

```
User Requests
    ↓
Load Balancer (nginx)
    ├─ ops-assistant-1:3000
    ├─ ops-assistant-2:3000
    └─ ops-assistant-3:3000
    ↓
Shared Cache (Redis)
```

### Database Connection Pooling

```typescript
const pool = new Pool({
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000
});

pool.on('error', (err) => {
  console.error('Pool error:', err);
});
```

### Circuit Breaker for Cascading Failures

```typescript
const prometheusCircuit = new CircuitBreaker({
  failureThreshold: 5,
  successThreshold: 2,
  timeout: 6000,
  resetTimeout: 30000
});

try {
  return await prometheusCircuit.fire(() => 
    prometheus.query(metric)
  );
} catch (error) {
  logger.error('Circuit breaker open');
  return cache.get(metric);
}
```

---

## 🚀 Deployment Patterns

### Blue-Green Deployment

```bash
# Deploy new version (green)
docker run -d -p 3002:3000 ops-assistant:new

# Test
curl http://localhost:3002/api/health

# Switch traffic
nginx_config_update old->new

# Cleanup
docker stop ops-assistant:old
```

### Rolling Deployment

```
Time →  pod1    pod2    pod3    pod4
0s      v1      v1      v1      v1
5s      v2      v1      v1      v1
10s     v2      v2      v1      v1
15s     v2      v2      v2      v1
20s     v2      v2      v2      v2 ✓
```

---

## ✅ Quality Checklist

- [ ] All APIs documented with examples
- [ ] Error codes standardized
- [ ] All inputs validated with Zod
- [ ] Unit tests for all actions
- [ ] E2E tests for user workflows
- [ ] Performance benchmarks passing
- [ ] Security audit completed
- [ ] Logging comprehensive
- [ ] Alerts configured
- [ ] Runbooks documented
- [ ] Team trained
- [ ] Deployment procedure tested

---

**Status**: ✅ COMPLETE PATTERN LIBRARY  
**Updated**: May 11, 2026

