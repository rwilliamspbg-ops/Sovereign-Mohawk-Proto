import { Request, Response } from 'express';
import { queryPrometheus, queryPrometheusRange, parseRelativeTime, KEY_METRICS } from './prometheus-client';

export async function handleQueryPrometheus(req: Request, res: Response) {
  try {
    const { query, rangeMinutes } = req.body;

    if (!query) {
      return res.status(400).json({ error: 'query parameter is required' });
    }

    if (rangeMinutes) {
      const now = Math.floor(Date.now() / 1000);
      const start = now - rangeMinutes * 60;
      const step = Math.max(60, rangeMinutes * 60 / 100); // Aim for ~100 points

      const result = await queryPrometheusRange(query, start, now, `${Math.round(step)}s`);
      return res.json(result);
    } else {
      const result = await queryPrometheus(query);
      return res.json(result);
    }
  } catch (error) {
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
}

export async function handleIncidentSummary(req: Request, res: Response) {
  try {
    const { startTime = '30m ago', endTime = 'now' } = req.body;

    const startTs = typeof startTime === 'string' ? parseRelativeTime(startTime) : startTime;
    const endTs = typeof endTime === 'string' ? parseRelativeTime(endTime) : endTime;

    // Query key metrics over the time range
    const queries = Object.entries(KEY_METRICS).map(([name, expr]) =>
      queryPrometheusRange(expr, startTs, endTs, '60s')
        .then(result => ({ [name]: result }))
        .catch(err => ({ [name]: { error: err.message } }))
    );

    const results = await Promise.all(queries);
    const metricsData = Object.assign({}, ...results);

    // Analyze the data
    const summary = analyzeMetrics(metricsData);

    res.json({
      timeRange: {
        start: new Date(startTs * 1000).toISOString(),
        end: new Date(endTs * 1000).toISOString()
      },
      summary
    });
  } catch (error) {
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
}

function analyzeMetrics(metricsData: Record<string, any>) {
  const issues: string[] = [];
  const successes: string[] = [];

  // Check throughput
  if (metricsData.throughput?.data?.result?.length) {
    const values = metricsData.throughput.data.result[0]?.values || [];
    if (values.length > 0) {
      const recent = parseFloat(values[values.length - 1][1]);
      if (recent > 100) {
        successes.push(`High gradient throughput: ${recent.toFixed(2)} ops/sec`);
      } else if (recent === 0) {
        issues.push('No gradient submissions detected');
      }
    }
  }

  // Check failures
  if (metricsData.failures?.data?.result?.length) {
    const values = metricsData.failures.data.result[0]?.values || [];
    if (values.length > 0) {
      const recent = parseFloat(values[values.length - 1][1]);
      if (recent > 0.1) {
        issues.push(`High failure rate: ${(recent * 100).toFixed(1)}%`);
      }
    }
  }

  // Check Byzantine filters
  if (metricsData.byzantineRejects?.data?.result?.length) {
    const values = metricsData.byzantineRejects.data.result[0]?.values || [];
    if (values.length > 0) {
      const recent = parseFloat(values[values.length - 1][1]);
      if (recent > 5) {
        issues.push(`Byzantine attacks detected: ${recent.toFixed(0)} rejections in last 5m`);
      }
    }
  }

  // Check latency
  if (metricsData.roundLatencyP95?.data?.result?.length) {
    const values = metricsData.roundLatencyP95.data.result[0]?.values || [];
    if (values.length > 0) {
      const recent = parseFloat(values[values.length - 1][1]);
      if (recent > 5000) {
        issues.push(`High round latency p95: ${recent.toFixed(0)}ms`);
      }
    }
  }

  if (issues.length === 0 && successes.length < 2) {
    issues.push('No significant activity detected');
  }

  return {
    status: issues.length > 0 ? 'anomalies_detected' : 'healthy',
    issues,
    successes,
    recommendations: generateRecommendations(issues)
  };
}

function generateRecommendations(issues: string[]): string[] {
  const recommendations: string[] = [];

  if (issues.some(i => i.includes('No gradient submissions'))) {
    recommendations.push('Check if orchestrator is running and FL aggregator is accepting clients');
  }

  if (issues.some(i => i.includes('High failure rate'))) {
    recommendations.push('Review recent logs for gradient submission errors or network issues');
  }

  if (issues.some(i => i.includes('Byzantine attacks'))) {
    recommendations.push('Review Byzantine filtering logs and correlation matrix scores');
  }

  if (issues.some(i => i.includes('High round latency'))) {
    recommendations.push('Check node-agent and aggregator resource usage; consider scaling up');
  }

  return recommendations;
}

export async function handleExplainDashboard(req: Request, res: Response) {
  try {
    const { dashboardName } = req.body;

    if (!dashboardName) {
      return res.status(400).json({ error: 'dashboardName is required' });
    }

    // Dashboard explanations (can be expanded with actual dashboard metadata)
    const explanations: Record<string, any> = {
      'v2-00-start-here': {
        title: 'Start Here',
        description: 'Landing page and navigation hub for all operational dashboards',
        keyMetrics: ['operational_status', 'alert_summary']
      },
      'v2-10-ops-overview': {
        title: 'Operations Overview',
        description: 'System health trends, gradient throughput, proof verification rates, and accelerator operation counts',
        keyMetrics: [
          'grade_submit:rate1m',
          'proof_verifications:rate1m',
          'accelerator_ops:rate1m'
        ]
      },
      'v2-11-ops-incidents': {
        title: 'Incidents & Triage',
        description: 'Failure rates, Byzantine filter rejections, and latency anomalies for incident investigation',
        keyMetrics: [
          'failure_rate_5m',
          'byzantine_filtered_total',
          'round_latency_quantile_ms'
        ]
      },
      'v2-13-ops-router-command-center': {
        title: 'Router Command Center',
        description: 'Federated router forensics, request counts, response distributions, and command center operations',
        keyMetrics: [
          'router_requests_total',
          'router_request_duration_ms',
          'command_center_operations'
        ]
      },
      'v2-14-ops-mrc-transport': {
        title: 'MRC Transport Health',
        description: 'MRC transport path health, gradient throughput, accelerator proxy telemetry, and Byzantine filtering',
        keyMetrics: [
          'gradient_submit:rate1m',
          'proof_verifications:rate1m',
          'accelerator_ops:rate1m',
          'byzantine_filtered_total'
        ]
      }
    };

    const explanation = explanations[dashboardName] || {
      title: dashboardName,
      description: 'Custom dashboard',
      keyMetrics: ['see Grafana dashboard for detailed panel list']
    };

    res.json(explanation);
  } catch (error) {
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
}
