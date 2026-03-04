import { describe, expect, it } from "vitest";
import { getServiceInfo } from "../src/service-info.js";

describe("getServiceInfo", () => {
  it("returns the given name and version", () => {
    const info = getServiceInfo("my-service", "1.2.3");
    expect(info.name).toBe("my-service");
    expect(info.version).toBe("1.2.3");
  });

  it("defaults env to development when NODE_ENV is unset", () => {
    delete process.env["NODE_ENV"];
    const info = getServiceInfo("svc", "0.1.0");
    expect(info.env).toBe("development");
  });

  it("reflects NODE_ENV when set", () => {
    process.env["NODE_ENV"] = "production";
    const info = getServiceInfo("svc", "0.1.0");
    expect(info.env).toBe("production");
    delete process.env["NODE_ENV"];
  });
});
