import axios from 'axios';
import client from 'prom-client';

const PROMETHEUS_URL = process.env.PROMETHEUS_URL || 'http://prometheus:9090';

function getFederationApiUrl(): string {
  return process.env.FEDERATION_API_URL || 'http://federation-api:8080';
}

function getFederationApiTimeoutMs(): number {
  const parsed = Number(process.env.FEDERATION_API_TIMEOUT_MS || '1000');
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 1000;
}

export type FLRoundPhase =
  | 'initialization'
  | 'client_selection'
  | 'distribution'
  | 'local_training'
  | 'submission'
  | 'aggregation'
  | 'validation'
  | 'convergence'
  | 'failure'
  | 'rollback';

export interface FLContributor {
  nodeId: string;
  tier: 'tier-1' | 'tier-2' | 'tier-3' | 'unknown';
  region: string;
  objective: string;
  contributionScore: number;
  verificationWeight: number;
  attestationStatus: 'verified' | 'partial' | 'unverified';
  reasoning: string;
}

export interface FLAnomaly {
  nodeId: string;
  category: 'drift' | 'poisoning' | 'byzantine' | 'attestation' | 'latency';
  severity: 'low' | 'medium' | 'high';
  score: number;
  evidence: string;
  recommendation: string;
}

export interface FLRoundStatus {
  roundId: string;
  phase: FLRoundPhase;
  progress: number;
  modelConfidence: number;
  driftScore: number;
  convergenceTrend: 'improving' | 'stable' | 'degrading';
  participatingNodes: number;
  honestNodeRatio: number;
  attestationThreshold: number;
  rdpBudgetRemaining: number;
  updatedAt: string;
  reasoning: string;
}

export interface FLIntelligenceScoreboard extends FLRoundStatus {
  topContributors: FLContributor[];
  anomalies: FLAnomaly[];
  recommendedAction: string;
  requiresConfirmation: boolean;
  supportingEvidence: string[];
}

export interface RoundSnapshot {
  status: FLRoundStatus;
  contributors: FLContributor[];
  anomalies: FLAnomaly[];
}

const DEFAULT_ROUND: RoundSnapshot = {
  status: {
    roundId: 'round-unknown',
    phase: 'initialization',
    progress: 8,
    modelConfidence: 0.61,
    driftScore: 0.12,
    convergenceTrend: 'stable',
    participatingNodes: 128,
    honestNodeRatio: 0.94,
    attestationThreshold: 0.9,
    rdpBudgetRemaining: 0.72,
    updatedAt: new Date().toISOString(),
    reasoning: 'Fallback round state derived from local assistant heuristics.',
  },
  contributors: [
    {
      nodeId: 'edge-alpha-01',
      tier: 'tier-1',
      region: 'Region Alpha',
      objective: 'Objective Z',
      contributionScore: 0.91,
      verificationWeight: 0.84,
      attestationStatus: 'verified',
      reasoning: 'Strong update consistency and verified attestation.',
    },
    {
      nodeId: 'edge-beta-12',
      tier: 'tier-2',
      region: 'Region Beta',
      objective: 'Objective Z',
      contributionScore: 0.73,
      verificationWeight: 0.61,
      attestationStatus: 'partial',
      reasoning: 'Moderate contribution with partial verification confidence.',
    },
    {
      nodeId: 'edge-gamma-22',
      tier: 'tier-3',
      region: 'Region Gamma',
      objective: 'Objective Y',
      contributionScore: 0.48,
      verificationWeight: 0.37,
      attestationStatus: 'unverified',
      reasoning: 'Low trust and higher variance compared with the round baseline.',
    },
  ],
  anomalies: [
    {
      nodeId: 'edge-gamma-22',
      category: 'drift',
      severity: 'medium',
      score: 0.67,
      evidence: 'Gradient variance exceeded the round median by 2.4 standard deviations.',
      recommendation: 'Increase verification weight and review the node cohort before aggregation.',
    },
  ],
};

function clampScore(value: number): number {
  return Math.max(0, Math.min(1, value));
}

function nowIso(): string {
  return new Date().toISOString();
}

async function fetchFederationSnapshot(): Promise<RoundSnapshot | null> {
  try {
    const FEDERATION_API_URL = getFederationApiUrl();
    const response = await axios.get(`${FEDERATION_API_URL}/api/v1/round/current`, {
      timeout: getFederationApiTimeoutMs(),
    });

    const payload = response.data?.data ?? response.data;
    if (!payload || typeof payload !== 'object') {
      return null;
    }

    return {
      status: {
        roundId: String(payload.roundId || DEFAULT_ROUND.status.roundId),
        phase: (payload.phase as FLRoundPhase) || DEFAULT_ROUND.status.phase,
        progress: clampScore(Number(payload.progress ?? DEFAULT_ROUND.status.progress / 100)) * 100,
        modelConfidence: clampScore(Number(payload.modelConfidence ?? DEFAULT_ROUND.status.modelConfidence)),
        driftScore: clampScore(Number(payload.driftScore ?? DEFAULT_ROUND.status.driftScore)),
        convergenceTrend:
          (payload.convergenceTrend as FLRoundStatus['convergenceTrend']) || DEFAULT_ROUND.status.convergenceTrend,
        participatingNodes: Number(payload.participatingNodes ?? DEFAULT_ROUND.status.participatingNodes),
        honestNodeRatio: clampScore(Number(payload.honestNodeRatio ?? DEFAULT_ROUND.status.honestNodeRatio)),
        attestationThreshold: clampScore(Number(payload.attestationThreshold ?? DEFAULT_ROUND.status.attestationThreshold)),
        rdpBudgetRemaining: clampScore(Number(payload.rdpBudgetRemaining ?? DEFAULT_ROUND.status.rdpBudgetRemaining)),
        updatedAt: typeof payload.updatedAt === 'string' ? payload.updatedAt : nowIso(),
        reasoning:
          typeof payload.reasoning === 'string'
            ? payload.reasoning
            : 'Round state provided by the federation control plane.',
      },
      contributors: Array.isArray(payload.contributors)
        ? payload.contributors.map((contributor: Record<string, unknown>) => ({
            nodeId: String(contributor.nodeId ?? contributor.id ?? 'unknown-node'),
            tier: (contributor.tier as FLContributor['tier']) || 'unknown',
            region: String(contributor.region ?? 'unknown'),
            objective: String(contributor.objective ?? 'unknown'),
            contributionScore: clampScore(Number(contributor.contributionScore ?? 0)),
            verificationWeight: clampScore(Number(contributor.verificationWeight ?? 0)),
            attestationStatus:
              (contributor.attestationStatus as FLContributor['attestationStatus']) || 'unverified',
            reasoning: String(contributor.reasoning ?? 'Fed control plane contribution summary.'),
          }))
        : DEFAULT_ROUND.contributors,
      anomalies: Array.isArray(payload.anomalies)
        ? payload.anomalies.map((anomaly: Record<string, unknown>) => ({
            nodeId: String(anomaly.nodeId ?? anomaly.id ?? 'unknown-node'),
            category: (anomaly.category as FLAnomaly['category']) || 'drift',
            severity: (anomaly.severity as FLAnomaly['severity']) || 'low',
            score: clampScore(Number(anomaly.score ?? 0)),
            evidence: String(anomaly.evidence ?? 'Federation control plane reported an anomaly.'),
            recommendation: String(anomaly.recommendation ?? 'Review node behavior.'),
          }))
        : DEFAULT_ROUND.anomalies,
    };
  } catch {
    return null;
  }
}

function mergeSnapshot(snapshot: RoundSnapshot | null): RoundSnapshot {
  return snapshot ?? DEFAULT_ROUND;
}

function buildReasoningTrail(status: FLRoundStatus, contributors: FLContributor[], anomalies: FLAnomaly[]): string[] {
  const topContributor = contributors[0];
  const driftSummary = anomalies[0];

  return [
    `Round ${status.roundId} is in ${status.phase} with ${status.progress.toFixed(0)}% completion.`,
    topContributor
      ? `Top contribution is from ${topContributor.nodeId} in ${topContributor.region} for ${topContributor.objective}.`
      : 'No contribution ranking is currently available.',
    driftSummary
      ? `Primary anomaly is ${driftSummary.category} on ${driftSummary.nodeId} with ${driftSummary.severity} severity.`
      : 'No material anomalies are currently detected.',
  ];
}

export class FederatedLearningStateMachine {
  private snapshot: RoundSnapshot = DEFAULT_ROUND;

  getSnapshot(): RoundSnapshot {
    return this.snapshot;
  }

  setSnapshot(snapshot: RoundSnapshot): void {
    this.snapshot = snapshot;
  }

  async refresh(): Promise<RoundSnapshot> {
    const latest = mergeSnapshot(await fetchFederationSnapshot());
    this.snapshot = latest;
    // update metrics on refresh
    try {
      federatedDriftGauge.set(latest.status.driftScore ?? computeDriftScoreFromContributors(latest.contributors));
      federatedRoundGauge.set({ phase: latest.status.phase }, latest.status.progress ?? 0);
    } catch (e) {
      // ignore metric errors
    }
    return latest;
  }
}

export const federatedLearningStateMachine = new FederatedLearningStateMachine();

export async function getRoundStatus(): Promise<FLRoundStatus> {
  const snapshot = await federatedLearningStateMachine.refresh();
  return snapshot.status;
}

export async function listContributingNodes(): Promise<FLContributor[]> {
  const snapshot = await federatedLearningStateMachine.refresh();
  return [...snapshot.contributors].sort((left, right) => right.contributionScore - left.contributionScore);
}

export async function detectAnomalies(): Promise<FLAnomaly[]> {
  const snapshot = await federatedLearningStateMachine.refresh();
  return [...snapshot.anomalies].sort((left, right) => right.score - left.score);
}

/**
 * Compute a drift score (0..1) from contributor contribution scores.
 * Uses coefficient of variation (stddev / mean) clipped to [0,1].
 */
export function computeDriftScoreFromContributors(contributors: FLContributor[]): number {
  if (!contributors || contributors.length === 0) return 0;
  const vals = contributors.map((c) => Number.isFinite(c.contributionScore) ? c.contributionScore : 0);
  const mean = vals.reduce((s, v) => s + v, 0) / vals.length;
  if (mean === 0) return 0;
  const variance = vals.reduce((s, v) => s + (v - mean) * (v - mean), 0) / vals.length;
  const std = Math.sqrt(variance);
  const cov = std / Math.abs(mean);
  // Normalize: assume cov of 1 -> high drift (1.0), cov 0 -> 0. Clip.
  return clampScore(cov);
}

/**
 * Simple anomaly heuristic scanning contributors and round status.
 * Returns detected anomalies with scoring and recommendations.
 */
export function detectAnomalyHeuristics(snapshot: RoundSnapshot): FLAnomaly[] {
  const anomalies: FLAnomaly[] = [];
  if (!snapshot) return anomalies;

  const contributors = snapshot.contributors || [];
  const scores = contributors.map((c) => c.contributionScore);
  const mean = scores.length ? scores.reduce((s, v) => s + v, 0) / scores.length : 0;
  const std = scores.length ? Math.sqrt(scores.reduce((s, v) => s + (v - mean) * (v - mean), 0) / scores.length) : 0;

  // Flag contributors with unusually high variance or mismatch between contribution and verification
  contributors.forEach((c) => {
    const z = std === 0 ? 0 : Math.abs((c.contributionScore - mean) / std);
    if (z > 2.0) {
      anomalies.push({
        nodeId: c.nodeId,
        category: 'drift',
        severity: z > 3 ? 'high' : 'medium',
        score: clampScore(Math.min(1, z / 5)),
        evidence: `Contribution score z=${z.toFixed(2)} (mean=${mean.toFixed(2)}, std=${std.toFixed(2)})`,
        recommendation: 'Isolate node and increase verification weight; consider rolling back its update.',
      });
    }

    // Low verification weight but high contribution -> potential poisoning
    if (c.contributionScore > 0.7 && c.verificationWeight < 0.4) {
      anomalies.push({
        nodeId: c.nodeId,
        category: 'poisoning',
        severity: 'medium',
        score: clampScore((c.contributionScore - c.verificationWeight)),
        evidence: `High contribution (${c.contributionScore.toFixed(2)}) with low verification weight (${c.verificationWeight.toFixed(2)})`,
        recommendation: 'Temporarily exclude from aggregation and perform deeper validation.',
      });
    }
  });

  // Global checks: if modelConfidence drops while driftScore is high
  const status = snapshot.status;
  if (status) {
    const drift = status.driftScore ?? computeDriftScoreFromContributors(contributors);
    const confidence = status.modelConfidence ?? 0;
    if (drift > 0.5 && confidence < 0.6) {
      anomalies.push({
        nodeId: 'round-global',
        category: 'attestation',
        severity: 'high',
        score: clampScore(drift * (1 - confidence)),
        evidence: `High drift ${drift.toFixed(2)} with falling confidence ${confidence.toFixed(2)}`,
        recommendation: 'Pause aggregation and trigger manual review of recent contributors and attestation logs.',
      });
    }
  }

  // De-duplicate by nodeId keeping highest-severity (score)
  const byId = new Map<string, FLAnomaly>();
  anomalies.forEach((a) => {
    const existing = byId.get(a.nodeId);
    if (!existing || a.score > existing.score) byId.set(a.nodeId, a);
  });

  return Array.from(byId.values()).sort((l, r) => r.score - l.score);
}

export async function explainModelDrift(): Promise<{
  objective: string;
  driftScore: number;
  confidenceDelta: number;
  affectedNodes: string[];
  reasoning: string;
  recommendation: string;
}> {
  const snapshot = await federatedLearningStateMachine.refresh();
  const primaryAnomaly = snapshot.anomalies[0];
  const confidenceDelta = clampScore(snapshot.status.modelConfidence - (snapshot.status.driftScore / 2));

  return {
    objective: snapshot.contributors[0]?.objective || 'Objective Z',
    driftScore: snapshot.status.driftScore,
    confidenceDelta,
    affectedNodes: snapshot.anomalies.map((anomaly) => anomaly.nodeId),
    reasoning: primaryAnomaly
      ? primaryAnomaly.evidence
      : 'Model drift remains within the current operating envelope.',
    recommendation: primaryAnomaly
      ? primaryAnomaly.recommendation
      : 'Maintain current verification settings and continue monitoring.',
  };
}

export async function getIntelligenceScoreboard(): Promise<FLIntelligenceScoreboard> {
  const snapshot = await federatedLearningStateMachine.refresh();
  const topContributors = [...snapshot.contributors].sort(
    (left, right) => right.contributionScore - left.contributionScore
  );
  const anomalies = [...snapshot.anomalies].sort((left, right) => right.score - left.score);

  return {
    ...snapshot.status,
    topContributors,
    anomalies,
    recommendedAction: anomalies.length > 0
      ? 'Increase verification weight for the affected cohort before aggregation.'
      : 'Proceed with aggregation and continue monitoring contribution quality.',
    requiresConfirmation: anomalies.some((anomaly) => anomaly.severity === 'high'),
    supportingEvidence: buildReasoningTrail(snapshot.status, topContributors, anomalies),
  };
}

export async function getFederatedOverview(): Promise<FLIntelligenceScoreboard> {
  const scoreboard = await getIntelligenceScoreboard();
  const prometheusResponse = await axios
    .get(`${PROMETHEUS_URL}/-/healthy`, { timeout: 3000 })
    .then(() => 'Prometheus healthy')
    .catch(() => 'Prometheus unavailable');

  return {
    ...scoreboard,
    supportingEvidence: [...scoreboard.supportingEvidence, prometheusResponse],
  };
}

// Prometheus metrics
const register = new client.Registry();
client.collectDefaultMetrics({ register });

export const federatedDriftGauge = new client.Gauge({
  name: 'sov_mohawk_federated_drift_score',
  help: 'Federated drift score (0..1)',
  registers: [register],
});

export const federatedRoundGauge = new client.Gauge({
  name: 'sov_mohawk_federated_round_progress',
  help: 'Federated round progress percent',
  labelNames: ['phase'],
  registers: [register],
});

export const anomaliesCounter = new client.Counter({
  name: 'sov_mohawk_federated_anomalies_total',
  help: 'Total federated anomalies detected',
  labelNames: ['category', 'severity'],
  registers: [register],
});

export function getMetrics(): Promise<string> {
  return register.metrics();
}