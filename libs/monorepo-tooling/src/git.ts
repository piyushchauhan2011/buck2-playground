import { execSync } from "node:child_process";

export function gitChangedFiles(
  baseRef: string,
  repoRoot: string,
  headRef: string = "HEAD"
): string[] {
  const out = execSync(`git diff --name-only ${baseRef}...${headRef}`, {
    cwd: repoRoot,
    encoding: "utf-8",
  });
  return out
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);
}

export function gitCatFileExists(path: string, repoRoot: string): boolean {
  try {
    execSync(`git cat-file -e HEAD:${path}`, {
      cwd: repoRoot,
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    });
    return true;
  } catch {
    return false;
  }
}

export function gitRevParseShowToplevel(cwd: string = process.cwd()): string {
  try {
    return execSync("git rev-parse --show-toplevel", {
      cwd,
      encoding: "utf-8",
    }).trim();
  } catch {
    return cwd;
  }
}
