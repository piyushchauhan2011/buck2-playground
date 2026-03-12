//! Core logic: git, buck2, package resolution, sparse-dirs, affected-targets.

use std::path::Path;
use std::process::Command;

#[derive(Debug, Clone, Default)]
pub struct AffectedResult {
    pub build: Vec<String>,
    pub test: Vec<String>,
    pub quality: Vec<String>,
    pub by_language: ByLanguage,
    pub needs_node: bool,
    pub needs_python: bool,
    pub needs_php: bool,
}

#[derive(Debug, Clone, Default)]
pub struct ByLanguage {
    pub build: LangTargets,
    pub test: LangTargets,
    pub quality: LangTargets,
}

#[derive(Debug, Clone, Default)]
pub struct LangTargets {
    pub node: Vec<String>,
    pub python: Vec<String>,
    pub php: Vec<String>,
    pub other: Vec<String>,
}

#[derive(Debug)]
pub struct SparseDirsResult {
    pub sparse_dirs: Vec<String>,
}

#[derive(Debug, Clone, Copy)]
pub enum Language {
    Node,
    Python,
    Php,
    Other,
}

// --- Git ---

pub fn git_changed_files(repo_root: &str, base_ref: &str, head_ref: &str) -> Result<Vec<String>, String> {
    let out = Command::new("git")
        .args(["diff", "--name-only", &format!("{}...{}", base_ref, head_ref)])
        .current_dir(repo_root)
        .output()
        .map_err(|e| e.to_string())?;
    if !out.status.success() {
        return Err(String::from_utf8_lossy(&out.stderr).into_owned());
    }
    let s = String::from_utf8_lossy(&out.stdout);
    Ok(s.lines().map(|l| l.trim().to_string()).filter(|l| !l.is_empty()).collect())
}

pub fn git_cat_file_exists(repo_root: &str, path: &str) -> bool {
    let out = Command::new("git")
        .args(["cat-file", "-e", &format!("HEAD:{}", path)])
        .current_dir(repo_root)
        .output();
    out.map(|o| o.status.success()).unwrap_or(false)
}

pub fn git_rev_parse_show_toplevel(cwd: Option<&str>) -> Result<String, String> {
    let mut cmd = Command::new("git");
    cmd.args(["rev-parse", "--show-toplevel"]);
    if let Some(c) = cwd {
        cmd.current_dir(c);
    }
    let out = cmd.output().map_err(|e| e.to_string())?;
    if !out.status.success() {
        return Err(String::from_utf8_lossy(&out.stderr).into_owned());
    }
    Ok(String::from_utf8_lossy(&out.stdout).trim().to_string())
}

// --- Buck2 ---

/// Strip Buck2 configuration suffix. e.g. "root//x:y (prelude//platforms:default#abc)" -> "root//x:y"
fn strip_config(line: &str) -> String {
    let line = line.trim();
    if let Some(idx) = line.rfind(" (") {
        line[..idx].trim().to_string()
    } else {
        line.to_string()
    }
}

pub fn buck2_uquery(query: &str, repo_root: &str) -> Result<Vec<String>, String> {
    let out = Command::new("buck2")
        .args(["uquery", query])
        .current_dir(repo_root)
        .output()
        .map_err(|e| e.to_string())?;
    if !out.status.success() {
        return Err(String::from_utf8_lossy(&out.stderr).into_owned());
    }
    let s = String::from_utf8_lossy(&out.stdout);
    Ok(s.lines()
        .map(|l| strip_config(l.trim()))
        .filter(|l| !l.is_empty())
        .collect())
}

// --- Package resolver ---

/// Walk up from a file path to find the nearest directory containing a BUCK file.
/// Uses git cat-file for blob:none (sparse checkout).
pub fn nearest_package(
    file_path: &str,
    repo_root: &str,
    git_cat_file_exists: impl Fn(&str) -> bool,
) -> Option<String> {
    let mut dir = Path::new(file_path).parent().unwrap_or(Path::new("."));
    let root = Path::new(repo_root);

    loop {
        let buck_path = dir.join("BUCK");
        let rel = buck_path.to_string_lossy().replace('\\', "/");
        if git_cat_file_exists(&rel) {
            let p = dir.to_string_lossy().replace('\\', "/");
            return Some(if p.is_empty() || p == "." { ".".to_string() } else { p });
        }
        // Also check filesystem (for full checkout)
        let abs = root.join(&buck_path);
        if abs.exists() {
            let p = dir.to_string_lossy().replace('\\', "/");
            return Some(if p.is_empty() || p == "." { ".".to_string() } else { p });
        }
        dir = match dir.parent() {
            Some(p) if p != dir && !p.as_os_str().is_empty() => p,
            _ => break,
        };
    }
    // Check root
    if git_cat_file_exists("BUCK") || root.join("BUCK").exists() {
        return Some(".".to_string());
    }
    None
}

/// Extract package path from target label. e.g. "root//domains/api/js:api_js" -> "domains/api/js"
pub fn target_to_package(target: &str) -> Option<String> {
    let target = target.strip_prefix("root//").unwrap_or(target.strip_prefix("//").unwrap_or(target));
    let colon = target.find(':')?;
    let pkg = &target[..colon];
    Some(if pkg.starts_with("root/") { pkg[5..].to_string() } else { pkg.to_string() })
}

fn has_manifest(
    repo_root: &Path,
    pkg_path: &str,
    files: &[&str],
    git_cat_file_exists: &impl Fn(&str) -> bool,
) -> bool {
    files.iter().any(|f| {
        let p = format!("{}/{}", pkg_path.trim_end_matches('/'), f.trim_start_matches('/'));
        let p = p.trim_start_matches('/');
        git_cat_file_exists(p) || repo_root.join(p).exists()
    })
}

pub fn classify_target(
    target: &str,
    repo_root: &Path,
    git_cat_file_exists: impl Fn(&str) -> bool,
) -> Language {
    let pkg = match target_to_package(target) {
        Some(p) => p,
        None => return Language::Other,
    };
    if pkg.is_empty() || pkg == "." {
        return Language::Other;
    }
    // PHP first (Laravel has both composer.json and package.json)
    if has_manifest(repo_root, &pkg, &["composer.json"], &git_cat_file_exists) {
        return Language::Php;
    }
    if has_manifest(repo_root, &pkg, &["package.json"], &git_cat_file_exists) {
        return Language::Node;
    }
    if has_manifest(repo_root, &pkg, &["requirements.txt", "pyproject.toml"], &git_cat_file_exists) {
        return Language::Python;
    }
    Language::Other
}

// --- Sparse dirs ---

pub fn compute_sparse_dirs(repo_root: &str, base_ref: &str, head_ref: &str) -> SparseDirsResult {
    let changed = match git_changed_files(repo_root, base_ref, head_ref) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("git diff failed: {}", e);
            return SparseDirsResult { sparse_dirs: vec![] };
        }
    };
    if changed.is_empty() {
        return SparseDirsResult { sparse_dirs: vec![] };
    }

    let cat_file = |p: &str| git_cat_file_exists(repo_root, p);
    let mut packages: std::collections::HashSet<String> = std::collections::HashSet::new();
    for f in &changed {
        if let Some(pkg) = nearest_package(f, repo_root, &cat_file) {
            if pkg != "." {
                packages.insert(pkg);
            }
        }
    }
    let mut package_list: Vec<_> = packages.into_iter().collect();
    package_list.sort();

    if package_list.is_empty() {
        return SparseDirsResult { sparse_dirs: vec![] };
    }

    let mut owning: Vec<String> = vec![];
    for pkg in &package_list {
        let query = format!("kind('genrule|sh_test', //{}/...)", pkg);
        if let Ok(res) = buck2_uquery(&query, repo_root) {
            owning.extend(res);
        }
    }
    owning.sort();
    owning.dedup();

    if owning.is_empty() {
        return SparseDirsResult { sparse_dirs: vec![] };
    }

    let targets_set = format!("set({})", owning.join(" "));
    if let Ok(impacted) = buck2_uquery(&format!("rdeps(//..., {})", targets_set), repo_root) {
        if !impacted.is_empty() {
            owning = impacted;
        }
    }

    let impacted_set = format!("set({})", owning.join(" "));
    let mut all_needed = owning.clone();
    if let Ok(deps) = buck2_uquery(&format!("deps({})", impacted_set), repo_root) {
        all_needed.extend(deps);
    }
    all_needed.sort();
    all_needed.dedup();

    let mut dirs: std::collections::HashSet<String> = std::collections::HashSet::new();
    for t in &all_needed {
        // Only include root cell targets (our repo), not prelude/toolchains
        if let Some(stripped) = t.strip_prefix("root//") {
            if let Some(colon) = stripped.find(':') {
                dirs.insert(stripped[..colon].to_string());
            }
        }
    }
    let mut sparse_dirs: Vec<_> = dirs.into_iter().collect();
    sparse_dirs.sort();
    SparseDirsResult { sparse_dirs }
}

// --- Affected targets ---

fn empty_by_language() -> LangTargets {
    LangTargets {
        node: vec![],
        python: vec![],
        php: vec![],
        other: vec![],
    }
}

fn split_by_language(
    targets: &[String],
    repo_root: &Path,
    cat_file: &impl Fn(&str) -> bool,
) -> LangTargets {
    let mut result = empty_by_language();
    for t in targets {
        if t.trim().is_empty() {
            continue;
        }
        let lang = classify_target(t, repo_root, cat_file);
        match lang {
            Language::Node => result.node.push(t.clone()),
            Language::Python => result.python.push(t.clone()),
            Language::Php => result.php.push(t.clone()),
            Language::Other => result.other.push(t.clone()),
        }
    }
    result
}

pub fn compute_affected_targets(
    repo_root: &str,
    base_ref: &str,
    head_ref: &str,
) -> AffectedResult {
    let changed = match git_changed_files(repo_root, base_ref, head_ref) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("git diff failed: {}", e);
            return AffectedResult::default();
        }
    };

    let empty = AffectedResult::default();
    if changed.is_empty() {
        return empty;
    }

    let cat_file = |p: &str| git_cat_file_exists(repo_root, p);
    let mut packages: std::collections::HashSet<String> = std::collections::HashSet::new();
    for f in &changed {
        if let Some(pkg) = nearest_package(f, repo_root, &cat_file) {
            if pkg != "." {
                packages.insert(pkg);
            }
        }
    }
    let mut package_list: Vec<_> = packages.into_iter().collect();
    package_list.sort();

    if package_list.is_empty() {
        return empty;
    }

    let mut owning: Vec<String> = vec![];
    for pkg in &package_list {
        let query = format!("kind('genrule|sh_test', //{}/...)", pkg);
        if let Ok(res) = buck2_uquery(&query, repo_root) {
            owning.extend(res);
        }
    }
    owning.sort();
    owning.dedup();

    if owning.is_empty() {
        return empty;
    }

    let targets_set = format!("set({})", owning.join(" "));
    if let Ok(impacted) = buck2_uquery(&format!("rdeps(//..., {})", targets_set), repo_root) {
        if !impacted.is_empty() {
            owning = impacted;
        }
    }

    let mut affected_pkgs: std::collections::HashSet<String> = std::collections::HashSet::new();
    for t in &owning {
        if let Some(m) = t.strip_prefix("root//").or_else(|| t.strip_prefix("//")) {
            if let Some(colon) = m.find(':') {
                let pkg = m[..colon].replace("root/", "");
                affected_pkgs.insert(pkg);
            }
        }
    }

    let mut needs_node = false;
    let mut needs_python = false;
    let mut needs_php = false;
    let root_path = Path::new(repo_root);
    for pkg in &affected_pkgs {
        if cat_file(&format!("{}/package.json", pkg)) || root_path.join(pkg).join("package.json").exists() {
            needs_node = true;
        }
        if cat_file(&format!("{}/requirements.txt", pkg))
            || cat_file(&format!("{}/pyproject.toml", pkg))
            || root_path.join(pkg).join("requirements.txt").exists()
            || root_path.join(pkg).join("pyproject.toml").exists()
        {
            needs_python = true;
        }
        if cat_file(&format!("{}/composer.json", pkg)) || root_path.join(pkg).join("composer.json").exists() {
            needs_php = true;
        }
    }

    let universe = format!("set({})", owning.join(" "));
    let test_targets = buck2_uquery(
        &format!("filter('(_test|_vitest)$', {})", universe),
        repo_root,
    )
    .unwrap_or_default();
    let quality_targets = buck2_uquery(
        &format!("attrregexfilter(name, '(lint|fmt|sast|typecheck)$', {})", universe),
        repo_root,
    )
    .unwrap_or_default();
    let build_targets = owning;

    let by_lang_build = split_by_language(&build_targets, root_path, &cat_file);
    let by_lang_test = split_by_language(&test_targets, root_path, &cat_file);
    let by_lang_quality = split_by_language(&quality_targets, root_path, &cat_file);

    AffectedResult {
        build: build_targets,
        test: test_targets,
        quality: quality_targets,
        by_language: ByLanguage {
            build: by_lang_build,
            test: by_lang_test,
            quality: by_lang_quality,
        },
        needs_node,
        needs_python,
        needs_php,
    }
}

// --- Profile targets ---

#[derive(serde::Deserialize)]
struct ProfileJson {
    #[serde(default)]
    include_folders: Vec<String>,
}

pub fn compute_profile_targets(repo_root: &str, profile: &str) -> AffectedResult {
    let profile_path = Path::new(repo_root)
        .join("common")
        .join("profiles")
        .join(format!("{}.json", profile));

    let empty = AffectedResult::default();
    if !profile_path.exists() {
        return empty;
    }

    let content = match std::fs::read_to_string(&profile_path) {
        Ok(c) => c,
        Err(_) => return empty,
    };
    let profile_data: ProfileJson = match serde_json::from_str(&content) {
        Ok(p) => p,
        Err(_) => return empty,
    };
    let dirs = &profile_data.include_folders;

    let mut owning: Vec<String> = vec![];
    for d in dirs {
        if d.trim().is_empty() {
            continue;
        }
        let buck_path = Path::new(repo_root).join(d).join("BUCK");
        if !buck_path.exists() {
            continue;
        }
        let query = format!("kind('genrule|sh_test', //{}/...)", d);
        if let Ok(res) = buck2_uquery(&query, repo_root) {
            owning.extend(res);
        }
    }
    owning.sort();
    owning.dedup();

    if owning.is_empty() {
        return empty;
    }

    let targets_set = format!("set({})", owning.join(" "));
    if let Ok(deps) = buck2_uquery(&format!("deps({})", targets_set), repo_root) {
        owning.extend(deps);
    }
    owning.sort();
    owning.dedup();
    owning.retain(|t| t.starts_with("root//"));

    let mut affected_pkgs: std::collections::HashSet<String> = std::collections::HashSet::new();
    for t in &owning {
        if let Some(m) = t.strip_prefix("root//") {
            if let Some(colon) = m.find(':') {
                affected_pkgs.insert(m[..colon].to_string());
            }
        }
    }

    let cat_file = |p: &str| git_cat_file_exists(repo_root, p);
    let mut needs_node = false;
    let mut needs_python = false;
    let mut needs_php = false;
    let root_path = Path::new(repo_root);
    for pkg in &affected_pkgs {
        if cat_file(&format!("{}/package.json", pkg)) || root_path.join(pkg).join("package.json").exists() {
            needs_node = true;
        }
        if cat_file(&format!("{}/requirements.txt", pkg))
            || cat_file(&format!("{}/pyproject.toml", pkg))
            || root_path.join(pkg).join("requirements.txt").exists()
            || root_path.join(pkg).join("pyproject.toml").exists()
        {
            needs_python = true;
        }
        if cat_file(&format!("{}/composer.json", pkg)) || root_path.join(pkg).join("composer.json").exists() {
            needs_php = true;
        }
    }

    let universe = format!("set({})", owning.join(" "));
    let test_targets = buck2_uquery(
        &format!("filter('(_test|_vitest)$', {})", universe),
        repo_root,
    )
    .unwrap_or_default();
    let quality_targets = buck2_uquery(
        &format!("attrregexfilter(name, '(lint|fmt|sast|typecheck)$', {})", universe),
        repo_root,
    )
    .unwrap_or_default();
    let build_targets = owning;

    let by_lang_build = split_by_language(&build_targets, root_path, &cat_file);
    let by_lang_test = split_by_language(&test_targets, root_path, &cat_file);
    let by_lang_quality = split_by_language(&quality_targets, root_path, &cat_file);

    AffectedResult {
        build: build_targets,
        test: test_targets,
        quality: quality_targets,
        by_language: ByLanguage {
            build: by_lang_build,
            test: by_lang_test,
            quality: by_lang_quality,
        },
        needs_node,
        needs_python,
        needs_php,
    }
}

// --- Sparse checkout ---

const BASE_DIRS: &[&str] = &[
    "common/profiles",
    "scripts",
    ".github",
    "toolchains",
    "build_defs",
    "libs/monorepo-tooling-rust",
];

pub fn sparse_checkout_list(repo_root: &str) {
    let profiles_dir = Path::new(repo_root).join("common").join("profiles");
    if !profiles_dir.exists() {
        eprintln!("Profiles directory not found: {:?}", profiles_dir);
        std::process::exit(1);
    }
    let entries = match std::fs::read_dir(&profiles_dir) {
        Ok(e) => e,
        Err(e) => {
            eprintln!("Error reading profiles: {}", e);
            std::process::exit(1);
        }
    };
    println!("Available profiles:");
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().map_or(false, |e| e == "json") {
            let name = path.file_stem().unwrap_or_default().to_string_lossy();
            if let Ok(content) = std::fs::read_to_string(&path) {
                if let Ok(profile) = serde_json::from_str::<ProfileJson>(&content) {
                    let owner = "unknown owner";
                    let dirs = profile.include_folders.join(", ");
                    println!("  {:12}  {:36}  {}", name, owner, dirs);
                }
            }
        }
    }
}

pub fn sparse_checkout_apply(repo_root: &str, profile: &str) {
    let profile_file = Path::new(repo_root)
        .join("common")
        .join("profiles")
        .join(format!("{}.json", profile));
    if !profile_file.exists() {
        eprintln!("Unknown profile: {}", profile);
        sparse_checkout_list(repo_root);
        std::process::exit(1);
    }
    let content = std::fs::read_to_string(&profile_file).expect("read profile");
    let profile_data: ProfileJson = serde_json::from_str(&content).expect("parse profile");
    let profile_dirs = profile_data.include_folders;
    let all_dirs: Vec<&str> = BASE_DIRS.iter().copied().chain(profile_dirs.iter().map(|s| s.as_str())).collect();
    let status = Command::new("git")
        .args(["sparse-checkout", "set"])
        .args(&all_dirs)
        .current_dir(repo_root)
        .status();
    if status.map(|s| !s.success()).unwrap_or(true) {
        std::process::exit(1);
    }
    println!("\nSparse cone after applying '{}' profile:", profile);
    let _ = Command::new("git")
        .args(["sparse-checkout", "list"])
        .current_dir(repo_root)
        .status();
}

pub fn sparse_checkout_new_clone(profile: &str, repo_url: &str, cwd: &str) {
    let repo_name = repo_url
        .trim_end_matches('/')
        .rsplit('/')
        .next()
        .unwrap_or("repo")
        .replace(".git", "");
    println!("Cloning {} with blobless filter…", repo_url);
    let status = Command::new("git")
        .args(["clone", "--filter=blob:none", "--no-checkout", repo_url])
        .current_dir(cwd)
        .status();
    if status.map(|s| !s.success()).unwrap_or(true) {
        std::process::exit(1);
    }
    let repo_path = Path::new(cwd).join(&repo_name);
    let _ = Command::new("git")
        .args(["sparse-checkout", "init", "--cone"])
        .current_dir(&repo_path)
        .status();
    let _ = Command::new("git")
        .args(["sparse-checkout", "set"])
        .args(BASE_DIRS)
        .current_dir(&repo_path)
        .status();
    let _ = Command::new("git").args(["checkout"]).current_dir(&repo_path).status();
    sparse_checkout_apply(repo_path.to_str().unwrap(), profile);
}
