export type ServiceInfo = {
  name: string;
  version: string;
  env: string;
};

export function getServiceInfo(name: string, version: string): ServiceInfo {
  return {
    name,
    version,
    env: process.env["NODE_ENV"] ?? "development",
  };
}
