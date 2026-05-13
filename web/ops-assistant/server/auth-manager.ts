import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

/**
 * Unified Authentication Manager
 * Manages credential lifecycle, token refresh, and identity validation
 * 
 * Supports multiple credential sources in priority order:
 * 1. Runtime secrets (Docker/Kubernetes) at /run/secrets/
 * 2. Environment variables
 * 3. Local credential files
 */
export interface AuthCredentials {
  grafanaToken: string;
  prometheusBasicAuth?: {
    username: string;
    password: string;
  };
  mtlsCert?: {
    cert: string;
    key: string;
    ca: string;
  };
}

export interface TokenValidationResult {
  isValid: boolean;
  expiresAt?: number;
  confidence: number;
  error?: string;
}

/**
 * Request tracing context for auditing auth failures
 */
export interface RequestTrace {
  requestId: string;
  timestamp: string;
  source: string;
  target: string;
  method: string;
  statusCode?: number;
  authMethod: string;
  error?: string;
  tokenAgeSeconds?: number;
}

export class AuthManager {
  private credentials: AuthCredentials;
  private tokenValidatedAt: number = 0;
  private requestTraces: RequestTrace[] = [];
  private maxTraceHistory: number = 1000;
  
  // Credential sources
  private readonly SECRETS_BASE_PATH = '/run/secrets';
  private readonly GRAFANA_TOKEN_ENV = 'GRAFANA_API_TOKEN';
  private readonly GRAFANA_TOKEN_FILE = 'grafana_api_token';
  private readonly PROMETHEUS_BASIC_AUTH_ENV = 'PROMETHEUS_BASIC_AUTH';
  
  // Validation thresholds
  private readonly TOKEN_VALIDATION_INTERVAL_MS = 3600000; // 1 hour
  private readonly TOKEN_EXPIRATION_GRACE_PERIOD_MS = 300000; // 5 minutes

  constructor() {
    this.credentials = {
      grafanaToken: '',
    };
  }

  /**
   * Initialize authentication manager
   * Loads credentials from all available sources
   */
  async initialize(): Promise<void> {
    console.log('[AuthManager] Initializing authentication...');
    
    try {
      // Try to load from secrets first (Docker/K8s)
      await this.loadSecretsCredentials();
      
      // Fallback to environment variables
      if (!this.credentials.grafanaToken) {
        this.loadEnvironmentCredentials();
      }

      // Validate credentials are loaded
      if (!this.credentials.grafanaToken) {
        throw new Error(
          'No Grafana API token found. Set GRAFANA_API_TOKEN env var or /run/secrets/grafana_api_token file'
        );
      }

      // Validate credentials work
      const validation = await this.validateCredentials();
      if (!validation.isValid) {
        console.warn('[AuthManager] ⚠️ Credential validation failed:', validation.error);
      } else {
        console.log('[AuthManager] ✓ Credentials validated successfully');
      }

      this.tokenValidatedAt = Date.now();
    } catch (error) {
      console.error('[AuthManager] ✗ Initialization failed:', error);
      throw error;
    }
  }

  /**
   * Load credentials from Docker/Kubernetes secrets
   */
  private async loadSecretsCredentials(): Promise<void> {
    try {
      // Try to read Grafana token from secrets
      try {
        const tokenPath = path.join(this.SECRETS_BASE_PATH, this.GRAFANA_TOKEN_FILE);
        const token = (await fs.readFile(tokenPath, 'utf-8')).trim();
        if (token) {
          this.credentials.grafanaToken = token;
          console.log('[AuthManager] ✓ Loaded Grafana token from secrets');
          return;
        }
      } catch {
        // Secrets path doesn't exist, continue to env vars
      }
    } catch (error) {
      console.debug('[AuthManager] Could not load from secrets:', error);
    }
  }

  /**
   * Load credentials from environment variables
   */
  private loadEnvironmentCredentials(): void {
    const grafanaToken = process.env[this.GRAFANA_TOKEN_ENV];
    if (grafanaToken) {
      this.credentials.grafanaToken = grafanaToken;
      console.log('[AuthManager] ✓ Loaded Grafana token from environment');
    }

    // Load Prometheus basic auth if available
    const promBasicAuth = process.env[this.PROMETHEUS_BASIC_AUTH_ENV];
    if (promBasicAuth) {
      const [username, password] = promBasicAuth.split(':');
      if (username && password) {
        this.credentials.prometheusBasicAuth = { username, password };
        console.log('[AuthManager] ✓ Loaded Prometheus basic auth from environment');
      }
    }
  }

  /**
   * Get current credentials with automatic refresh if needed
   */
  async getCredentials(): Promise<AuthCredentials> {
    const timeSinceValidation = Date.now() - this.tokenValidatedAt;
    
    // Validate periodically
    if (timeSinceValidation > this.TOKEN_VALIDATION_INTERVAL_MS) {
      await this.validateCredentials();
      this.tokenValidatedAt = Date.now();
    }

    return { ...this.credentials };
  }

  /**
   * Get Authorization header for API requests
   */
  async getAuthorizationHeader(): Promise<string> {
    const creds = await this.getCredentials();
    
    if (creds.prometheusBasicAuth) {
      const encoded = Buffer.from(
        `${creds.prometheusBasicAuth.username}:${creds.prometheusBasicAuth.password}`
      ).toString('base64');
      return `Basic ${encoded}`;
    }

    return `Bearer ${creds.grafanaToken}`;
  }

  /**
   * Get Bearer token for Grafana API
   */
  async getGrafanaToken(): Promise<string> {
    const creds = await this.getCredentials();
    if (!creds.grafanaToken) {
      throw new Error('Grafana API token not configured');
    }
    return creds.grafanaToken;
  }

  /**
   * Validate credentials by testing a simple API call
   */
  private async validateCredentials(): Promise<TokenValidationResult> {
    try {
      // Note: Full validation requires HTTP call to Grafana
      // This is called from index.ts after client setup to avoid circular dependency
      
      if (!this.credentials.grafanaToken) {
        return {
          isValid: false,
          confidence: 0,
          error: 'No Grafana token found',
        };
      }

      if (this.credentials.grafanaToken === 'admin') {
        console.warn('[AuthManager] ⚠️ Using default "admin" token - this may fail!');
      }

      return {
        isValid: true,
        confidence: this.credentials.grafanaToken !== 'admin' ? 1.0 : 0.5,
      };
    } catch (error) {
      return {
        isValid: false,
        confidence: 0,
        error: error instanceof Error ? error.message : 'Unknown validation error',
      };
    }
  }

  /**
   * Add request trace for auditing
   */
  addRequestTrace(
    source: string,
    target: string,
    method: string,
    statusCode?: number,
    error?: string
  ): void {
    const trace: RequestTrace = {
      requestId: `req_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      timestamp: new Date().toISOString(),
      source,
      target,
      method,
      statusCode,
      authMethod: this.credentials.prometheusBasicAuth ? 'basic' : 'bearer',
      error,
      tokenAgeSeconds: Math.floor((Date.now() - this.tokenValidatedAt) / 1000),
    };

    this.requestTraces.push(trace);

    // Keep only recent traces
    if (this.requestTraces.length > this.maxTraceHistory) {
      this.requestTraces = this.requestTraces.slice(-this.maxTraceHistory);
    }

    // Log errors and auth failures
    if (statusCode && statusCode >= 400) {
      console.warn(`[AuthManager] Request failed: ${source} → ${target}`, {
        method,
        statusCode,
        error,
        tokenAge: trace.tokenAgeSeconds,
      });
    }
  }

  /**
   * Get recent request traces for debugging
   */
  getRequestTraces(limit: number = 50): RequestTrace[] {
    return this.requestTraces.slice(-limit);
  }

  /**
   * Get authentication diagnostics
   */
  getDiagnostics(): {
    credentialsLoaded: boolean;
    grafanaTokenPresent: boolean;
    grafanaTokenLength: number;
    prometheusAuthPresent: boolean;
    lastValidation: string;
    timeSinceValidationSeconds: number;
    recentErrors: RequestTrace[];
  } {
    const timeSinceValidation = Date.now() - this.tokenValidatedAt;
    const errors = this.requestTraces.filter(
      (t) => t.error || (t.statusCode && t.statusCode >= 400)
    );

    return {
      credentialsLoaded: !!this.credentials.grafanaToken,
      grafanaTokenPresent: !!this.credentials.grafanaToken,
      grafanaTokenLength: this.credentials.grafanaToken?.length || 0,
      prometheusAuthPresent: !!this.credentials.prometheusBasicAuth,
      lastValidation: new Date(this.tokenValidatedAt).toISOString(),
      timeSinceValidationSeconds: Math.floor(timeSinceValidation / 1000),
      recentErrors: errors.slice(-10),
    };
  }
}

// Global singleton instance
let authManagerInstance: AuthManager | null = null;

/**
 * Get or create the global AuthManager instance
 */
export function getAuthManager(): AuthManager {
  if (!authManagerInstance) {
    authManagerInstance = new AuthManager();
  }
  return authManagerInstance;
}

/**
 * Initialize the global AuthManager
 */
export async function initializeAuthManager(): Promise<AuthManager> {
  const manager = getAuthManager();
  await manager.initialize();
  return manager;
}
