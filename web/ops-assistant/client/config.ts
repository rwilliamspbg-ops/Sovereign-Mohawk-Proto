export interface RuntimeConfig {
  apiBaseUrl: string;
  wsUrl: string;
}

function normalizeBaseUrl(value: string | undefined): string {
  if (!value) return '';
  return value.replace(/\/$/, '');
}

function getDefaultApiBaseUrl(): string {
  if (typeof window === 'undefined') {
    return 'http://localhost:3000';
  }

  // In browser deployments, relative API paths follow the current origin.
  return window.location.origin;
}

function toWebSocketUrl(apiBaseUrl: string): string {
  const base = apiBaseUrl || getDefaultApiBaseUrl();

  try {
    const url = new URL(base);
    url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
    url.pathname = '/';
    return url.toString().replace(/\/$/, '');
  } catch {
    return 'ws://localhost:3000';
  }
}

export function getRuntimeConfig(): RuntimeConfig {
  const configuredApi = normalizeBaseUrl(import.meta.env.VITE_API_BASE_URL);
  const apiBaseUrl = configuredApi || getDefaultApiBaseUrl();

  const configuredWs = normalizeBaseUrl(import.meta.env.VITE_WS_URL);
  const wsUrl = configuredWs || toWebSocketUrl(apiBaseUrl);

  return {
    apiBaseUrl,
    wsUrl,
  };
}

export function buildApiUrl(path: string): string {
  const { apiBaseUrl } = getRuntimeConfig();
  return `${apiBaseUrl}${path.startsWith('/') ? path : `/${path}`}`;
}
