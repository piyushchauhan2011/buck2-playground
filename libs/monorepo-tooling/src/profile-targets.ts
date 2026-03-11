import * as fs from "node:fs";
import * as path from "node:path";
import type { AffectedResult, Language } from "./types.js";
import { buck2Uquery } from "./buck.js";
import { gitCatFileExists, gitRevParseShowToplevel } from "./git.js";
import { classifyTarget } from "./package-resolver.js";

const LANGUAGES: Language[] = ["node", "python", "php", "other"];

function emptyByLanguage(): Record<Language, string[]> {
  return {
    node: [],
    python: [],
    php: [],
    other: [],
  };
}

function splitByLanguage(
  targets: string[],
  repoRoot: string
): Record<Language, string[]> {
  const result = emptyByLanguage();
  const catFile = (p: string) => gitCatFileExists(p, repoRoot);
  for (const t of targets) {
    if (!t.trim()) continue;
    const lang = classifyTarget(t, repoRoot, catFile);
    result[lang].push(t);
  }
  return result;
}

export interface ProfileTargetsOptions {
  profile: string;
  repoRoot?: string;
}

export function computeProfileTargets(
  options: ProfileTargetsOptions
): AffectedResult {
  const repoRoot = options.repoRoot ?? gitRevParseShowToplevel();
  const profilePath = path.join(repoRoot, "common", "profiles", `${options.profile}.json`);

  const empty: AffectedResult = {
    build: [],
    test: [],
    quality: [],
    byLanguage: {
      build: emptyByLanguage(),
      test: emptyByLanguage(),
      quality: emptyByLanguage(),
    },
    needsNode: false,
    needsPython: false,
    needsPhp: false,
  };

  if (!fs.existsSync(profilePath)) {
    return empty;
  }

  const profile = JSON.parse(fs.readFileSync(profilePath, "utf-8")) as {
    includeFolders?: string[];
  };
  const dirs = (profile.includeFolders ?? []) as string[];

  let owning: string[] = [];
  for (const d of dirs) {
    if (!d.trim()) continue;
    const buckPath = path.join(repoRoot, d, "BUCK");
    if (!fs.existsSync(buckPath)) continue;
    const res = buck2Uquery(`kind('genrule|sh_test', //${d}/...)`, repoRoot);
    owning.push(...res);
  }
  owning = [...new Set(owning)].sort();

  if (owning.length === 0) return empty;

  const targetsSet = `set(${owning.join(" ")})`;
  const deps = buck2Uquery(`deps(${targetsSet})`, repoRoot);
  owning = [...new Set([...owning, ...deps])].filter((t) =>
    t.startsWith("root//")
  );

  const affectedPkgs = new Set<string>();
  for (const t of owning) {
    const match = t.match(/(?:root\/)?\/\/([^:]+)/);
    if (match) affectedPkgs.add(match[1].replace(/^root\//, ""));
  }

  const catFile = (p: string) => gitCatFileExists(p, repoRoot);
  let needsNode = false;
  let needsPython = false;
  let needsPhp = false;
  for (const pkg of affectedPkgs) {
    if (
      catFile(`${pkg}/package.json`) ||
      fs.existsSync(path.join(repoRoot, pkg, "package.json"))
    )
      needsNode = true;
    if (
      catFile(`${pkg}/requirements.txt`) ||
      catFile(`${pkg}/pyproject.toml`) ||
      fs.existsSync(path.join(repoRoot, pkg, "requirements.txt")) ||
      fs.existsSync(path.join(repoRoot, pkg, "pyproject.toml"))
    )
      needsPython = true;
    if (
      catFile(`${pkg}/composer.json`) ||
      fs.existsSync(path.join(repoRoot, pkg, "composer.json"))
    )
      needsPhp = true;
  }

  const universe = `set(${owning.join(" ")})`;
  const testTargets = buck2Uquery(
    `filter('(_test|_vitest)$', ${universe})`,
    repoRoot
  );
  const qualityTargets = buck2Uquery(
    `attrregexfilter(name, '(lint|fmt|sast|typecheck)$', ${universe})`,
    repoRoot
  );
  const buildTargets = owning;

  const byLangBuild = splitByLanguage(buildTargets, repoRoot);
  const byLangTest = splitByLanguage(testTargets, repoRoot);
  const byLangQuality = splitByLanguage(qualityTargets, repoRoot);

  return {
    build: buildTargets,
    test: testTargets,
    quality: qualityTargets,
    byLanguage: {
      build: byLangBuild,
      test: byLangTest,
      quality: byLangQuality,
    },
    needsNode,
    needsPython,
    needsPhp,
  };
}
