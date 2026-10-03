import React from 'react';
import ReactDOM from 'react-dom/client';
import { CopilotKit } from '@copilotkit/react-core';
import App from '../client/App';
import './index.css';

/**
 * <CopilotKit> throws during its own render when given neither `runtimeUrl` nor
 * a `publicApiKey`/`publicLicenseKey`:
 *
 *   Error: Missing required prop: 'runtimeUrl' or 'publicApiKey' or
 *          'publicLicenseKey'
 *
 * That throw used to produce a completely blank page in an unconfigured
 * deployment: <App/> calls useCopilotAction() three times and renders
 * <CopilotChat/>, so both the provider and the whole app depend on this prop
 * being satisfiable.
 *
 * This deployment is self-hosted -- it serves its own agent surface at
 * /api/agent/events (SSE) and /api/agent/intent and exposes no CopilotKit
 * runtime endpoint -- so a CopilotKit Cloud key is the only thing that can
 * satisfy the provider, and it is optional.
 *
 * When neither is configured we render the app WITHOUT the provider and tell it
 * so via <App chatEnabled={false}/>, which skips the CopilotKit hooks and shows
 * a "not configured" panel in the chat tab. Metrics and dashboards keep
 * working, which is the whole point.
 *
 * To enable chat, set either at BUILD time (Vite inlines these; see
 * web/ops-assistant/Dockerfile and docker-compose.yml):
 *   VITE_COPILOT_PUBLIC_API_KEY   -- CopilotKit Cloud public key
 *   VITE_COPILOT_RUNTIME_URL      -- self-hosted CopilotKit runtime base URL
 */
const copilotApiKey = import.meta.env.VITE_COPILOT_PUBLIC_API_KEY?.trim() ?? '';
const copilotRuntimeUrl = import.meta.env.VITE_COPILOT_RUNTIME_URL?.trim() ?? '';
const chatEnabled = Boolean(copilotApiKey || copilotRuntimeUrl);

const root = ReactDOM.createRoot(document.getElementById('root')!);

root.render(
  <React.StrictMode>
    {chatEnabled ? (
      <CopilotKit
        publicApiKey={copilotApiKey || undefined}
        runtimeUrl={copilotRuntimeUrl || undefined}
      >
        <App chatEnabled />
      </CopilotKit>
    ) : (
      <App chatEnabled={false} />
    )}
  </React.StrictMode>
);
