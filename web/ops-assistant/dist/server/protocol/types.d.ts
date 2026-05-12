import { z } from 'zod';
export declare const AgUiEventKindSchema: z.ZodEnum<["agent.message.delta", "agent.message.final", "agent.tool.call.started", "agent.tool.call.completed", "agent.tool.call.failed", "agent.ui.patch", "agent.ui.replace", "agent.state.changed"]>;
export declare const AgUiEventSchema: z.ZodObject<{
    version: z.ZodString;
    eventId: z.ZodString;
    timestamp: z.ZodString;
    sessionId: z.ZodOptional<z.ZodString>;
    runId: z.ZodOptional<z.ZodString>;
    kind: z.ZodEnum<["agent.message.delta", "agent.message.final", "agent.tool.call.started", "agent.tool.call.completed", "agent.tool.call.failed", "agent.ui.patch", "agent.ui.replace", "agent.state.changed"]>;
    payload: z.ZodRecord<z.ZodString, z.ZodUnknown>;
    meta: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodUnion<[z.ZodString, z.ZodNumber, z.ZodBoolean, z.ZodNull]>>>;
}, "strip", z.ZodTypeAny, {
    version: string;
    eventId: string;
    timestamp: string;
    kind: "agent.message.delta" | "agent.message.final" | "agent.tool.call.started" | "agent.tool.call.completed" | "agent.tool.call.failed" | "agent.ui.patch" | "agent.ui.replace" | "agent.state.changed";
    payload: Record<string, unknown>;
    sessionId?: string | undefined;
    runId?: string | undefined;
    meta?: Record<string, string | number | boolean | null> | undefined;
}, {
    version: string;
    eventId: string;
    timestamp: string;
    kind: "agent.message.delta" | "agent.message.final" | "agent.tool.call.started" | "agent.tool.call.completed" | "agent.tool.call.failed" | "agent.ui.patch" | "agent.ui.replace" | "agent.state.changed";
    payload: Record<string, unknown>;
    sessionId?: string | undefined;
    runId?: string | undefined;
    meta?: Record<string, string | number | boolean | null> | undefined;
}>;
export declare const A2UiEnvelopeSchema: z.ZodObject<{
    version: z.ZodString;
    surface: z.ZodEnum<["main", "sidebar", "modal", "mcp-dock"]>;
    layout: z.ZodObject<{
        type: z.ZodEnum<["stack", "grid", "tabs"]>;
        components: z.ZodArray<z.ZodObject<{
            id: z.ZodString;
            kind: z.ZodEnum<["text", "metric", "table", "chart", "form", "timeline", "button"]>;
            props: z.ZodRecord<z.ZodString, z.ZodUnknown>;
        }, "strip", z.ZodTypeAny, {
            id: string;
            kind: "text" | "metric" | "table" | "chart" | "form" | "timeline" | "button";
            props: Record<string, unknown>;
        }, {
            id: string;
            kind: "text" | "metric" | "table" | "chart" | "form" | "timeline" | "button";
            props: Record<string, unknown>;
        }>, "many">;
    }, "strip", z.ZodTypeAny, {
        type: "stack" | "grid" | "tabs";
        components: {
            id: string;
            kind: "text" | "metric" | "table" | "chart" | "form" | "timeline" | "button";
            props: Record<string, unknown>;
        }[];
    }, {
        type: "stack" | "grid" | "tabs";
        components: {
            id: string;
            kind: "text" | "metric" | "table" | "chart" | "form" | "timeline" | "button";
            props: Record<string, unknown>;
        }[];
    }>;
    actions: z.ZodOptional<z.ZodArray<z.ZodObject<{
        id: z.ZodString;
        label: z.ZodString;
        intent: z.ZodString;
        confirm: z.ZodOptional<z.ZodBoolean>;
    }, "strip", z.ZodTypeAny, {
        id: string;
        label: string;
        intent: string;
        confirm?: boolean | undefined;
    }, {
        id: string;
        label: string;
        intent: string;
        confirm?: boolean | undefined;
    }>, "many">>;
}, "strip", z.ZodTypeAny, {
    version: string;
    surface: "main" | "sidebar" | "modal" | "mcp-dock";
    layout: {
        type: "stack" | "grid" | "tabs";
        components: {
            id: string;
            kind: "text" | "metric" | "table" | "chart" | "form" | "timeline" | "button";
            props: Record<string, unknown>;
        }[];
    };
    actions?: {
        id: string;
        label: string;
        intent: string;
        confirm?: boolean | undefined;
    }[] | undefined;
}, {
    version: string;
    surface: "main" | "sidebar" | "modal" | "mcp-dock";
    layout: {
        type: "stack" | "grid" | "tabs";
        components: {
            id: string;
            kind: "text" | "metric" | "table" | "chart" | "form" | "timeline" | "button";
            props: Record<string, unknown>;
        }[];
    };
    actions?: {
        id: string;
        label: string;
        intent: string;
        confirm?: boolean | undefined;
    }[] | undefined;
}>;
export type AgUiEvent = z.infer<typeof AgUiEventSchema>;
export type A2UiEnvelope = z.infer<typeof A2UiEnvelopeSchema>;
//# sourceMappingURL=types.d.ts.map