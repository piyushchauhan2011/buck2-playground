import * as path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, it, expect } from "vitest";
import {
  stripConfig,
  nearestPackage,
  targetToPackage,
  classifyTarget,
} from "../src/package-resolver.js";

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");

describe("stripConfig", () => {
  it("strips Buck2 config suffix", () => {
    expect(
      stripConfig("root//domains/api:target (prelude//platforms:default#abc123)")
    ).toBe("root//domains/api:target");
  });

  it("returns unchanged if no suffix", () => {
    expect(stripConfig("root//domains/api:target")).toBe("root//domains/api:target");
  });
});

describe("nearestPackage", () => {
  it("finds package when BUCK exists in parent", () => {
    const result = nearestPackage("libs/utils/src/format.ts", REPO_ROOT);
    expect(result).toBe("libs/utils");
  });

  it("finds libs/monorepo-tooling for files in this package", () => {
    const result = nearestPackage("libs/monorepo-tooling/src/cli.ts", REPO_ROOT);
    expect(result).toBe("libs/monorepo-tooling");
  });
});

describe("targetToPackage", () => {
  it("extracts package from root// path", () => {
    expect(targetToPackage("root//domains/api/js:api_js")).toBe("domains/api/js");
  });

  it("extracts package from // path", () => {
    expect(targetToPackage("//domains/api:target")).toBe("domains/api");
  });

  it("returns null for invalid target", () => {
    expect(targetToPackage("invalid")).toBeNull();
  });
});

describe("classifyTarget", () => {
  it("classifies php when composer.json exists", () => {
    expect(
      classifyTarget("root//domains/api/php:api", REPO_ROOT, (p) =>
        p === "domains/api/php/composer.json"
      )
    ).toBe("php");
  });

  it("classifies node when package.json exists via catFile", () => {
    expect(
      classifyTarget("root//domains/api/js:api", REPO_ROOT, (p) =>
        p === "domains/api/js/package.json"
      )
    ).toBe("node");
  });

  it("classifies other when no manifest", () => {
    expect(
      classifyTarget("root//unknown:pkg", REPO_ROOT, () => false)
    ).toBe("other");
  });
});
