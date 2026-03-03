export type HealthResponse = {
  ok: boolean;
  service: string;
  timestamp: string;
};

export function health(): HealthResponse {
  return {
    ok: true,
    service: "api-js-service",
    timestamp: new Date().toISOString()
  };
}
