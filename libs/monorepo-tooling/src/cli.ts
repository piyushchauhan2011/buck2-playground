#!/usr/bin/env node
/**
 * Monorepo tooling CLI — sparse-dirs, affected-targets, profile-targets,
 * run-affected, sparse-checkout.
 *
 * Usage:
 *   monorepo-tooling sparse-dirs [BASE_REF] [HEAD_REF]
 *   monorepo-tooling affected-targets [BASE_REF] [HEAD_REF]
 *   monorepo-tooling profile-targets <PROFILE>
 *   monorepo-tooling run-affected [BASE_REF]
 *   monorepo-tooling sparse-checkout list
 *   monorepo-tooling sparse-checkout apply <PROFILE>
 *   monorepo-tooling sparse-checkout new-clone <PROFILE> <REPO_URL>
 */
import { execSync } from "node:child_process";
import { computeAffectedTargets } from "./affected-targets.js";
import { computeSparseDirs } from "./sparse-dirs.js";
import { computeProfileTargets } from "./profile-targets.js";
import { applyProfile, listProfiles, newClone } from "./sparse-checkout.js";
import { gitRevParseShowToplevel } from "./git.js";

function toShellExports(
  result: ReturnType<typeof computeAffectedTargets>,
): void {
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
  console.log(
    `export QUALITY_PYTHON='${join(result.byLanguage.quality.python)}'`,
  );
  console.log(`export QUALITY_PHP='${join(result.byLanguage.quality.php)}'`);
  console.log(
    `export QUALITY_OTHER='${join(result.byLanguage.quality.other)}'`,
  );
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

  if (cmd === "run-affected") {
    const baseRef = args[1] ?? "HEAD~1";
    const headRef = args[2] ?? "HEAD";
    const result = computeAffectedTargets({ baseRef, headRef, repoRoot });
    const build = result.build.join(" ");
    const test = result.test.join(" ");
    const quality = result.quality.join(" ");

    if (!build && !test && !quality) {
      console.log("Fallback: running //domains/...");
      execSync("buck2 build //domains/...", {
        cwd: repoRoot,
        stdio: "inherit",
      });
      let qualityTargets = "";
      try {
        const out = execSync(
          "buck2 cquery \"attrregexfilter(name, 'lint|fmt|sast', //domains/...)\"",
          { cwd: repoRoot, encoding: "utf-8", stdio: ["pipe", "pipe", "pipe"] },
        );
        qualityTargets = out
          .trim()
          .replace(/ \(prelude[^)]*\)/g, "")
          .split(/\s+/)
          .filter(Boolean)
          .join(" ");
      } catch {
        /* cquery may fail if no targets match */
      }
      if (qualityTargets) {
        execSync(`buck2 build ${qualityTargets}`, {
          cwd: repoRoot,
          stdio: "inherit",
        });
      }
    } else {
      if (build) {
        console.log("--- Building affected targets ---");
        execSync(`buck2 build ${build}`, { cwd: repoRoot, stdio: "inherit" });
      } else {
        console.log("No affected build targets.");
      }
      if (test) {
        console.log("--- Running affected tests ---");
        execSync(`buck2 test ${test}`, { cwd: repoRoot, stdio: "inherit" });
      } else {
        console.log("No affected tests.");
      }
      if (quality) {
        console.log("--- Running affected quality checks ---");
        execSync(`buck2 build ${quality}`, { cwd: repoRoot, stdio: "inherit" });
      } else {
        console.log("No affected quality targets.");
      }
    }
    return;
  }

  if (cmd === "sparse-checkout") {
    const sub = args[1];
    if (sub === "list") {
      listProfiles(repoRoot);
      return;
    }
    if (sub === "apply") {
      const profile = args[2];
      if (!profile) {
        console.error(
          "Usage: monorepo-tooling sparse-checkout apply <PROFILE>",
        );
        process.exit(1);
      }
      console.log(`Applying profile: ${profile}`);
      applyProfile(repoRoot, profile);
      return;
    }
    if (sub === "new-clone") {
      const profile = args[2];
      const repoUrl = args[3];
      if (!profile || !repoUrl) {
        console.error(
          "Usage: monorepo-tooling sparse-checkout new-clone <PROFILE> <REPO_URL>",
        );
        process.exit(1);
      }
      newClone(profile, repoUrl, process.cwd());
      return;
    }
    console.error(
      "Usage: monorepo-tooling sparse-checkout list|apply|new-clone [args]",
    );
    process.exit(1);
  }

  console.error(`Unknown command: ${cmd}`);
  console.error(
    "Usage: monorepo-tooling sparse-dirs|affected-targets|profile-targets|run-affected|sparse-checkout [args]",
  );
  process.exit(1);
}

main();
