export const SERVICE_VERSION = "1.1.0";

export type HealthResponse = {
  ok: boolean;
  service: string;
  version: string;
  timestamp: string;
};

export function health(): HealthResponse {
  return {
    ok: true,
    service: "api-js-service",
    version: SERVICE_VERSION,
    timestamp: new Date().toISOString()
  };
}
