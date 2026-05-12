import { z } from 'zod';
export const AgUiEventKindSchema = z.enum([
    'agent.message.delta',
    'agent.message.final',
    'agent.tool.call.started',
    'agent.tool.call.completed',
    'agent.tool.call.failed',
    'agent.ui.patch',
    'agent.ui.replace',
    'agent.state.changed',
]);
export const AgUiEventSchema = z.object({
    version: z.string().regex(/^1\.[0-9]+$/),
    eventId: z.string(),
    timestamp: z.string().datetime(),
    sessionId: z.string().optional(),
    runId: z.string().optional(),
    kind: AgUiEventKindSchema,
    payload: z.record(z.unknown()),
    meta: z.record(z.union([z.string(), z.number(), z.boolean(), z.null()])).optional(),
});
const A2UiComponentSchema = z.object({
    id: z.string(),
    kind: z.enum(['text', 'metric', 'table', 'chart', 'form', 'timeline', 'button']),
    props: z.record(z.unknown()),
});
const A2UiActionSchema = z.object({
    id: z.string(),
    label: z.string(),
    intent: z.string(),
    confirm: z.boolean().optional(),
});
export const A2UiEnvelopeSchema = z.object({
    version: z.string().regex(/^1\.[0-9]+$/),
    surface: z.enum(['main', 'sidebar', 'modal', 'mcp-dock']),
    layout: z.object({
        type: z.enum(['stack', 'grid', 'tabs']),
        components: z.array(A2UiComponentSchema),
    }),
    actions: z.array(A2UiActionSchema).optional(),
});
//# sourceMappingURL=types.js.map