use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "monorepo-tooling")]
#[command(about = "Monorepo CLI: sparse-dirs, affected-targets, profile-targets, sparse-checkout")]
pub struct MonorepoTooling {
    #[command(subcommand)]
    pub command: Commands,

    /// Repository root (default: git rev-parse --show-toplevel)
    #[arg(global = true, long)]
    pub repo_root: Option<String>,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Compute sparse dirs for changed packages (affects output)
    SparseDirs {
        #[arg(default_value = "HEAD~1")]
        base_ref: Option<String>,
        #[arg(default_value = "HEAD")]
        head_ref: Option<String>,
    },

    /// Compute affected build/test/quality targets (affects output)
    AffectedTargets {
        #[arg(default_value = "HEAD~1")]
        base_ref: Option<String>,
        #[arg(default_value = "HEAD")]
        head_ref: Option<String>,
    },

    /// Compute targets for a profile (affects output)
    ProfileTargets {
        profile: String,
    },

    #[command(subcommand)]
    SparseCheckout(SparseCheckoutCmd),
}

#[derive(Subcommand)]
pub enum SparseCheckoutCmd {
    /// List available profiles
    List,

    /// Apply a profile to sparse-checkout
    Apply {
        profile: String,
    },

    /// Clone repo with blobless filter and apply profile
    NewClone {
        profile: String,
        repo_url: String,
    },
}
