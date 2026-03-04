import { formatVersion } from "@repo/utils";

export type ServiceInfo = {
  name: string;
  version: string;
  env: string;
};

export function getServiceInfo(name: string, version: string): ServiceInfo {
  const [major = 0, minor = 0, patch = 0] = version.split(".").map(Number);
  return {
    name,
    version: formatVersion(major, minor, patch),
    env: process.env["NODE_ENV"] ?? "development",
  };
}
