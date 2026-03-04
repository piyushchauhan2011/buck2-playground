import { describe, expect, it } from "vitest";
import { formatVersion, formatTimestamp } from "../src/format.js";

describe("formatVersion", () => {
  it("formats a semver string from parts", () => {
    expect(formatVersion(1, 2, 3)).toBe("1.2.3");
  });

  it("handles zero patch", () => {
    expect(formatVersion(2, 0, 0)).toBe("2.0.0");
  });
});

describe("formatTimestamp", () => {
  it("formats a given date as ISO string", () => {
    const d = new Date("2026-01-01T00:00:00.000Z");
    expect(formatTimestamp(d)).toBe("2026-01-01T00:00:00.000Z");
  });

  it("defaults to current date when no argument given", () => {
    const before = Date.now();
    const ts = formatTimestamp();
    const after = Date.now();
    const ms = new Date(ts).getTime();
    expect(ms).toBeGreaterThanOrEqual(before);
    expect(ms).toBeLessThanOrEqual(after);
  });
});
