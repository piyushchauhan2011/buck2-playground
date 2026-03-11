import * as fs from "node:fs";
import * as path from "node:path";
import { execSync } from "node:child_process";

const BASE_DIRS = [
  "common/profiles",
  "scripts",
  ".github",
  "toolchains",
  "build_defs",
  "libs/monorepo-tooling",
];

interface ProfileJson {
  owner?: string;
  purpose?: string;
  includeFolders: string[];
}

function getProfilesDir(repoRoot: string): string {
  return path.join(repoRoot, "common", "profiles");
}

export function listProfiles(repoRoot: string): void {
  const profilesDir = getProfilesDir(repoRoot);
  if (!fs.existsSync(profilesDir)) {
    console.error("Profiles directory not found:", profilesDir);
    process.exit(1);
  }
  const files = fs.readdirSync(profilesDir).filter((f) => f.endsWith(".json"));
  console.log("Available profiles:");
  for (const f of files) {
    const name = path.basename(f, ".json");
    const content = JSON.parse(
      fs.readFileSync(path.join(profilesDir, f), "utf-8"),
    ) as ProfileJson;
    const owner = content.owner ?? "unknown owner";
    const dirs = (content.includeFolders ?? []).join(", ");
    console.log(`  ${name.padEnd(12)}  ${owner.padEnd(36)}  ${dirs}`);
  }
}

export function applyProfile(repoRoot: string, profile: string): void {
  const profileFile = path.join(getProfilesDir(repoRoot), `${profile}.json`);
  if (!fs.existsSync(profileFile)) {
    console.error("Unknown profile:", profile);
    listProfiles(repoRoot);
    process.exit(1);
  }
  const content = JSON.parse(
    fs.readFileSync(profileFile, "utf-8"),
  ) as ProfileJson;
  const profileDirs = content.includeFolders ?? [];
  const allDirs = [...BASE_DIRS, ...profileDirs];
  execSync(`git sparse-checkout set ${allDirs.join(" ")}`, {
    cwd: repoRoot,
    stdio: "inherit",
  });
  console.log("");
  console.log(`Sparse cone after applying '${profile}' profile:`);
  execSync("git sparse-checkout list", { cwd: repoRoot, stdio: "inherit" });
}

export function newClone(
  profile: string,
  repoUrl: string,
  cwd: string = process.cwd(),
): void {
  const repoName = path.basename(repoUrl.replace(/\.git$/, ""));
  console.log(`Cloning ${repoUrl} with blobless filter…`);
  execSync(`git clone --filter=blob:none --no-checkout "${repoUrl}"`, {
    cwd,
    stdio: "inherit",
  });
  const repoPath = path.join(cwd, repoName);
  execSync("git sparse-checkout init --cone", {
    cwd: repoPath,
    stdio: "inherit",
  });
  execSync(`git sparse-checkout set ${BASE_DIRS.join(" ")}`, {
    cwd: repoPath,
    stdio: "inherit",
  });
  execSync("git checkout", { cwd: repoPath, stdio: "inherit" });
  applyProfile(repoPath, profile);
}
