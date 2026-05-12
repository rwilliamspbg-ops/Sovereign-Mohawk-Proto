import client from 'prom-client';
export type FLRoundPhase = 'initialization' | 'client_selection' | 'distribution' | 'local_training' | 'submission' | 'aggregation' | 'validation' | 'convergence' | 'failure' | 'rollback';
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
export declare class FederatedLearningStateMachine {
    private snapshot;
    getSnapshot(): RoundSnapshot;
    setSnapshot(snapshot: RoundSnapshot): void;
    refresh(): Promise<RoundSnapshot>;
}
export declare const federatedLearningStateMachine: FederatedLearningStateMachine;
export declare function getRoundStatus(): Promise<FLRoundStatus>;
export declare function listContributingNodes(): Promise<FLContributor[]>;
export declare function detectAnomalies(): Promise<FLAnomaly[]>;
/**
 * Compute a drift score (0..1) from contributor contribution scores.
 * Uses coefficient of variation (stddev / mean) clipped to [0,1].
 */
export declare function computeDriftScoreFromContributors(contributors: FLContributor[]): number;
/**
 * Simple anomaly heuristic scanning contributors and round status.
 * Returns detected anomalies with scoring and recommendations.
 */
export declare function detectAnomalyHeuristics(snapshot: RoundSnapshot): FLAnomaly[];
export declare function explainModelDrift(): Promise<{
    objective: string;
    driftScore: number;
    confidenceDelta: number;
    affectedNodes: string[];
    reasoning: string;
    recommendation: string;
}>;
export declare function getIntelligenceScoreboard(): Promise<FLIntelligenceScoreboard>;
export declare function getFederatedOverview(): Promise<FLIntelligenceScoreboard>;
export declare const federatedDriftGauge: client.Gauge<string>;
export declare const federatedRoundGauge: client.Gauge<"phase">;
export declare const anomaliesCounter: client.Counter<"category" | "severity">;
export declare function getMetrics(): Promise<string>;
//# sourceMappingURL=federated-intelligence.d.ts.map