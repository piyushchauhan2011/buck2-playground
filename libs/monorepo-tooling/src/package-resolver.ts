import * as fs from "node:fs";
import * as path from "node:path";

/**
 * Strip Buck2 configuration suffix from uquery output.
 * e.g. "root//domains/api:target (prelude//platforms:default#abc123)" -> "root//domains/api:target"
 */
export function stripConfig(line: string): string {
  return line.replace(/\s*\([^)]*\)\s*$/, "").trim();
}

/**
 * Walk up from a file path to find the nearest directory containing a BUCK file.
 */
export function nearestPackage(
  filePath: string,
  repoRoot: string,
): string | null {
  const root = path.resolve(repoRoot);
  let dir = path.resolve(root, path.dirname(filePath));
  while (dir && dir !== root && dir !== path.dirname(dir)) {
    if (fs.existsSync(path.join(dir, "BUCK"))) {
      return path.relative(root, dir) || ".";
    }
    dir = path.dirname(dir);
  }
  if (dir === root && fs.existsSync(path.join(dir, "BUCK"))) {
    return ".";
  }
  return null;
}

/**
 * Extract package path from a Buck target label.
 * e.g. "root//domains/api/js:api_js" -> "domains/api/js"
 */
export function targetToPackage(target: string): string | null {
  // Match root//path:target or //path:target
  const match = target.match(/^(?:root\/\/|\/\/)([^:]+)/);
  if (!match) return null;
  const pkg = match[1];
  return pkg.startsWith("root/") ? pkg.slice(5) : pkg;
}

export type Language = "node" | "python" | "php" | "other";

/**
 * Check if a package has a manifest file (for toolchain detection).
 */
function hasManifest(
  repoRoot: string,
  pkgPath: string,
  files: string[],
  gitCatFileExists: (path: string) => boolean,
): boolean {
  return files.some(
    (f) =>
      fs.existsSync(path.join(repoRoot, pkgPath, f)) ||
      gitCatFileExists(`${pkgPath}/${f}`),
  );
}

/**
 * Classify a target's language based on its package manifest files.
 * PHP first (Laravel has both composer.json and package.json).
 */
export function classifyTarget(
  target: string,
  repoRoot: string,
  gitCatFileExists: (path: string) => boolean,
): Language {
  const pkg = targetToPackage(target);
  if (!pkg) return "other";

  if (hasManifest(repoRoot, pkg, ["composer.json"], gitCatFileExists)) {
    return "php";
  }
  if (hasManifest(repoRoot, pkg, ["package.json"], gitCatFileExists)) {
    return "node";
  }
  if (
    hasManifest(
      repoRoot,
      pkg,
      ["requirements.txt", "pyproject.toml"],
      gitCatFileExists,
    )
  ) {
    return "python";
  }
  return "other";
}
