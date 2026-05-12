import { describe, it, expect } from 'vitest';
import createMockFederation from '../mock-federation';
import { getIntelligenceScoreboard } from '../federated-intelligence';
describe('Federated integration (mock)', () => {
    it('fetches scoreboard from mock federation', async () => {
        const mockPayload = {
            roundId: 'round-123',
            phase: 'aggregation',
            progress: 42,
            modelConfidence: 0.8,
            driftScore: 0.2,
            convergenceTrend: 'stable',
            participatingNodes: 5,
            honestNodeRatio: 0.95,
            attestationThreshold: 0.9,
            rdpBudgetRemaining: 0.6,
            updatedAt: new Date().toISOString(),
            reasoning: 'mocked round',
            contributors: [
                { nodeId: 'n1', tier: 'tier-1', region: 'r', objective: 'o', contributionScore: 0.9, verificationWeight: 0.9, attestationStatus: 'verified', reasoning: '' },
                { nodeId: 'n2', tier: 'tier-2', region: 'r', objective: 'o', contributionScore: 0.4, verificationWeight: 0.5, attestationStatus: 'partial', reasoning: '' },
            ],
            anomalies: [],
        };
        const mock = await createMockFederation({ ...mockPayload, contributors: mockPayload.contributors, anomalies: mockPayload.anomalies });
        try {
            process.env.FEDERATION_API_URL = mock.url;
            const scoreboard = await getIntelligenceScoreboard();
            expect(scoreboard).toBeDefined();
            expect(scoreboard.roundId).toBe('round-123');
            expect(Array.isArray(scoreboard.topContributors)).toBe(true);
            expect(scoreboard.topContributors.length).toBeGreaterThan(0);
        }
        finally {
            await mock.close();
        }
    });
});
//# sourceMappingURL=fl.integration.test.js.map