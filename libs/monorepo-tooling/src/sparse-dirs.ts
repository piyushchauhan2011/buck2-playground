import * as path from "node:path";
import { buck2Uquery } from "./buck.js";
import { gitChangedFiles, gitRevParseShowToplevel } from "./git.js";
import { nearestPackage } from "./package-resolver.js";

export interface SparseDirsOptions {
  baseRef?: string;
  headRef?: string;
  changedFiles?: string[];
  repoRoot?: string;
}

export function computeSparseDirs(options: SparseDirsOptions = {}): {
  sparseDirs: string[];
} {
  const repoRoot = options.repoRoot ?? gitRevParseShowToplevel();
  const baseRef = options.baseRef ?? "HEAD~1";
  const headRef = options.headRef ?? "HEAD";
  const changedFiles =
    options.changedFiles ?? gitChangedFiles(baseRef, repoRoot, headRef);

  if (changedFiles.length === 0) {
    return { sparseDirs: [] };
  }

  const packages = new Set<string>();
  for (const f of changedFiles) {
    const pkg = nearestPackage(f, repoRoot);
    if (pkg && pkg !== ".") packages.add(pkg);
  }
  const packageList = [...packages].sort();

  if (packageList.length === 0) {
    return { sparseDirs: [] };
  }

  let owning: string[] = [];
  for (const pkg of packageList) {
    const res = buck2Uquery(`kind('genrule|sh_test', //${pkg}/...)`, repoRoot);
    owning.push(...res);
  }
  owning = [...new Set(owning)].sort();

  if (owning.length === 0) {
    return { sparseDirs: [] };
  }

  const targetsSet = `set(${owning.join(" ")})`;
  const impacted = buck2Uquery(`rdeps(//..., ${targetsSet})`, repoRoot);
  if (impacted.length > 0) owning = impacted;

  const impactedSet = `set(${owning.join(" ")})`;
  const deps = buck2Uquery(`deps(${impactedSet})`, repoRoot);
  const allNeeded = [...new Set([...owning, ...deps])];

  const dirs = new Set<string>();
  for (const t of allNeeded) {
    if (t.startsWith("root//")) {
      const match = t.match(/^root\/\/?([^:]+)/);
      if (match) dirs.add(match[1]);
    }
  }

  return {
    sparseDirs: [...dirs].sort(),
  };
}
