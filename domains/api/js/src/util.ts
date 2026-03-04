import { getServiceInfo } from "@repo/common";

export const SERVICE_VERSION = "1.1.0";

export type HealthResponse = {
  ok: boolean;
  service: string;
  version: string;
  timestamp: string;
};

export function health(): HealthResponse {
  const info = getServiceInfo("api-js-service", SERVICE_VERSION);
  return {
    ok: true,
    service: info.name,
    version: info.version,
    timestamp: new Date().toISOString()
  };
}
