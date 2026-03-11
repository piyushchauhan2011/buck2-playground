#!/usr/bin/env node
/**
 * Monorepo tooling CLI — sparse-dirs, affected-targets, profile-targets.
 * Outputs shell-export format for drop-in replacement with bash scripts.
 *
 * Usage:
 *   monorepo-tooling sparse-dirs [BASE_REF]
 *   monorepo-tooling affected-targets [BASE_REF]
 *   monorepo-tooling profile-targets <PROFILE>
 */
import * as path from "node:path";
import { computeAffectedTargets } from "./affected-targets.js";
import { computeSparseDirs } from "./sparse-dirs.js";
import { computeProfileTargets } from "./profile-targets.js";
import { gitRevParseShowToplevel } from "./git.js";

function toShellExports(result: ReturnType<typeof computeAffectedTargets>): void {
  const join = (arr: string[]) => arr.join(" ");

  console.log(`export BUILD_TARGETS='${join(result.build)}'`);
  console.log(`export TEST_TARGETS='${join(result.test)}'`);
  console.log(`export QUALITY_TARGETS='${join(result.quality)}'`);
  console.log(`export BUILD_NODE='${join(result.byLanguage.build.node)}'`);
  console.log(`export BUILD_PYTHON='${join(result.byLanguage.build.python)}'`);
  console.log(`export BUILD_PHP='${join(result.byLanguage.build.php)}'`);
  console.log(`export BUILD_OTHER='${join(result.byLanguage.build.other)}'`);
  console.log(`export TEST_NODE='${join(result.byLanguage.test.node)}'`);
  console.log(`export TEST_PYTHON='${join(result.byLanguage.test.python)}'`);
  console.log(`export TEST_PHP='${join(result.byLanguage.test.php)}'`);
  console.log(`export TEST_OTHER='${join(result.byLanguage.test.other)}'`);
  console.log(`export QUALITY_NODE='${join(result.byLanguage.quality.node)}'`);
  console.log(`export QUALITY_PYTHON='${join(result.byLanguage.quality.python)}'`);
  console.log(`export QUALITY_PHP='${join(result.byLanguage.quality.php)}'`);
  console.log(`export QUALITY_OTHER='${join(result.byLanguage.quality.other)}'`);
  console.log(`export NEEDS_NODE='${result.needsNode}'`);
  console.log(`export NEEDS_PYTHON='${result.needsPython}'`);
  console.log(`export NEEDS_PHP='${result.needsPhp}'`);
}

function main(): void {
  const args = process.argv.slice(2);
  const cmd = args[0];
  const repoRoot = gitRevParseShowToplevel();

  if (cmd === "sparse-dirs") {
    const baseRef = args[1] ?? "HEAD~1";
    const headRef = args[2] ?? "HEAD";
    const result = computeSparseDirs({ baseRef, headRef, repoRoot });
    console.log(`export SPARSE_DIRS='${result.sparseDirs.join(" ")}'`);
    return;
  }

  if (cmd === "affected-targets") {
    const baseRef = args[1] ?? "HEAD~1";
    const headRef = args[2] ?? "HEAD";
    const result = computeAffectedTargets({ baseRef, headRef, repoRoot });
    toShellExports(result);
    return;
  }

  if (cmd === "profile-targets") {
    const profile = args[1];
    if (!profile) {
      console.error("Usage: monorepo-tooling profile-targets <PROFILE>");
      process.exit(1);
    }
    const result = computeProfileTargets({ profile, repoRoot });
    toShellExports(result);
    return;
  }

  console.error(`Unknown command: ${cmd}`);
  console.error("Usage: monorepo-tooling sparse-dirs|affected-targets|profile-targets [args]");
  process.exit(1);
}

main();
