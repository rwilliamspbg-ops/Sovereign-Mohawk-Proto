import React from 'react';
import ReactDOM from 'react-dom/client';
import { CopilotKit } from '@copilotkit/react-core';
import App from '../client/App';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <CopilotKit publicApiKey={import.meta.env.VITE_COPILOT_PUBLIC_API_KEY || ''}>
      <App />
    </CopilotKit>
  </React.StrictMode>
);
