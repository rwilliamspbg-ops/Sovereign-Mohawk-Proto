import React from 'react';
import { A2UiAction, A2UiComponent, A2UiEnvelope } from '../types/protocol';

interface A2UIRendererProps {
  envelope: A2UiEnvelope | null;
  busyIntent?: string | null;
  onAction: (action: A2UiAction) => void;
}

function renderComponent(component: A2UiComponent) {
  if (component.kind === 'text') {
    return (
      <div className="a2ui-block a2ui-text">
        <h4>{String(component.props.title || 'Untitled')}</h4>
        <p>{String(component.props.body || '')}</p>
      </div>
    );
  }

  if (component.kind === 'metric') {
    return (
      <div className="a2ui-block a2ui-metric">
        <span className="a2ui-metric-label">{String(component.props.label || 'Metric')}</span>
        <strong className="a2ui-metric-value">{String(component.props.value || '-')}</strong>
      </div>
    );
  }

  if (component.kind === 'table') {
    const columns = (component.props.columns as string[]) || [];
    const rows = (component.props.rows as Record<string, unknown>[]) || [];

    return (
      <div className="a2ui-block a2ui-table-wrap">
        <table className="a2ui-table">
          <thead>
            <tr>
              {columns.map((column) => (
                <th key={column}>{column}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row, rowIndex) => (
              <tr key={`${component.id}-row-${rowIndex}`}>
                {columns.map((column) => (
                  <td key={`${component.id}-${rowIndex}-${column}`}>{String(row[column] ?? '-')}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  }

  return (
    <div className="a2ui-block">
      <p>Unsupported component kind: {component.kind}</p>
    </div>
  );
}

const A2UIRenderer: React.FC<A2UIRendererProps> = ({ envelope, busyIntent, onAction }) => {
  if (!envelope) {
    return null;
  }

  return (
    <section className="a2ui-surface" aria-label="Agent workflow surface">
      <div className="a2ui-layout">
        {envelope.layout.components.map((component) => (
          <div key={component.id}>{renderComponent(component)}</div>
        ))}
      </div>
      {envelope.actions && envelope.actions.length > 0 && (
        <div className="a2ui-actions">
          {envelope.actions.map((action) => (
            <button
              key={action.id}
              className="a2ui-action-button"
              disabled={busyIntent === action.intent}
              onClick={() => onAction(action)}
            >
              {busyIntent === action.intent ? 'Working...' : action.label}
            </button>
          ))}
        </div>
      )}
    </section>
  );
};

export default A2UIRenderer;
