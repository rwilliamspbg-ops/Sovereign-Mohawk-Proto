import { describe, it, expect } from 'vitest';
import { computeDriftScoreFromContributors, detectAnomalyHeuristics, FLContributor, RoundSnapshot } from '../federated-intelligence';

describe('Federated intelligence utilities', () => {
  it('computeDriftScoreFromContributors returns 0 for uniform contributors', () => {
    const contributors: FLContributor[] = [
      { nodeId: 'a', tier: 'tier-1', region: 'r', objective: 'o', contributionScore: 0.5, verificationWeight: 0.5, attestationStatus: 'verified', reasoning: '' },
      { nodeId: 'b', tier: 'tier-1', region: 'r', objective: 'o', contributionScore: 0.5, verificationWeight: 0.5, attestationStatus: 'verified', reasoning: '' },
      { nodeId: 'c', tier: 'tier-1', region: 'r', objective: 'o', contributionScore: 0.5, verificationWeight: 0.5, attestationStatus: 'verified', reasoning: '' },
    ];

    const score = computeDriftScoreFromContributors(contributors);
    expect(score).toBeGreaterThanOrEqual(0);
    expect(score).toBeLessThanOrEqual(1);
    expect(score).toBeCloseTo(0, 6);
  });

  it('detectAnomalyHeuristics flags z-score outliers and low verification/high contribution', () => {
    const snapshot: RoundSnapshot = {
      status: {
        roundId: 'r1', phase: 'local_training', progress: 50, modelConfidence: 0.7, driftScore: 0.0,
        convergenceTrend: 'stable', participatingNodes: 3, honestNodeRatio: 0.9, attestationThreshold: 0.8,
        rdpBudgetRemaining: 0.5, updatedAt: new Date().toISOString(), reasoning: ''
      },
      contributors: [
        { nodeId: 'good', tier: 'tier-1', region: 'r', objective: 'o', contributionScore: 0.5, verificationWeight: 0.6, attestationStatus: 'verified', reasoning: '' },
        { nodeId: 'weird', tier: 'tier-2', region: 'r', objective: 'o', contributionScore: 0.99, verificationWeight: 0.2, attestationStatus: 'partial', reasoning: '' },
        { nodeId: 'ok', tier: 'tier-3', region: 'r', objective: 'o', contributionScore: 0.45, verificationWeight: 0.5, attestationStatus: 'verified', reasoning: '' },
      ],
      anomalies: [],
    };

    const anomalies = detectAnomalyHeuristics(snapshot);
    // should flag 'weird' at least once (poisoning or drift)
    const ids = anomalies.map((a) => a.nodeId);
    expect(ids).toContain('weird');
    // global anomaly unlikely here
    expect(ids).not.toContain('round-global');
  });
});
