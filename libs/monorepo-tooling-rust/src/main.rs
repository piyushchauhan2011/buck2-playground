//! Monorepo tooling CLI — sparse-dirs, affected-targets, profile-targets, sparse-checkout.
//!
//! Usage:
//!   monorepo-tooling sparse-dirs [BASE_REF] [HEAD_REF]
//!   monorepo-tooling affected-targets [BASE_REF] [HEAD_REF]
//!   monorepo-tooling profile-targets <PROFILE>
//!   monorepo-tooling sparse-checkout list
//!   monorepo-tooling sparse-checkout apply <PROFILE>
//!   monorepo-tooling sparse-checkout new-clone <PROFILE> <REPO_URL>

mod cli;
mod core;

use clap::Parser;
use cli::Commands;
use core::{
    compute_affected_targets, compute_profile_targets, compute_sparse_dirs,
    sparse_checkout_apply, sparse_checkout_list, sparse_checkout_new_clone,
};
use std::process::exit;

fn main() {
    let args = cli::MonorepoTooling::parse();

    let repo_root = match core::git_rev_parse_show_toplevel(args.repo_root.as_deref()) {
        Ok(r) => r,
        Err(e) => {
            eprintln!("Error: {}", e);
            exit(1);
        }
    };

    match args.command {
        Commands::SparseDirs { base_ref, head_ref } => {
            let base = base_ref.as_deref().unwrap_or("HEAD~1");
            let head = head_ref.as_deref().unwrap_or("HEAD");
            let result = compute_sparse_dirs(&repo_root, base, head);
            println!("export SPARSE_DIRS='{}'", result.sparse_dirs.join(" "));
        }
        Commands::AffectedTargets { base_ref, head_ref } => {
            let base = base_ref.as_deref().unwrap_or("HEAD~1");
            let head = head_ref.as_deref().unwrap_or("HEAD");
            let result = compute_affected_targets(&repo_root, base, head);
            print_affected_exports(&result);
        }
        Commands::ProfileTargets { profile } => {
            let result = compute_profile_targets(&repo_root, &profile);
            print_affected_exports(&result);
        }
        Commands::SparseCheckout(subcommand) => {
            match subcommand {
                cli::SparseCheckoutCmd::List => {
                    sparse_checkout_list(&repo_root);
                }
                cli::SparseCheckoutCmd::Apply { profile } => {
                    sparse_checkout_apply(&repo_root, &profile);
                }
                cli::SparseCheckoutCmd::NewClone { profile, repo_url } => {
                    let cwd = std::env::current_dir()
                        .unwrap_or_else(|_| std::path::PathBuf::from("."))
                        .to_string_lossy()
                        .to_string();
                    sparse_checkout_new_clone(&profile, &repo_url, &cwd);
                }
            }
        }
    }
}

fn print_affected_exports(result: &core::AffectedResult) {
    let join = |arr: &[String]| arr.join(" ");
    println!("export BUILD_TARGETS='{}'", join(&result.build));
    println!("export TEST_TARGETS='{}'", join(&result.test));
    println!("export QUALITY_TARGETS='{}'", join(&result.quality));
    println!(
        "export BUILD_NODE='{}'",
        join(&result.by_language.build.node)
    );
    println!(
        "export BUILD_PYTHON='{}'",
        join(&result.by_language.build.python)
    );
    println!(
        "export BUILD_PHP='{}'",
        join(&result.by_language.build.php)
    );
    println!(
        "export BUILD_OTHER='{}'",
        join(&result.by_language.build.other)
    );
    println!(
        "export TEST_NODE='{}'",
        join(&result.by_language.test.node)
    );
    println!(
        "export TEST_PYTHON='{}'",
        join(&result.by_language.test.python)
    );
    println!(
        "export TEST_PHP='{}'",
        join(&result.by_language.test.php)
    );
    println!(
        "export TEST_OTHER='{}'",
        join(&result.by_language.test.other)
    );
    println!(
        "export QUALITY_NODE='{}'",
        join(&result.by_language.quality.node)
    );
    println!(
        "export QUALITY_PYTHON='{}'",
        join(&result.by_language.quality.python)
    );
    println!(
        "export QUALITY_PHP='{}'",
        join(&result.by_language.quality.php)
    );
    println!(
        "export QUALITY_OTHER='{}'",
        join(&result.by_language.quality.other)
    );
    println!("export NEEDS_NODE='{}'", result.needs_node);
    println!("export NEEDS_PYTHON='{}'", result.needs_python);
    println!("export NEEDS_PHP='{}'", result.needs_php);
}
