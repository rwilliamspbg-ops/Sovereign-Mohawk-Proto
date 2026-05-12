export type AgUiEventKind =
  | 'agent.message.delta'
  | 'agent.message.final'
  | 'agent.tool.call.started'
  | 'agent.tool.call.completed'
  | 'agent.tool.call.failed'
  | 'agent.ui.patch'
  | 'agent.ui.replace'
  | 'agent.state.changed';

export interface A2UiComponent {
  id: string;
  kind: 'text' | 'metric' | 'table' | 'chart' | 'form' | 'timeline' | 'button';
  props: Record<string, unknown>;
}

export interface A2UiAction {
  id: string;
  label: string;
  intent: string;
  confirm?: boolean;
}

export interface A2UiEnvelope {
  version: string;
  surface: 'main' | 'sidebar' | 'modal' | 'mcp-dock';
  layout: {
    type: 'stack' | 'grid' | 'tabs';
    components: A2UiComponent[];
  };
  actions?: A2UiAction[];
}

export interface AgUiEvent {
  version: string;
  eventId: string;
  timestamp: string;
  sessionId?: string;
  runId?: string;
  kind: AgUiEventKind;
  payload: Record<string, unknown>;
  meta?: Record<string, string | number | boolean | null>;
}
