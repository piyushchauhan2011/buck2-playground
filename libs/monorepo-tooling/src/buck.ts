import { execSync } from "node:child_process";
import { stripConfig } from "./package-resolver.js";

export function buck2Uquery(query: string, repoRoot: string): string[] {
  const out = execSync(`buck2 uquery "${query}"`, {
    cwd: repoRoot,
    encoding: "utf-8",
  });
  return out
    .split("\n")
    .map((s) => stripConfig(s.trim()))
    .filter(Boolean);
}
