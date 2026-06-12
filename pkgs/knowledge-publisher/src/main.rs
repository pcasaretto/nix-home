use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::env;
use std::ffi::OsStr;
use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::path::{Component, Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant, SystemTime};

use anyhow::{bail, Context, Result};
use chrono::{DateTime, Utc};
use clap::{Parser, Subcommand};
use html_escape::{encode_double_quoted_attribute, encode_text};
use notify::{recommended_watcher, RecursiveMode, Watcher};
use pulldown_cmark::{
    html, CowStr, Event, HeadingLevel, Options, Parser as MarkdownParser, Tag, TagEnd,
};
use serde::{Deserialize, Serialize};
use serde_yaml::Value as YamlValue;
use walkdir::WalkDir;

const DEFAULT_KNOWLEDGE_ROOT: &str = "/Users/paulo.casaretto/knowledge";
const DEFAULT_QMD_PATH: &str = "/Users/paulo.casaretto/.nix-profile/bin/qmd";
const DEFAULT_QUICK_PATH: &str =
    "/Users/paulo.casaretto/.local/state/tec/profiles/base/current/global/bin/quick";
const DEFAULT_SITE_NAME: &str = "pcasaretto-knowledge";
const FRESHNESS_TARGET_SECS: u64 = 60;
const LOG_MAX_BYTES: u64 = 5 * 1024 * 1024;
const LOG_ROTATIONS: usize = 5;

const BLOCKED_DIRS: &[&str] = &["tuple-calls", "work-journal-evidence"];

const FRONTMATTER_ALLOWLIST: &[&str] = &["title", "date", "status", "type", "project"];

#[derive(Parser, Debug)]
#[command(name = "knowledge-publisher")]
#[command(about = "Keep ~/knowledge indexed in qmd and published to Quick", long_about = None)]
struct Cli {
    #[arg(long)]
    knowledge_root: Option<PathBuf>,

    #[arg(long)]
    cache_dir: Option<PathBuf>,

    #[arg(long)]
    state_dir: Option<PathBuf>,

    #[arg(long)]
    qmd: Option<PathBuf>,

    #[arg(long)]
    quick: Option<PathBuf>,

    #[arg(long)]
    site_name: Option<String>,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Print environment and auth checks without deploying.
    Preflight,

    /// Ensure qmd collections exist for all publishable top-level folders.
    ReconcileQmd,

    /// Generate and write a dry-run publish manifest.
    #[command(visible_alias = "manifest")]
    DryRunManifest {
        #[arg(long)]
        output: Option<PathBuf>,
    },

    /// Generate the static site without qmd update/embed or Quick deploy.
    GenerateSite,

    /// Run qmd update/embed, generate the site, and deploy unless disabled.
    RunOnce {
        #[arg(long = "changed-path")]
        changed_paths: Vec<PathBuf>,

        #[arg(long)]
        no_deploy: bool,

        #[arg(long)]
        skip_qmd: bool,
    },

    /// Watch ~/knowledge and run after markdown changes.
    Watch,

    /// Show durable status.
    Status {
        #[arg(long)]
        json: bool,
    },
}

#[derive(Debug, Clone)]
struct Settings {
    knowledge_root: PathBuf,
    cache_dir: PathBuf,
    site_dir: PathBuf,
    state_dir: PathBuf,
    logs_dir: PathBuf,
    tmp_dir: PathBuf,
    qmd_path: PathBuf,
    quick_path: PathBuf,
    site_name: String,
}

#[derive(Debug, Clone, Serialize)]
struct ManifestDoc {
    source_path: PathBuf,
    relative_path: PathBuf,
    title: String,
    collection: String,
    modified: String,
    output_url_path: String,
    output_file: PathBuf,
    summary: Option<String>,
    metadata: BTreeMap<String, String>,
    warnings: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
struct Manifest {
    generated_at: String,
    knowledge_root: PathBuf,
    site_name: String,
    included_count: usize,
    excluded_count: usize,
    documents: Vec<ManifestDoc>,
    excluded: Vec<ExcludedPath>,
    warnings: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
struct ExcludedPath {
    relative_path: PathBuf,
    reason: String,
}

#[derive(Debug, Clone)]
struct SourceDoc {
    source_path: PathBuf,
    relative_path: PathBuf,
    body: String,
    summary_markdown: Option<String>,
    summary_text: Option<String>,
    title: String,
    collection: String,
    modified: String,
    output_url_path: String,
    output_file: PathBuf,
    metadata: BTreeMap<String, String>,
    warnings: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Status {
    updated_at: Option<String>,
    overall_state: String,
    last_run_started_at: Option<String>,
    last_run_finished_at: Option<String>,
    last_successful_qmd_update: Option<String>,
    last_successful_embed: Option<String>,
    last_successful_site_generation: Option<String>,
    last_successful_quick_deploy: Option<String>,
    last_manifest_path: Option<PathBuf>,
    last_generated_site_dir: Option<PathBuf>,
    last_deploy_url: Option<String>,
    last_warning: Option<String>,
    last_failure: Option<String>,
    pending_deploy: bool,
    stale_embeddings: bool,
    action_required: bool,
    deploy_failure_count: u32,
    next_deploy_retry_at: Option<String>,
}

impl Default for Status {
    fn default() -> Self {
        Self {
            updated_at: None,
            overall_state: "unknown".to_string(),
            last_run_started_at: None,
            last_run_finished_at: None,
            last_successful_qmd_update: None,
            last_successful_embed: None,
            last_successful_site_generation: None,
            last_successful_quick_deploy: None,
            last_manifest_path: None,
            last_generated_site_dir: None,
            last_deploy_url: None,
            last_warning: None,
            last_failure: None,
            pending_deploy: false,
            stale_embeddings: false,
            action_required: false,
            deploy_failure_count: 0,
            next_deploy_retry_at: None,
        }
    }
}

#[derive(Debug, Clone)]
struct CommandResult {
    program: String,
    args: Vec<String>,
    success: bool,
    exit_code: Option<i32>,
    stdout: String,
    stderr: String,
    duration_ms: u128,
    timed_out: bool,
}

#[derive(Debug, Clone)]
struct TocItem {
    level: u8,
    title: String,
    id: String,
}

impl Settings {
    fn from_cli(cli: &Cli) -> Result<Self> {
        let home = env::var("HOME").unwrap_or_else(|_| "/Users/paulo.casaretto".to_string());
        let knowledge_root = first_path(
            cli.knowledge_root.clone(),
            "KNOWLEDGE_PUBLISHER_ROOT",
            PathBuf::from(DEFAULT_KNOWLEDGE_ROOT),
        );
        let cache_dir = first_path(
            cli.cache_dir.clone(),
            "KNOWLEDGE_PUBLISHER_CACHE_DIR",
            PathBuf::from(format!("{home}/.cache/knowledge-publisher")),
        );
        let state_dir = first_path(
            cli.state_dir.clone(),
            "KNOWLEDGE_PUBLISHER_STATE_DIR",
            PathBuf::from(format!("{home}/.local/state/knowledge-publisher")),
        );
        let qmd_path = first_path(
            cli.qmd.clone(),
            "KNOWLEDGE_PUBLISHER_QMD",
            PathBuf::from(DEFAULT_QMD_PATH),
        );
        let quick_path = first_path(
            cli.quick.clone(),
            "KNOWLEDGE_PUBLISHER_QUICK",
            PathBuf::from(DEFAULT_QUICK_PATH),
        );
        let site_name = cli
            .site_name
            .clone()
            .or_else(|| env::var("KNOWLEDGE_PUBLISHER_SITE_NAME").ok())
            .unwrap_or_else(|| DEFAULT_SITE_NAME.to_string());
        if site_name != DEFAULT_SITE_NAME {
            bail!("refusing to use non-approved Quick site name: {site_name}");
        }
        Ok(Self {
            knowledge_root,
            site_dir: cache_dir.join("site"),
            cache_dir,
            logs_dir: state_dir.join("logs"),
            tmp_dir: state_dir.join("tmp"),
            state_dir,
            qmd_path,
            quick_path,
            site_name,
        })
    }

    fn ensure_dirs(&self) -> Result<()> {
        fs::create_dir_all(&self.cache_dir)
            .with_context(|| format!("creating {}", self.cache_dir.display()))?;
        fs::create_dir_all(&self.state_dir)
            .with_context(|| format!("creating {}", self.state_dir.display()))?;
        fs::create_dir_all(&self.logs_dir)
            .with_context(|| format!("creating {}", self.logs_dir.display()))?;
        fs::create_dir_all(&self.tmp_dir)
            .with_context(|| format!("creating {}", self.tmp_dir.display()))?;
        Ok(())
    }

    fn status_path(&self) -> PathBuf {
        self.state_dir.join("status.json")
    }

    fn manifest_json_path(&self) -> PathBuf {
        self.state_dir.join("publish-manifest.json")
    }

    fn manifest_md_path(&self) -> PathBuf {
        self.state_dir.join("publish-manifest.md")
    }

    fn log_path(&self) -> PathBuf {
        self.logs_dir.join("publisher.log")
    }
}

fn first_path(cli: Option<PathBuf>, env_key: &str, default: PathBuf) -> PathBuf {
    cli.or_else(|| env::var(env_key).ok().map(PathBuf::from))
        .unwrap_or(default)
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let settings = Settings::from_cli(&cli)?;
    settings.ensure_dirs()?;

    match &cli.command {
        Commands::Preflight => preflight(&settings),
        Commands::ReconcileQmd => reconcile_qmd(&settings, true),
        Commands::DryRunManifest { output } => {
            let manifest = build_manifest(&settings)?;
            write_manifest(&settings, &manifest, output.clone())?;
            print_manifest_summary(&manifest);
            Ok(())
        }
        Commands::GenerateSite => {
            let manifest = build_manifest(&settings)?;
            let status = load_status(&settings)?;
            generate_site(&settings, &manifest, &status)?;
            println!("Generated site at {}", settings.site_dir.display());
            Ok(())
        }
        Commands::RunOnce {
            changed_paths,
            no_deploy,
            skip_qmd,
        } => run_once(&settings, changed_paths.clone(), !no_deploy, *skip_qmd),
        Commands::Watch => watch(&settings),
        Commands::Status { json } => show_status(&settings, *json),
    }
}

fn preflight(settings: &Settings) -> Result<()> {
    log_line(settings, "INFO", "preflight started")?;
    println!("knowledge_root: {}", settings.knowledge_root.display());
    println!("site_name: {}", settings.site_name);
    println!("site_dir: {}", settings.site_dir.display());
    println!("state_dir: {}", settings.state_dir.display());
    println!("qmd: {}", settings.qmd_path.display());
    println!("quick: {}", settings.quick_path.display());

    let qmd_version = run_command(
        settings,
        &settings.qmd_path,
        &["--version"],
        Some(Duration::from_secs(30)),
    )?;
    print_command_result("qmd --version", &qmd_version);

    let quick_version = run_command(
        settings,
        &settings.quick_path,
        &["--version"],
        Some(Duration::from_secs(30)),
    )?;
    print_command_result("quick --version", &quick_version);

    let collections = run_command(
        settings,
        &settings.qmd_path,
        &["collection", "list"],
        Some(Duration::from_secs(60)),
    )?;
    print_command_result("qmd collection list", &collections);

    let broad = collections.stdout.contains("knowledge (qmd://knowledge/)")
        || collections
            .stdout
            .contains("/Users/paulo.casaretto/knowledge\n  Pattern:  **/*.md");
    if broad {
        println!("WARNING: possible broad qmd knowledge collection detected");
    } else {
        println!("No obvious broad qmd knowledge catch-all detected.");
    }

    let auth = run_command(
        settings,
        &settings.quick_path,
        &["auth", "print-identity-token"],
        Some(Duration::from_secs(60)),
    )?;
    if auth.success {
        println!("Quick auth: OK");
    } else {
        println!("Quick auth: FAILED");
        println!("{}", trim_for_log(&auth.stderr, 2000));
    }

    let remix_target = settings.tmp_dir.join("quick-site-check");
    let _ = fs::remove_dir_all(&remix_target);
    let remix_target_s = remix_target.to_string_lossy().to_string();
    let remix = run_command(
        settings,
        &settings.quick_path,
        &["remix", "--copy", &settings.site_name, &remix_target_s],
        Some(Duration::from_secs(120)),
    )?;
    if remix.success {
        println!("Quick site lookup: existing site is readable");
        let _ = fs::remove_dir_all(&remix_target);
    } else if remix.stderr.contains("not found") || remix.stdout.contains("not found") {
        println!("Quick site lookup: site not found yet; first deploy should create it if ownership is available");
    } else {
        println!("Quick site lookup failed:");
        println!("{}", trim_for_log(&(remix.stdout + &remix.stderr), 4000));
    }

    log_line(settings, "INFO", "preflight finished")?;
    Ok(())
}

fn print_command_result(label: &str, result: &CommandResult) {
    println!("--- {label} ---");
    println!(
        "success: {} exit: {:?} duration_ms: {}",
        result.success, result.exit_code, result.duration_ms
    );
    let out = trim_for_log(&result.stdout, 4000);
    let err = trim_for_log(&result.stderr, 4000);
    if !out.trim().is_empty() {
        println!("{out}");
    }
    if !err.trim().is_empty() {
        eprintln!("{err}");
    }
}

fn reconcile_qmd(settings: &Settings, verbose: bool) -> Result<()> {
    log_line(settings, "INFO", "qmd reconciliation started")?;
    let collections = publishable_collection_dirs(settings)?;
    let before = run_command(
        settings,
        &settings.qmd_path,
        &["collection", "list"],
        Some(Duration::from_secs(60)),
    )?;
    if !before.success {
        bail!("qmd collection list failed: {}", before.stderr);
    }
    for name in &collections {
        if qmd_collection_exists(&before.stdout, name) {
            if verbose {
                println!("qmd collection exists: {name}");
            }
            continue;
        }
        let path = settings.knowledge_root.join(name);
        let path_s = path.to_string_lossy().to_string();
        let result = run_command(
            settings,
            &settings.qmd_path,
            &[
                "collection",
                "add",
                &path_s,
                "--name",
                name,
                "--mask",
                "**/*.md",
            ],
            Some(Duration::from_secs(120)),
        )?;
        if result.success {
            log_line(settings, "INFO", &format!("added qmd collection {name}"))?;
            if verbose {
                println!("added qmd collection: {name}");
            }
        } else if result.stderr.contains("already exists")
            || result.stdout.contains("already exists")
        {
            log_line(
                settings,
                "INFO",
                &format!("qmd collection {name} already existed during add"),
            )?;
        } else {
            bail!(
                "failed to add qmd collection {name}: {}{}",
                result.stdout,
                result.stderr
            );
        }
    }
    let after = run_command(
        settings,
        &settings.qmd_path,
        &["collection", "list"],
        Some(Duration::from_secs(60)),
    )?;
    if verbose {
        println!("{}", after.stdout);
    }
    log_line(settings, "INFO", "qmd reconciliation finished")?;
    Ok(())
}

fn publishable_collection_dirs(settings: &Settings) -> Result<Vec<String>> {
    let mut names = BTreeSet::new();
    for entry in fs::read_dir(&settings.knowledge_root)
        .with_context(|| format!("reading {}", settings.knowledge_root.display()))?
    {
        let entry = entry?;
        if !entry.file_type()?.is_dir() {
            continue;
        }
        let name = entry.file_name();
        let Some(name) = name.to_str() else {
            continue;
        };
        if is_publishable_dir_name(name) {
            names.insert(name.to_string());
        }
    }
    Ok(names.into_iter().collect())
}

fn is_publishable_dir_name(name: &str) -> bool {
    !name.starts_with('.') && !BLOCKED_DIRS.contains(&name)
}

fn qmd_collection_exists(output: &str, name: &str) -> bool {
    output
        .lines()
        .any(|line| line.trim_start().starts_with(&format!("{name} ")))
}

fn run_once(
    settings: &Settings,
    changed_paths: Vec<PathBuf>,
    deploy: bool,
    skip_qmd: bool,
) -> Result<()> {
    let started = Instant::now();
    let started_at = now_string();
    log_line(
        settings,
        "INFO",
        &format!(
            "run-once started deploy={deploy} skip_qmd={skip_qmd} changed_paths={}",
            changed_paths.len()
        ),
    )?;

    let mut status = load_status(settings)?;
    status.overall_state = "running".to_string();
    status.last_run_started_at = Some(started_at.clone());
    status.last_run_finished_at = None;
    status.last_failure = None;
    status.last_warning = None;
    status.updated_at = Some(now_string());
    save_status(settings, &status)?;

    if !skip_qmd {
        reconcile_qmd(settings, false).context("reconciling qmd collections")?;
        let update = run_command(
            settings,
            &settings.qmd_path,
            &["update"],
            Some(Duration::from_secs(600)),
        )?;
        log_command(settings, "qmd update", &update)?;
        if !update.success {
            status.overall_state = "failed".to_string();
            status.last_failure = Some(format_command_failure("qmd update", &update));
            status.updated_at = Some(now_string());
            save_status(settings, &status)?;
            notify("Knowledge publisher qmd update failed", "action_needed");
            bail!("qmd update failed");
        }
        status.last_successful_qmd_update = Some(now_string());
        status.updated_at = Some(now_string());
        save_status(settings, &status)?;

        let collections = affected_qmd_collections(settings, &changed_paths)?;
        let mut embed_failed = false;
        let mut embed_failure = None;
        for collection in collections {
            let embed = run_command(
                settings,
                &settings.qmd_path,
                &[
                    "embed",
                    "-c",
                    &collection,
                    "--max-docs-per-batch",
                    "100",
                    "--max-batch-mb",
                    "20",
                ],
                Some(Duration::from_secs(1800)),
            )?;
            log_command(settings, &format!("qmd embed -c {collection}"), &embed)?;
            if !embed.success {
                embed_failed = true;
                embed_failure = Some(format_command_failure(
                    &format!("qmd embed -c {collection}"),
                    &embed,
                ));
                break;
            }
        }
        if embed_failed {
            status.stale_embeddings = true;
            status.last_warning = embed_failure
                .or_else(|| Some("qmd embed failed; deploying with stale embeddings".to_string()));
            notify(
                "Knowledge publisher qmd embed failed; deploying site with stale embeddings",
                "action_needed",
            );
        } else {
            status.stale_embeddings = false;
            status.last_successful_embed = Some(now_string());
        }
        status.updated_at = Some(now_string());
        save_status(settings, &status)?;
    }

    let manifest = build_manifest(settings)?;
    write_manifest(settings, &manifest, None)?;
    status.last_manifest_path = Some(settings.manifest_json_path());
    if let Some(warning) = manifest.warnings.first() {
        status.last_warning = Some(warning.clone());
    }
    status.updated_at = Some(now_string());
    save_status(settings, &status)?;

    let mut public_status = status.clone();
    public_status.last_successful_site_generation = Some(now_string());
    public_status.overall_state =
        if public_status.last_warning.is_some() || public_status.stale_embeddings {
            "warning".to_string()
        } else {
            "ok".to_string()
        };
    if let Err(err) = generate_site(settings, &manifest, &public_status) {
        status.overall_state = "failed".to_string();
        status.last_failure = Some(format!("site generation failed: {err:#}"));
        status.updated_at = Some(now_string());
        save_status(settings, &status)?;
        notify(
            "Knowledge publisher site generation failed",
            "action_needed",
        );
        return Err(err);
    }
    status.last_successful_site_generation = public_status.last_successful_site_generation;
    status.last_generated_site_dir = Some(settings.site_dir.clone());
    status.updated_at = Some(now_string());
    save_status(settings, &status)?;

    if deploy {
        let site_dir_s = settings.site_dir.to_string_lossy().to_string();
        let deploy_result = run_command(
            settings,
            &settings.quick_path,
            &["deploy", "--force", &site_dir_s, &settings.site_name],
            Some(Duration::from_secs(300)),
        )?;
        log_command(settings, "quick deploy", &deploy_result)?;
        if deploy_result.success {
            status.pending_deploy = false;
            status.action_required = false;
            status.deploy_failure_count = 0;
            status.next_deploy_retry_at = None;
            status.last_successful_quick_deploy = Some(now_string());
            status.last_deploy_url =
                Some(format!("https://{}.quick.shopify.io", settings.site_name));
        } else {
            handle_deploy_failure(settings, &mut status, &deploy_result)?;
            save_status(settings, &status)?;
            bail!("quick deploy failed");
        }
    }

    let elapsed = started.elapsed();
    if elapsed > Duration::from_secs(FRESHNESS_TARGET_SECS) {
        let warning = format!(
            "freshness target missed: run took {:.1}s (target {}s)",
            elapsed.as_secs_f64(),
            FRESHNESS_TARGET_SECS
        );
        log_line(settings, "WARN", &warning)?;
        notify(
            &format!(
                "Knowledge publisher slow run: {:.1}s",
                elapsed.as_secs_f64()
            ),
            "info",
        );
        status.last_warning = Some(warning);
    }

    if status.last_warning.is_some() || status.stale_embeddings {
        status.overall_state = "warning".to_string();
    } else {
        status.overall_state = "ok".to_string();
    }
    status.last_run_finished_at = Some(now_string());
    status.updated_at = Some(now_string());
    save_status(settings, &status)?;
    log_line(
        settings,
        "INFO",
        &format!("run-once finished in {:.1}s", elapsed.as_secs_f64()),
    )?;
    Ok(())
}

fn handle_deploy_failure(
    settings: &Settings,
    status: &mut Status,
    result: &CommandResult,
) -> Result<()> {
    let combined = format!("{}\n{}", result.stdout, result.stderr);
    status.pending_deploy = true;
    status.deploy_failure_count = status.deploy_failure_count.saturating_add(1);
    let delay = deploy_backoff_delay(status.deploy_failure_count);
    status.next_deploy_retry_at = Some(
        (Utc::now()
            + chrono::Duration::from_std(delay).unwrap_or_else(|_| chrono::Duration::minutes(15)))
        .to_rfc3339(),
    );
    status.last_failure = Some(format_command_failure("quick deploy", result));
    status.overall_state = "failed".to_string();

    if looks_like_auth_failure(&combined) {
        log_line(
            settings,
            "WARN",
            "quick deploy looked like auth failure; attempting quick auth",
        )?;
        let auth = run_command(
            settings,
            &settings.quick_path,
            &["auth"],
            Some(Duration::from_secs(180)),
        )?;
        log_command(settings, "quick auth", &auth)?;
        if auth.success {
            status.action_required = false;
            status.last_warning =
                Some("Quick auth refreshed; pending deploy will retry".to_string());
            notify(
                "Knowledge publisher refreshed Quick auth; deploy pending retry",
                "info",
            );
        } else {
            status.action_required = true;
            status.last_failure = Some(format_command_failure("quick auth", &auth));
            notify(
                "Knowledge publisher Quick auth failed; manual action required",
                "action_needed",
            );
        }
    } else {
        notify(
            "Knowledge publisher Quick deploy failed; pending retry recorded",
            "action_needed",
        );
    }
    Ok(())
}

fn deploy_backoff_delay(failures: u32) -> Duration {
    let exponent = failures.saturating_sub(1).min(5);
    let secs = 30_u64.saturating_mul(2_u64.pow(exponent));
    Duration::from_secs(secs.min(15 * 60))
}

fn looks_like_auth_failure(text: &str) -> bool {
    let lower = text.to_ascii_lowercase();
    lower.contains("auth")
        || lower.contains("unauthorized")
        || lower.contains("forbidden")
        || lower.contains("login")
        || lower.contains("credential")
}

fn affected_qmd_collections(settings: &Settings, changed_paths: &[PathBuf]) -> Result<Vec<String>> {
    if changed_paths.is_empty() {
        return publishable_collection_dirs(settings);
    }
    let mut set = BTreeSet::new();
    for path in changed_paths {
        let abs = if path.is_absolute() {
            path.clone()
        } else {
            settings.knowledge_root.join(path)
        };
        if let Ok(rel) = abs.strip_prefix(&settings.knowledge_root) {
            if let Some(collection) = publishable_collection_for_rel(rel) {
                set.insert(collection);
            }
        }
    }
    if set.is_empty() {
        publishable_collection_dirs(settings)
    } else {
        Ok(set.into_iter().collect())
    }
}

fn build_manifest(settings: &Settings) -> Result<Manifest> {
    let mut docs = Vec::new();
    let mut excluded = Vec::new();
    let mut warnings = Vec::new();

    for entry in WalkDir::new(&settings.knowledge_root)
        .follow_links(false)
        .into_iter()
        .filter_entry(|entry| should_descend(entry.path(), &settings.knowledge_root))
    {
        let entry = entry?;
        let path = entry.path();
        if !entry.file_type().is_file() {
            continue;
        }
        let rel = path.strip_prefix(&settings.knowledge_root)?.to_path_buf();
        if path.extension().and_then(OsStr::to_str) != Some("md") {
            continue;
        }
        match publish_decision(&rel) {
            PublishDecision::Include { collection } => {
                match read_source_doc(settings, path, rel.clone(), collection) {
                    Ok(doc) => docs.push(doc_to_manifest(doc)),
                    Err(err) => warnings.push(format!("failed to read {}: {err:#}", rel.display())),
                }
            }
            PublishDecision::Exclude { reason } => excluded.push(ExcludedPath {
                relative_path: rel,
                reason,
            }),
            PublishDecision::ReportOnly { reason } => {
                warnings.push(format!(
                    "unpublished markdown area: {} ({reason})",
                    rel.display()
                ));
                excluded.push(ExcludedPath {
                    relative_path: rel,
                    reason,
                });
            }
        }
    }

    docs.sort_by(|a, b| {
        b.modified
            .cmp(&a.modified)
            .then_with(|| a.relative_path.cmp(&b.relative_path))
    });

    Ok(Manifest {
        generated_at: now_string(),
        knowledge_root: settings.knowledge_root.clone(),
        site_name: settings.site_name.clone(),
        included_count: docs.len(),
        excluded_count: excluded.len(),
        documents: docs,
        excluded,
        warnings,
    })
}

fn should_descend(path: &Path, root: &Path) -> bool {
    if path == root {
        return true;
    }
    let Ok(rel) = path.strip_prefix(root) else {
        return true;
    };
    for component in rel.components() {
        if let Some(s) = component_to_str(component) {
            if s.starts_with('.') {
                return false;
            }
            if BLOCKED_DIRS.contains(&s) {
                return false;
            }
        }
    }
    true
}

#[derive(Debug)]
enum PublishDecision {
    Include { collection: String },
    Exclude { reason: String },
    ReportOnly { reason: String },
}

fn publish_decision(rel: &Path) -> PublishDecision {
    if rel.components().any(|c| {
        component_to_str(c)
            .map(|s| s.starts_with('.'))
            .unwrap_or(false)
    }) {
        return PublishDecision::Exclude {
            reason: "hidden path".to_string(),
        };
    }
    if rel.file_name().and_then(OsStr::to_str) == Some("AGENTS.md") {
        return PublishDecision::Exclude {
            reason: "operational AGENTS.md".to_string(),
        };
    }
    let components: Vec<_> = rel.components().filter_map(component_to_str).collect();
    if components.iter().any(|s| BLOCKED_DIRS.contains(s)) {
        return PublishDecision::Exclude {
            reason: "blocked folder".to_string(),
        };
    }
    let Some(collection) = publishable_collection_for_rel(rel) else {
        return PublishDecision::ReportOnly {
            reason: "top-level markdown is not in a publishable folder".to_string(),
        };
    };
    PublishDecision::Include { collection }
}

fn publishable_collection_for_rel(rel: &Path) -> Option<String> {
    let components = rel
        .components()
        .filter_map(component_to_str)
        .collect::<Vec<_>>();
    if components.len() < 2 {
        return None;
    }
    if components
        .iter()
        .any(|component| component.starts_with('.') || BLOCKED_DIRS.contains(component))
    {
        return None;
    }
    Some(components[0].to_string())
}

fn component_to_str(component: Component<'_>) -> Option<&str> {
    match component {
        Component::Normal(s) => s.to_str(),
        _ => None,
    }
}

fn read_source_doc(
    settings: &Settings,
    path: &Path,
    rel: PathBuf,
    collection: String,
) -> Result<SourceDoc> {
    let content =
        fs::read_to_string(path).with_context(|| format!("reading {}", path.display()))?;
    let mut warnings = Vec::new();
    let (metadata, body_with_summary) = parse_frontmatter(&content, &rel, &mut warnings);
    let title = derive_title(&metadata, &body_with_summary, &rel);
    let (summary_markdown, body) = split_fold_summary(&body_with_summary);
    let summary_markdown = summary_markdown
        .map(|summary| strip_leading_summary_title(&summary, &title))
        .filter(|summary| !summary.trim().is_empty());
    let summary_text = summary_markdown
        .as_deref()
        .map(plain_text_from_markdown)
        .filter(|s| !s.trim().is_empty());
    let file_meta = fs::metadata(path)?;
    let modified =
        system_time_to_rfc3339(file_meta.modified().unwrap_or_else(|_| SystemTime::now()));
    let output_url_path = output_url_for_rel(&rel);
    let output_file = output_file_for_rel(&settings.site_dir, &rel);
    Ok(SourceDoc {
        source_path: path.to_path_buf(),
        relative_path: rel,
        body,
        summary_markdown,
        summary_text,
        title,
        collection,
        modified,
        output_url_path,
        output_file,
        metadata,
        warnings,
    })
}

fn doc_to_manifest(doc: SourceDoc) -> ManifestDoc {
    ManifestDoc {
        source_path: doc.source_path,
        relative_path: doc.relative_path,
        title: doc.title,
        collection: doc.collection,
        modified: doc.modified,
        output_url_path: doc.output_url_path,
        output_file: doc.output_file,
        summary: doc.summary_text,
        metadata: doc.metadata,
        warnings: doc.warnings,
    }
}

fn parse_frontmatter(
    content: &str,
    rel: &Path,
    warnings: &mut Vec<String>,
) -> (BTreeMap<String, String>, String) {
    let Some(stripped) = content.strip_prefix("---") else {
        return (BTreeMap::new(), content.to_string());
    };
    if !(stripped.starts_with('\n') || stripped.starts_with("\r\n")) {
        return (BTreeMap::new(), content.to_string());
    }

    let mut offset = if stripped.starts_with("\r\n") { 5 } else { 4 };
    let bytes = content.as_bytes();
    let mut line_start = offset;
    while line_start <= content.len() {
        let line_end = content[line_start..]
            .find('\n')
            .map(|i| line_start + i)
            .unwrap_or(content.len());
        let line = content[line_start..line_end].trim_end_matches('\r');
        if line.trim() == "---" {
            let fm = &content[offset..line_start];
            let body_start = if line_end < content.len() {
                line_end + 1
            } else {
                line_end
            };
            let body = content[body_start..].to_string();
            match serde_yaml::from_str::<YamlValue>(fm) {
                Ok(value) => return (frontmatter_map(value), body),
                Err(err) => {
                    warnings.push(format!("malformed frontmatter in {}: {err}", rel.display()));
                    return (BTreeMap::new(), body);
                }
            }
        }
        if line_end >= content.len() {
            break;
        }
        line_start = line_end + 1;
        offset = offset.min(bytes.len());
    }
    warnings.push(format!(
        "unterminated frontmatter in {}; rendering whole body",
        rel.display()
    ));
    (BTreeMap::new(), content.to_string())
}

fn split_fold_summary(body: &str) -> (Option<String>, String) {
    for marker in ["<!--more-->", "<!-- more -->"] {
        if let Some(index) = body.find(marker) {
            let summary = body[..index].trim().to_string();
            let rest = body[index + marker.len()..]
                .trim_start_matches(['\r', '\n'])
                .to_string();
            return (
                if summary.is_empty() {
                    None
                } else {
                    Some(summary)
                },
                rest,
            );
        }
    }
    (None, body.to_string())
}

fn plain_text_from_markdown(markdown: &str) -> String {
    let mut out = String::new();
    for event in MarkdownParser::new_ext(markdown, markdown_options()) {
        match event {
            Event::Text(text) | Event::Code(text) => {
                if !out.is_empty() && !out.ends_with(char::is_whitespace) {
                    out.push(' ');
                }
                out.push_str(text.as_ref());
            }
            Event::SoftBreak | Event::HardBreak => out.push(' '),
            _ => {}
        }
    }
    out.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn normalized_inline_text(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn strip_leading_summary_title(summary: &str, title: &str) -> String {
    let lines = summary.lines().collect::<Vec<_>>();
    let Some(first_content_index) = lines.iter().position(|line| !line.trim().is_empty()) else {
        return String::new();
    };

    let first_line = lines[first_content_index].trim_start();
    let Some(_) = first_line.strip_prefix("# ") else {
        return summary.trim().to_string();
    };

    let candidate = plain_text_from_markdown(first_line);
    if normalized_inline_text(&candidate) != normalized_inline_text(title) {
        return summary.trim().to_string();
    }

    let mut body_start = first_content_index + 1;
    while body_start < lines.len() && lines[body_start].trim().is_empty() {
        body_start += 1;
    }
    lines[body_start..].join("\n").trim().to_string()
}

fn frontmatter_map(value: YamlValue) -> BTreeMap<String, String> {
    let mut out = BTreeMap::new();
    let YamlValue::Mapping(map) = value else {
        return out;
    };
    for key in FRONTMATTER_ALLOWLIST {
        if let Some(value) = map.get(YamlValue::String((*key).to_string())) {
            if let Some(s) = yaml_scalar_to_string(value) {
                out.insert((*key).to_string(), s);
            }
        }
    }
    out
}

fn yaml_scalar_to_string(value: &YamlValue) -> Option<String> {
    match value {
        YamlValue::String(s) => Some(s.clone()),
        YamlValue::Number(n) => Some(n.to_string()),
        YamlValue::Bool(b) => Some(b.to_string()),
        YamlValue::Null => None,
        _ => serde_yaml::to_string(value)
            .ok()
            .map(|s| s.trim().replace('\n', " ")),
    }
}

fn derive_title(metadata: &BTreeMap<String, String>, body: &str, rel: &Path) -> String {
    if let Some(title) = metadata.get("title").filter(|s| !s.trim().is_empty()) {
        return title.trim().to_string();
    }

    let mut current_h1: Option<String> = None;
    for event in MarkdownParser::new_ext(body, markdown_options()) {
        match event {
            Event::Start(Tag::Heading { level, .. }) if matches!(level, HeadingLevel::H1) => {
                current_h1 = Some(String::new());
            }
            Event::Text(text) | Event::Code(text) => {
                if let Some(title) = &mut current_h1 {
                    if !title.is_empty() && !title.ends_with(char::is_whitespace) {
                        title.push(' ');
                    }
                    title.push_str(text.as_ref());
                }
            }
            Event::SoftBreak | Event::HardBreak => {
                if let Some(title) = &mut current_h1 {
                    title.push(' ');
                }
            }
            Event::End(TagEnd::Heading(level)) if matches!(level, HeadingLevel::H1) => {
                if let Some(title) = current_h1.take() {
                    let title = normalized_inline_text(&title);
                    if !title.is_empty() {
                        return title;
                    }
                }
            }
            _ => {}
        }
    }

    rel.file_stem()
        .and_then(OsStr::to_str)
        .map(|s| s.replace('-', " ").replace('_', " "))
        .unwrap_or_else(|| "Untitled".to_string())
}

fn output_url_for_rel(rel: &Path) -> String {
    let mut parts = Vec::new();
    for component in rel.components().filter_map(component_to_str) {
        let mut piece = component.to_string();
        if piece.ends_with(".md") {
            piece.truncate(piece.len() - 3);
        }
        parts.push(url_segment(&piece));
    }
    format!("/docs/{}/", parts.join("/"))
}

fn output_file_for_rel(site_dir: &Path, rel: &Path) -> PathBuf {
    let mut out = site_dir.join("docs");
    for component in rel.components().filter_map(component_to_str) {
        let mut piece = component.to_string();
        if piece.ends_with(".md") {
            piece.truncate(piece.len() - 3);
        }
        out.push(url_segment(&piece));
    }
    out.join("index.html")
}

fn url_segment(input: &str) -> String {
    let mut out = String::new();
    for ch in input.chars() {
        if ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_' | '.') {
            out.push(ch);
        } else if ch.is_whitespace() {
            out.push('-');
        } else {
            out.push('-');
        }
    }
    let trimmed = out.trim_matches('-');
    if trimmed.is_empty() {
        "untitled".to_string()
    } else {
        trimmed.to_ascii_lowercase()
    }
}

fn write_manifest(
    settings: &Settings,
    manifest: &Manifest,
    explicit_output: Option<PathBuf>,
) -> Result<()> {
    let json_path = explicit_output.unwrap_or_else(|| settings.manifest_json_path());
    if let Some(parent) = json_path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(&json_path, serde_json::to_string_pretty(manifest)?)
        .with_context(|| format!("writing {}", json_path.display()))?;
    if json_path == settings.manifest_json_path() {
        fs::write(settings.manifest_md_path(), manifest_markdown(manifest)?)?;
    }
    log_line(
        settings,
        "INFO",
        &format!(
            "wrote manifest: {} included, {} excluded",
            manifest.included_count, manifest.excluded_count
        ),
    )?;
    Ok(())
}

fn manifest_markdown(manifest: &Manifest) -> Result<String> {
    let mut out = String::new();
    out.push_str("# Knowledge publish manifest\n\n");
    out.push_str(&format!("Generated: {}\n\n", manifest.generated_at));
    out.push_str(&format!("Included: {}\n\n", manifest.included_count));
    out.push_str(&format!("Excluded: {}\n\n", manifest.excluded_count));
    if !manifest.warnings.is_empty() {
        out.push_str("## Warnings\n\n");
        for warning in &manifest.warnings {
            out.push_str(&format!("- {}\n", warning));
        }
        out.push('\n');
    }
    out.push_str("## Published documents\n\n");
    out.push_str("| Modified | Collection | Title | Source | URL |\n");
    out.push_str("|---|---|---|---|---|\n");
    for doc in &manifest.documents {
        out.push_str(&format!(
            "| {} | {} | {} | `{}` | `{}` |\n",
            doc.modified,
            doc.collection,
            doc.title.replace('|', "\\|"),
            doc.relative_path.display(),
            doc.output_url_path
        ));
    }
    out.push_str("\n## Excluded markdown\n\n");
    for excluded in &manifest.excluded {
        out.push_str(&format!(
            "- `{}` — {}\n",
            excluded.relative_path.display(),
            excluded.reason
        ));
    }
    Ok(out)
}

fn print_manifest_summary(manifest: &Manifest) {
    println!("Manifest generated at {}", manifest.generated_at);
    println!("Included: {}", manifest.included_count);
    println!("Excluded: {}", manifest.excluded_count);
    if !manifest.warnings.is_empty() {
        println!("Warnings:");
        for warning in &manifest.warnings {
            println!("- {warning}");
        }
    }
}

fn generate_site(settings: &Settings, manifest: &Manifest, status: &Status) -> Result<()> {
    log_line(settings, "INFO", "site generation started")?;
    if settings.site_dir.exists() {
        fs::remove_dir_all(&settings.site_dir)
            .with_context(|| format!("cleaning {}", settings.site_dir.display()))?;
    }
    fs::create_dir_all(&settings.site_dir)?;
    fs::create_dir_all(settings.site_dir.join("assets"))?;
    write_assets(settings)?;

    let docs = load_docs_for_manifest(settings, manifest)?;
    let link_map: HashMap<PathBuf, String> = docs
        .iter()
        .map(|doc| {
            (
                normalize_rel_path(&doc.relative_path),
                doc.output_url_path.clone(),
            )
        })
        .collect();

    let mut by_collection: BTreeMap<String, Vec<&SourceDoc>> = BTreeMap::new();
    for doc in &docs {
        by_collection
            .entry(doc.collection.clone())
            .or_default()
            .push(doc);
    }
    for docs in by_collection.values_mut() {
        docs.sort_by(|a, b| {
            b.modified
                .cmp(&a.modified)
                .then_with(|| a.relative_path.cmp(&b.relative_path))
        });
    }

    let site_base_url = site_base_url(settings);
    let mut site_warnings = manifest.warnings.clone();
    for doc in &docs {
        let mut warnings = doc.warnings.clone();
        let headings = collect_toc(&doc.body);
        let summary_html = doc.summary_markdown.as_deref().map(|summary| {
            render_markdown(
                summary,
                &doc.relative_path,
                &link_map,
                &mut warnings,
                None,
                &site_base_url,
            )
        });
        let body_html = render_markdown(
            &doc.body,
            &doc.relative_path,
            &link_map,
            &mut warnings,
            Some(&headings),
            &site_base_url,
        );
        site_warnings.extend(warnings.iter().cloned());
        let page = document_page(
            settings,
            doc,
            summary_html.as_deref(),
            &body_html,
            &headings,
            &warnings,
            &link_map,
            &site_base_url,
        )?;
        write_page(&doc.output_file, &page)?;
    }

    let home = home_page(settings, &docs, &by_collection, status)?;
    write_page(&settings.site_dir.join("index.html"), &home)?;

    for (collection, collection_docs) in &by_collection {
        let page = collection_page(settings, collection, collection_docs)?;
        write_page(
            &settings
                .site_dir
                .join("collections")
                .join(url_segment(collection))
                .join("index.html"),
            &page,
        )?;
    }

    let status_page = status_page(settings, status)?;
    write_page(
        &settings.site_dir.join("status").join("index.html"),
        &status_page,
    )?;

    let not_found = layout(settings, "Not found", "404", "<section class=\"card\"><h1>Not found</h1><p>The requested page was not found. Deleted or renamed knowledge pages intentionally disappear in this version.</p><p><a href=\"/\">Back to home</a></p></section>");
    write_page(&settings.site_dir.join("404.html"), &not_found)?;

    if !site_warnings.is_empty() {
        let warnings_path = settings.state_dir.join("site-warnings.log");
        fs::write(&warnings_path, site_warnings.join("\n"))?;
        log_line(
            settings,
            "WARN",
            &format!(
                "site generated with {} warnings; see {}",
                site_warnings.len(),
                warnings_path.display()
            ),
        )?;
    }
    log_line(settings, "INFO", "site generation finished")?;
    Ok(())
}

fn load_docs_for_manifest(settings: &Settings, manifest: &Manifest) -> Result<Vec<SourceDoc>> {
    let mut docs = Vec::new();
    for item in &manifest.documents {
        let content = fs::read_to_string(&item.source_path)
            .with_context(|| format!("reading {}", item.source_path.display()))?;
        let mut warnings = Vec::new();
        let (_metadata, body_with_summary) =
            parse_frontmatter(&content, &item.relative_path, &mut warnings);
        let (summary_markdown, body) = split_fold_summary(&body_with_summary);
        let summary_markdown = summary_markdown
            .map(|summary| strip_leading_summary_title(&summary, &item.title))
            .filter(|summary| !summary.trim().is_empty());
        let summary_text = summary_markdown
            .as_deref()
            .map(plain_text_from_markdown)
            .filter(|s| !s.trim().is_empty())
            .or_else(|| item.summary.clone());
        warnings.extend(item.warnings.clone());
        docs.push(SourceDoc {
            source_path: item.source_path.clone(),
            relative_path: item.relative_path.clone(),
            body,
            summary_markdown,
            summary_text,
            title: item.title.clone(),
            collection: item.collection.clone(),
            modified: item.modified.clone(),
            output_url_path: item.output_url_path.clone(),
            output_file: item.output_file.clone(),
            metadata: item.metadata.clone(),
            warnings,
        });
    }
    let _ = settings;
    Ok(docs)
}

fn markdown_options() -> Options {
    let mut options = Options::empty();
    options.insert(Options::ENABLE_TABLES);
    options.insert(Options::ENABLE_FOOTNOTES);
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_TASKLISTS);
    options.insert(Options::ENABLE_SMART_PUNCTUATION);
    options.insert(Options::ENABLE_HEADING_ATTRIBUTES);
    options
}

fn collect_toc(body: &str) -> Vec<TocItem> {
    let mut headings = Vec::new();
    let mut current: Option<(HeadingLevel, Option<String>, String)> = None;
    let mut used = HashMap::<String, usize>::new();

    for event in MarkdownParser::new_ext(body, markdown_options()) {
        match event {
            Event::Start(Tag::Heading { level, id, .. }) => {
                current = Some((
                    level,
                    id.map(|id| id.trim_start_matches('#').to_string()),
                    String::new(),
                ));
            }
            Event::Text(text) | Event::Code(text) => {
                if let Some((_, _, title)) = &mut current {
                    if !title.is_empty() && !title.ends_with(char::is_whitespace) {
                        title.push(' ');
                    }
                    title.push_str(text.as_ref());
                }
            }
            Event::SoftBreak | Event::HardBreak => {
                if let Some((_, _, title)) = &mut current {
                    title.push(' ');
                }
            }
            Event::End(TagEnd::Heading(level)) => {
                if let Some((start_level, explicit_id, title)) = current.take() {
                    let level = if heading_level_number(start_level) == heading_level_number(level)
                    {
                        start_level
                    } else {
                        level
                    };
                    let title = title.split_whitespace().collect::<Vec<_>>().join(" ");
                    if !title.is_empty() {
                        let base = explicit_id.unwrap_or_else(|| slugify_heading(&title));
                        let id = unique_heading_id(&base, &mut used);
                        headings.push(TocItem {
                            level: heading_level_number(level),
                            title,
                            id,
                        });
                    }
                }
            }
            _ => {}
        }
    }
    headings
}

fn render_markdown(
    body: &str,
    source_rel: &Path,
    link_map: &HashMap<PathBuf, String>,
    warnings: &mut Vec<String>,
    headings: Option<&[TocItem]>,
    site_base_url: &str,
) -> String {
    let mut heading_ids = headings
        .map(|items| items.iter().map(|item| item.id.clone()).collect::<Vec<_>>())
        .unwrap_or_default()
        .into_iter();
    let mut in_code_block = false;
    let mut in_link = false;

    let parser = MarkdownParser::new_ext(body, markdown_options()).map(|event| match event {
        Event::Start(Tag::Link {
            link_type,
            dest_url,
            title,
            id,
        }) => {
            in_link = true;
            let rewritten = rewrite_markdown_link(
                source_rel,
                dest_url.as_ref(),
                link_map,
                warnings,
                site_base_url,
            );
            Event::Start(Tag::Link {
                link_type,
                dest_url: rewritten
                    .map(|s| CowStr::Boxed(s.into_boxed_str()))
                    .unwrap_or(dest_url),
                title,
                id,
            })
        }
        Event::End(TagEnd::Link) => {
            in_link = false;
            Event::End(TagEnd::Link)
        }
        Event::Start(Tag::CodeBlock(kind)) => {
            in_code_block = true;
            Event::Start(Tag::CodeBlock(kind))
        }
        Event::End(TagEnd::CodeBlock) => {
            in_code_block = false;
            Event::End(TagEnd::CodeBlock)
        }
        Event::Start(Tag::Heading {
            level,
            id,
            classes,
            attrs,
        }) => {
            let generated_id = heading_ids.next();
            Event::Start(Tag::Heading {
                level,
                id: id.or_else(|| generated_id.map(|id| CowStr::Boxed(id.into_boxed_str()))),
                classes,
                attrs,
            })
        }
        Event::Text(text) if !in_code_block && !in_link => {
            rewrite_knowledge_paths_to_html(text.as_ref(), link_map, site_base_url)
                .map(|html| Event::Html(CowStr::Boxed(html.into_boxed_str())))
                .unwrap_or(Event::Text(text))
        }
        Event::Code(text) if !in_link => {
            rewrite_knowledge_paths_to_code_html(text.as_ref(), link_map, site_base_url)
                .map(|html| Event::Html(CowStr::Boxed(html.into_boxed_str())))
                .unwrap_or(Event::Code(text))
        }
        other => other,
    });

    let mut unsafe_html = String::new();
    html::push_html(&mut unsafe_html, parser);
    sanitize_body_html(&unsafe_html)
}

fn heading_level_number(level: HeadingLevel) -> u8 {
    match level {
        HeadingLevel::H1 => 1,
        HeadingLevel::H2 => 2,
        HeadingLevel::H3 => 3,
        HeadingLevel::H4 => 4,
        HeadingLevel::H5 => 5,
        HeadingLevel::H6 => 6,
    }
}

fn slugify_heading(title: &str) -> String {
    let mut out = String::new();
    let mut last_dash = false;
    for ch in title.chars().flat_map(char::to_lowercase) {
        if ch.is_ascii_alphanumeric() {
            out.push(ch);
            last_dash = false;
        } else if (ch.is_whitespace() || matches!(ch, '-' | '_' | '/' | ':' | '.')) && !last_dash {
            out.push('-');
            last_dash = true;
        }
    }
    let trimmed = out.trim_matches('-');
    if trimmed.is_empty() {
        "section".to_string()
    } else {
        trimmed.to_string()
    }
}

fn unique_heading_id(base: &str, used: &mut HashMap<String, usize>) -> String {
    let count = used.entry(base.to_string()).or_insert(0);
    *count += 1;
    if *count == 1 {
        base.to_string()
    } else {
        format!("{base}-{}", *count)
    }
}

fn toc_html(headings: &[TocItem]) -> String {
    let visible = headings
        .iter()
        .filter(|item| (2..=3).contains(&item.level))
        .collect::<Vec<_>>();
    if visible.is_empty() {
        return String::new();
    }
    let mut html = String::from(
        "<nav class=\"toc\" aria-label=\"Table of contents\"><p class=\"toc__title\">Table of contents</p><ul class=\"toc__list\">",
    );
    for item in visible {
        html.push_str(&format!(
            "<li class=\"toc__item toc__item--h{}\"><a href=\"#{}\">{}</a></li>",
            item.level,
            encode_double_quoted_attribute(&item.id),
            encode_text(&item.title)
        ));
    }
    html.push_str("</ul></nav>");
    html
}

fn site_base_url(settings: &Settings) -> String {
    format!("https://{}.quick.shopify.io", settings.site_name)
}

fn knowledge_ref_to_site_url(
    input: &str,
    link_map: &HashMap<PathBuf, String>,
    site_base_url: &str,
) -> Option<String> {
    let input = input.strip_prefix("file://").unwrap_or(input);
    let (without_fragment, fragment) = match input.split_once('#') {
        Some((path, frag)) => (path, Some(frag)),
        None => (input, None),
    };
    let (path_part, query) = match without_fragment.split_once('?') {
        Some((path, q)) => (path, Some(q)),
        None => (without_fragment, None),
    };
    let rel = if let Some(rest) = path_part.strip_prefix("~/knowledge/") {
        rest
    } else if let Some(rest) = path_part.strip_prefix("/Users/paulo.casaretto/knowledge/") {
        rest
    } else {
        return None;
    };
    let normalized = normalize_rel_path(Path::new(rel));
    let output_url_path = link_map.get(&normalized)?;
    let mut out = format!("{site_base_url}{output_url_path}");
    if let Some(q) = query {
        out.push('?');
        out.push_str(q);
    }
    if let Some(frag) = fragment {
        out.push('#');
        out.push_str(frag);
    }
    Some(out)
}

fn render_metadata_value(
    value: &str,
    link_map: &HashMap<PathBuf, String>,
    site_base_url: &str,
) -> String {
    rewrite_knowledge_paths_to_html(value, link_map, site_base_url)
        .unwrap_or_else(|| encode_text(value).to_string())
}

fn rewrite_knowledge_paths_to_text(
    input: &str,
    link_map: &HashMap<PathBuf, String>,
    site_base_url: &str,
) -> Option<String> {
    rewrite_knowledge_paths(
        input,
        link_map,
        site_base_url,
        |text| text.to_string(),
        |url| url.to_string(),
    )
}

fn rewrite_knowledge_paths_to_html(
    input: &str,
    link_map: &HashMap<PathBuf, String>,
    site_base_url: &str,
) -> Option<String> {
    rewrite_knowledge_paths(
        input,
        link_map,
        site_base_url,
        |text| encode_text(text).to_string(),
        |url| {
            format!(
                "<a class=\"knowledge-path\" href=\"{}\">{}</a>",
                encode_double_quoted_attribute(url),
                encode_text(url)
            )
        },
    )
}

fn rewrite_knowledge_paths_to_code_html(
    input: &str,
    link_map: &HashMap<PathBuf, String>,
    site_base_url: &str,
) -> Option<String> {
    rewrite_knowledge_paths(
        input,
        link_map,
        site_base_url,
        |text| format!("<code>{}</code>", encode_text(text)),
        |url| {
            format!(
                "<a class=\"knowledge-path\" href=\"{}\"><code>{}</code></a>",
                encode_double_quoted_attribute(url),
                encode_text(url)
            )
        },
    )
}

fn rewrite_knowledge_paths<T, U>(
    input: &str,
    link_map: &HashMap<PathBuf, String>,
    site_base_url: &str,
    render_text: T,
    render_url: U,
) -> Option<String>
where
    T: Fn(&str) -> String,
    U: Fn(&str) -> String,
{
    let mut output = String::new();
    let mut cursor = 0;
    let mut changed = false;

    while let Some((start, prefix)) = find_next_knowledge_prefix(input, cursor) {
        let search_start = start + prefix.len();
        let Some(md_offset) = input[search_start..].find(".md") else {
            break;
        };
        let path_end = search_start + md_offset + 3;
        let candidate_end = extend_local_markdown_ref(input, path_end);
        let candidate = &input[start..candidate_end];
        let prefix_text = &input[cursor..start];
        if !prefix_text.is_empty() {
            output.push_str(&render_text(prefix_text));
        }
        if let Some(url) = knowledge_ref_to_site_url(candidate, link_map, site_base_url) {
            output.push_str(&render_url(&url));
            changed = true;
        } else {
            output.push_str(&render_text(candidate));
        }
        cursor = candidate_end;
    }

    if !changed {
        return None;
    }
    let suffix_text = &input[cursor..];
    if !suffix_text.is_empty() {
        output.push_str(&render_text(suffix_text));
    }
    Some(output)
}

fn find_next_knowledge_prefix(input: &str, start: usize) -> Option<(usize, &'static str)> {
    [
        "file:///Users/paulo.casaretto/knowledge/",
        "/Users/paulo.casaretto/knowledge/",
        "~/knowledge/",
    ]
    .into_iter()
    .filter_map(|prefix| {
        input[start..]
            .find(prefix)
            .map(|offset| (start + offset, prefix))
    })
    .min_by_key(|(index, _)| *index)
}

fn extend_local_markdown_ref(input: &str, path_end: usize) -> usize {
    let Some(first) = input[path_end..].chars().next() else {
        return path_end;
    };
    if !matches!(first, '#' | '?') {
        return path_end;
    }
    let mut end = path_end;
    for (offset, ch) in input[path_end..].char_indices() {
        if offset > 0 && is_local_ref_delimiter(ch) {
            break;
        }
        end = path_end + offset + ch.len_utf8();
    }
    end
}

fn is_local_ref_delimiter(ch: char) -> bool {
    ch.is_whitespace() || matches!(ch, ')' | ']' | '}' | '"' | '\'' | '<' | '>' | '`')
}

fn rewrite_markdown_link(
    source_rel: &Path,
    dest: &str,
    link_map: &HashMap<PathBuf, String>,
    warnings: &mut Vec<String>,
    site_base_url: &str,
) -> Option<String> {
    if let Some(url) = knowledge_ref_to_site_url(dest, link_map, site_base_url) {
        return Some(url);
    }
    if dest.is_empty()
        || dest.starts_with('#')
        || dest.starts_with('/')
        || dest.contains("://")
        || dest.starts_with("mailto:")
        || dest.starts_with("qmd://")
    {
        return None;
    }
    let (without_fragment, fragment) = match dest.split_once('#') {
        Some((path, frag)) => (path, Some(frag)),
        None => (dest, None),
    };
    let (path_part, query) = match without_fragment.split_once('?') {
        Some((path, q)) => (path, Some(q)),
        None => (without_fragment, None),
    };
    let target = Path::new(path_part);
    if target.extension().and_then(OsStr::to_str) != Some("md") {
        return None;
    }
    let base = source_rel.parent().unwrap_or_else(|| Path::new(""));
    let normalized = normalize_rel_path(&base.join(target));
    if let Some(url) = link_map.get(&normalized) {
        let mut out = url.clone();
        if let Some(q) = query {
            out.push('?');
            out.push_str(q);
        }
        if let Some(frag) = fragment {
            out.push('#');
            out.push_str(frag);
        }
        Some(out)
    } else {
        warnings.push(format!(
            "relative markdown link not published from {} to {}",
            source_rel.display(),
            dest
        ));
        None
    }
}

fn normalize_rel_path(path: &Path) -> PathBuf {
    let mut out = PathBuf::new();
    for component in path.components() {
        match component {
            Component::CurDir => {}
            Component::ParentDir => {
                out.pop();
            }
            Component::Normal(s) => out.push(s),
            _ => {}
        }
    }
    out
}

fn sanitize_body_html(input: &str) -> String {
    let mut builder = ammonia::Builder::default();
    builder.add_generic_attributes(["class", "id"]);
    builder.add_tags(["input"]);
    builder.add_tag_attributes("input", ["type", "checked", "disabled"]);
    builder.clean(input).to_string()
}

fn write_assets(settings: &Settings) -> Result<()> {
    fs::write(settings.site_dir.join("assets/site.css"), SITE_CSS)?;
    fs::write(settings.site_dir.join("assets/site.js"), SITE_JS)?;
    Ok(())
}

fn document_page(
    settings: &Settings,
    doc: &SourceDoc,
    summary_html: Option<&str>,
    body_html: &str,
    headings: &[TocItem],
    warnings: &[String],
    link_map: &HashMap<PathBuf, String>,
    site_base_url: &str,
) -> Result<String> {
    let breadcrumbs = breadcrumbs(doc);
    let mut meta = String::new();
    meta.push_str("<dl class=\"metadata\">");
    meta.push_str(&format!(
        "<div><dt>Last modified</dt><dd>{}</dd></div>",
        encode_text(&doc.modified)
    ));
    meta.push_str(&format!(
        "<div><dt>Collection</dt><dd><span class=\"badge\">{}</span></dd></div>",
        encode_text(&doc.collection)
    ));
    for (key, value) in &doc.metadata {
        meta.push_str(&format!(
            "<div><dt>{}</dt><dd>{}</dd></div>",
            encode_text(key),
            render_metadata_value(value, link_map, site_base_url)
        ));
    }
    meta.push_str("</dl>");

    let mut warning_html = String::new();
    if !warnings.is_empty() {
        warning_html.push_str(
            "<details class=\"local-warning\"><summary>Local rendering warnings</summary><ul>",
        );
        for warning in warnings {
            warning_html.push_str(&format!("<li>{}</li>", encode_text(warning)));
        }
        warning_html.push_str("</ul></details>");
    }

    let summary = summary_html
        .map(|html| format!("<div class=\"lede prose\">{html}</div>"))
        .unwrap_or_default();
    let toc = toc_html(headings);

    let content = format!(
        "<nav class=\"breadcrumbs\">{breadcrumbs}</nav><article class=\"doc document\"><header class=\"doc__header\"><p class=\"eyebrow\">{collection}</p><h1>{title}</h1></header><div class=\"doc__layout\"><div class=\"doc__main\">{summary}{toc}{warning_html}<div class=\"markdown prose\">{body_html}</div></div><aside class=\"doc__sidebar\" aria-label=\"Document metadata\"><section class=\"doc__side-block\"><h2>Details</h2>{meta}</section></aside></div></article>",
        collection = encode_text(&doc.collection),
        title = encode_text(&doc.title),
    );
    Ok(layout(settings, &doc.title, &doc.collection, &content))
}

fn breadcrumbs(doc: &SourceDoc) -> String {
    let mut parts = vec!["<a href=\"/\">Home</a>".to_string()];
    parts.push(format!(
        "<a href=\"/collections/{}/\">{}</a>",
        encode_double_quoted_attribute(&url_segment(&doc.collection)),
        encode_text(&doc.collection)
    ));
    parts.push(encode_text(&doc.title).to_string());
    parts.join("<span aria-hidden=\"true\">/</span>")
}

fn home_page(
    settings: &Settings,
    docs: &[SourceDoc],
    by_collection: &BTreeMap<String, Vec<&SourceDoc>>,
    status: &Status,
) -> Result<String> {
    let recent = docs.iter().take(28).collect::<Vec<_>>();
    let mut body = String::new();
    body.push_str("<section class=\"hero\" aria-labelledby=\"home-title\"><div class=\"hero__body\"><p class=\"eyebrow hero__eyebrow\">Local field notes</p><h1 id=\"home-title\">Knowledge Office</h1><p class=\"hero__subtitle\">Published markdown from ~/knowledge, organized by folder.</p></div></section>");
    body.push_str("<section id=\"recent\" class=\"section-head\"><p class=\"eyebrow\">Dispatches</p><h2>Recent documents</h2><p>The newest published markdown, newest first.</p></section><section class=\"box recent-box\"><div class=\"box__body\">");
    body.push_str(&doc_list(&recent));
    body.push_str("</div></section>");
    body.push_str("<section id=\"collections\" class=\"section-head\"><p class=\"eyebrow\">Shelves</p><h2>Collections</h2><p>Browsable knowledge areas, sorted by recent changes and published from the approved content contract.</p></section>");
    body.push_str(
        "<section class=\"cards-grid collection-grid\" aria-label=\"Knowledge collections\">",
    );
    for (collection, collection_docs) in by_collection {
        let latest = collection_docs
            .iter()
            .map(|doc| doc.modified.as_str())
            .max()
            .unwrap_or("never");
        body.push_str(&format!(
            "<a class=\"card collection-card\" href=\"/collections/{}/\"><span class=\"card__band\"><span class=\"card__band-label\">Collection</span><span>{} docs</span></span><span class=\"card__body\"><span class=\"card__title\">{}</span><span class=\"card__teaser\">Latest update: {}</span><span class=\"card__footer\"><span>Open shelf</span></span></span></a>",
            encode_double_quoted_attribute(&url_segment(collection)),
            collection_docs.len(),
            encode_text(collection),
            encode_text(latest),
        ));
    }
    body.push_str("</section>");
    body.push_str("<section class=\"box status-box\"><div class=\"box__header\">Publisher status</div><div class=\"box__body\">");
    body.push_str(&public_status_summary(status));
    body.push_str(
        "<p><a class=\"button-link\" href=\"/status/\">View status page</a></p></div></section>",
    );
    Ok(layout(settings, "Knowledge Office", "Home", &body))
}

fn collection_page(settings: &Settings, collection: &str, docs: &[&SourceDoc]) -> Result<String> {
    let mut body = String::new();
    body.push_str(&format!(
        "<nav class=\"breadcrumbs\"><a href=\"/\">Home</a><span aria-hidden=\"true\">/</span>{}</nav>",
        encode_text(collection)
    ));
    body.push_str(&format!(
        "<section class=\"section-head collection-head\"><p class=\"eyebrow\">Collection</p><h1>{}</h1><p>{} document{}</p></section><section class=\"box recent-box\"><div class=\"box__body\">",
        encode_text(collection),
        docs.len(),
        if docs.len() == 1 { "" } else { "s" }
    ));
    body.push_str(&doc_list(docs));
    body.push_str("</div></section>");
    Ok(layout(settings, collection, collection, &body))
}

fn status_page(settings: &Settings, status: &Status) -> Result<String> {
    let mut body = String::new();
    body.push_str("<article class=\"doc doc--solo\"><header class=\"doc__header\"><p class=\"eyebrow\">Operations</p><h1>Publisher status</h1><p class=\"subtitle\">This page intentionally shows only high-level, non-sensitive state. Detailed warnings and failures stay in local logs.</p></header><section class=\"box\"><div class=\"box__header\">Public status</div><div class=\"box__body\">");
    body.push_str(&public_status_summary(status));
    body.push_str(&format!(
        "<p class=\"muted\">Status page generated at {}</p>",
        encode_text(&now_string())
    ));
    body.push_str("</div></section></article>");
    Ok(layout(settings, "Publisher status", "Status", &body))
}

fn public_status_summary(status: &Status) -> String {
    let rows = [
        ("Overall state", Some(status.overall_state.as_str())),
        (
            "Last qmd update",
            status.last_successful_qmd_update.as_deref(),
        ),
        (
            "Last embedding refresh",
            status.last_successful_embed.as_deref(),
        ),
        (
            "Last site generation",
            status.last_successful_site_generation.as_deref(),
        ),
        (
            "Last Quick deploy",
            status.last_successful_quick_deploy.as_deref(),
        ),
        (
            "Pending deploy",
            Some(if status.pending_deploy { "yes" } else { "no" }),
        ),
        (
            "Stale embeddings",
            Some(if status.stale_embeddings { "yes" } else { "no" }),
        ),
        (
            "Action required",
            Some(if status.action_required { "yes" } else { "no" }),
        ),
    ];
    let mut html = String::from("<dl class=\"status-list\">");
    for (key, value) in rows {
        html.push_str(&format!(
            "<div><dt>{}</dt><dd>{}</dd></div>",
            encode_text(key),
            encode_text(value.unwrap_or("never"))
        ));
    }
    html.push_str("</dl>");
    html
}

fn doc_list(docs: &[&SourceDoc]) -> String {
    let mut html = String::from("<ol class=\"doc-list\">");
    for doc in docs {
        let teaser = doc
            .summary_text
            .as_deref()
            .map(|summary| format!("<span class=\"doc-teaser\">{}</span>", encode_text(summary)))
            .unwrap_or_default();
        html.push_str(&format!(
            "<li><a href=\"{}\"><span class=\"doc-title-wrap\"><span class=\"doc-title\">{}</span>{teaser}</span><span class=\"doc-meta\"><span class=\"badge\">{}</span><time>{}</time></span></a></li>",
            encode_double_quoted_attribute(&doc.output_url_path),
            encode_text(&doc.title),
            encode_text(&doc.collection),
            encode_text(&doc.modified),
        ));
    }
    html.push_str("</ol>");
    html
}

fn layout(settings: &Settings, title: &str, active: &str, body: &str) -> String {
    let full_title = if title == "Knowledge Office" {
        "Knowledge Office".to_string()
    } else {
        format!("{title} · Knowledge Office")
    };
    format!(
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>{}</title><link rel=\"stylesheet\" href=\"/assets/site.css\"><link rel=\"stylesheet\" href=\"https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css\"><script defer src=\"https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js\"></script><script defer src=\"https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js\"></script><script defer src=\"/assets/site.js\"></script></head><body><nav class=\"site-nav\"><div class=\"site-nav__inner\"><a class=\"site-nav__title\" href=\"/\">Knowledge Office</a><span class=\"site-nav__kicker\">qmd + quick</span><span class=\"site-nav__links\"><a href=\"/#recent\">Recent</a><a href=\"/#collections\">Collections</a><a href=\"/status/\">Status</a></span></div></nav><main class=\"site-main\">{}</main><footer class=\"site-footer\"><span>{}</span><span>{}</span></footer></body></html>",
        encode_text(&full_title),
        body,
        encode_text(active),
        encode_text(&format!("{}.quick.shopify.io", settings.site_name))
    )
}

fn write_page(path: &Path, content: &str) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, content).with_context(|| format!("writing {}", path.display()))
}

fn watch(settings: &Settings) -> Result<()> {
    log_line(settings, "INFO", "watcher starting")?;
    println!("Watching {}", settings.knowledge_root.display());
    let (tx, rx) = mpsc::channel();
    let mut watcher = recommended_watcher(move |res| {
        let _ = tx.send(res);
    })?;
    watcher.watch(&settings.knowledge_root, RecursiveMode::Recursive)?;

    let mut pending: BTreeSet<PathBuf> = BTreeSet::new();
    loop {
        if pending.is_empty() {
            match rx.recv_timeout(next_retry_wait(settings)?) {
                Ok(Ok(event)) => collect_event_paths(settings, &event, &mut pending),
                Ok(Err(err)) => log_line(settings, "WARN", &format!("watch error: {err}"))?,
                Err(mpsc::RecvTimeoutError::Timeout) => {
                    if deploy_retry_due(settings)? {
                        let _ = run_once(settings, Vec::new(), true, false).map_err(|err| {
                            let _ = log_line(
                                settings,
                                "ERROR",
                                &format!("pending deploy retry failed: {err:#}"),
                            );
                        });
                    }
                }
                Err(mpsc::RecvTimeoutError::Disconnected) => bail!("watch channel disconnected"),
            }
        }

        if pending.is_empty() {
            continue;
        }

        let coalesce_until = Instant::now() + Duration::from_millis(900);
        while Instant::now() < coalesce_until {
            match rx.recv_timeout(Duration::from_millis(150)) {
                Ok(Ok(event)) => collect_event_paths(settings, &event, &mut pending),
                Ok(Err(err)) => log_line(settings, "WARN", &format!("watch error: {err}"))?,
                Err(mpsc::RecvTimeoutError::Timeout) => {}
                Err(mpsc::RecvTimeoutError::Disconnected) => bail!("watch channel disconnected"),
            }
        }
        wait_for_stability(&pending);
        let changed: Vec<PathBuf> = pending.iter().cloned().collect();
        pending.clear();
        if changed.is_empty() {
            continue;
        }
        let result = run_once(settings, changed, true, false);
        if let Err(err) = result {
            log_line(settings, "ERROR", &format!("watch run failed: {err:#}"))?;
        }
        while let Ok(res) = rx.try_recv() {
            match res {
                Ok(event) => collect_event_paths(settings, &event, &mut pending),
                Err(err) => log_line(settings, "WARN", &format!("watch error: {err}"))?,
            }
        }
    }
}

fn collect_event_paths(
    settings: &Settings,
    event: &notify::Event,
    pending: &mut BTreeSet<PathBuf>,
) {
    for path in &event.paths {
        if is_relevant_watch_path(settings, path) {
            pending.insert(path.clone());
        }
    }
}

fn is_relevant_watch_path(settings: &Settings, path: &Path) -> bool {
    let abs = if path.is_absolute() {
        path.to_path_buf()
    } else {
        settings.knowledge_root.join(path)
    };
    let rel = match abs.strip_prefix(&settings.knowledge_root) {
        Ok(rel) => rel,
        Err(_) => return false,
    };
    if rel.components().any(|c| {
        component_to_str(c)
            .map(|s| s.starts_with('.'))
            .unwrap_or(false)
    }) {
        return false;
    }
    if rel.file_name().and_then(OsStr::to_str) == Some("AGENTS.md") {
        return false;
    }
    if abs.extension().and_then(OsStr::to_str) != Some("md") {
        return false;
    }
    matches!(publish_decision(rel), PublishDecision::Include { .. })
}

fn wait_for_stability(paths: &BTreeSet<PathBuf>) {
    let existing: Vec<_> = paths.iter().filter(|p| p.exists()).cloned().collect();
    if existing.is_empty() {
        return;
    }
    let snapshot = existing
        .iter()
        .map(|p| {
            (
                p.clone(),
                fs::metadata(p)
                    .ok()
                    .and_then(|m| Some((m.len(), m.modified().ok()?))),
            )
        })
        .collect::<Vec<_>>();
    thread::sleep(Duration::from_millis(350));
    for (path, before) in snapshot {
        let after = fs::metadata(&path)
            .ok()
            .and_then(|m| Some((m.len(), m.modified().ok()?)));
        if before != after {
            thread::sleep(Duration::from_millis(350));
            break;
        }
    }
}

fn next_retry_wait(settings: &Settings) -> Result<Duration> {
    let status = load_status(settings)?;
    if !status.pending_deploy {
        return Ok(Duration::from_secs(3600));
    }
    let Some(next) = status.next_deploy_retry_at.as_deref() else {
        return Ok(Duration::from_secs(5));
    };
    let Ok(next_dt) = DateTime::parse_from_rfc3339(next) else {
        return Ok(Duration::from_secs(5));
    };
    let now = Utc::now();
    if next_dt.with_timezone(&Utc) <= now {
        Ok(Duration::from_secs(0))
    } else {
        let diff = next_dt.with_timezone(&Utc) - now;
        Ok(diff
            .to_std()
            .unwrap_or_else(|_| Duration::from_secs(5))
            .min(Duration::from_secs(3600)))
    }
}

fn deploy_retry_due(settings: &Settings) -> Result<bool> {
    Ok(next_retry_wait(settings)? == Duration::from_secs(0))
}

fn show_status(settings: &Settings, json: bool) -> Result<()> {
    let status = load_status(settings)?;
    if json {
        println!("{}", serde_json::to_string_pretty(&status)?);
    } else {
        println!("state: {}", status.overall_state);
        println!(
            "last qmd update: {}",
            status
                .last_successful_qmd_update
                .as_deref()
                .unwrap_or("never")
        );
        println!(
            "last embed: {}",
            status.last_successful_embed.as_deref().unwrap_or("never")
        );
        println!(
            "last site generation: {}",
            status
                .last_successful_site_generation
                .as_deref()
                .unwrap_or("never")
        );
        println!(
            "last deploy: {}",
            status
                .last_successful_quick_deploy
                .as_deref()
                .unwrap_or("never")
        );
        println!("pending deploy: {}", status.pending_deploy);
        println!("stale embeddings: {}", status.stale_embeddings);
        println!("action required: {}", status.action_required);
        if let Some(warning) = status.last_warning {
            println!("last warning: {warning}");
        }
        if let Some(failure) = status.last_failure {
            println!("last failure: {failure}");
        }
    }
    Ok(())
}

fn load_status(settings: &Settings) -> Result<Status> {
    let path = settings.status_path();
    if !path.exists() {
        return Ok(Status::default());
    }
    let text = fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
    Ok(serde_json::from_str(&text).unwrap_or_else(|_| Status::default()))
}

fn save_status(settings: &Settings, status: &Status) -> Result<()> {
    let mut next = status.clone();
    next.updated_at = Some(now_string());
    fs::write(settings.status_path(), serde_json::to_string_pretty(&next)?)
        .with_context(|| format!("writing {}", settings.status_path().display()))
}

fn run_command(
    settings: &Settings,
    program: &Path,
    args: &[&str],
    timeout: Option<Duration>,
) -> Result<CommandResult> {
    fs::create_dir_all(&settings.tmp_dir)?;
    let stamp = Utc::now().timestamp_nanos_opt().unwrap_or(0);
    let stdout_path = settings.tmp_dir.join(format!("cmd-{stamp}.out"));
    let stderr_path = settings.tmp_dir.join(format!("cmd-{stamp}.err"));
    let stdout_file = File::create(&stdout_path)?;
    let stderr_file = File::create(&stderr_path)?;

    let start = Instant::now();
    let mut child = Command::new(program)
        .args(args)
        .stdout(Stdio::from(stdout_file))
        .stderr(Stdio::from(stderr_file))
        .spawn()
        .with_context(|| format!("spawning {}", program.display()))?;

    let mut timed_out = false;
    let status = loop {
        if let Some(status) = child.try_wait()? {
            break status;
        }
        if let Some(timeout) = timeout {
            if start.elapsed() > timeout {
                timed_out = true;
                let _ = child.kill();
                break child.wait()?;
            }
        }
        thread::sleep(Duration::from_millis(100));
    };
    let duration_ms = start.elapsed().as_millis();
    let stdout = read_limited(&stdout_path, 256 * 1024).unwrap_or_default();
    let stderr = read_limited(&stderr_path, 256 * 1024).unwrap_or_default();
    let _ = fs::remove_file(&stdout_path);
    let _ = fs::remove_file(&stderr_path);
    Ok(CommandResult {
        program: program.display().to_string(),
        args: args.iter().map(|s| (*s).to_string()).collect(),
        success: status.success() && !timed_out,
        exit_code: status.code(),
        stdout,
        stderr,
        duration_ms,
        timed_out,
    })
}

fn read_limited(path: &Path, limit: usize) -> Result<String> {
    let mut file = File::open(path)?;
    let mut buf = Vec::new();
    std::io::Read::by_ref(&mut file)
        .take(limit as u64)
        .read_to_end(&mut buf)?;
    Ok(String::from_utf8_lossy(&buf).to_string())
}

fn log_command(settings: &Settings, label: &str, result: &CommandResult) -> Result<()> {
    let msg = format!(
        "{label}: success={} exit={:?} timed_out={} duration_ms={} cmd={} {}\nstdout:\n{}\nstderr:\n{}",
        result.success,
        result.exit_code,
        result.timed_out,
        result.duration_ms,
        result.program,
        result.args.join(" "),
        trim_for_log(&result.stdout, 12000),
        trim_for_log(&result.stderr, 12000)
    );
    log_line(
        settings,
        if result.success { "INFO" } else { "ERROR" },
        &msg,
    )
}

fn format_command_failure(label: &str, result: &CommandResult) -> String {
    format!(
        "{label} failed exit={:?} timed_out={} stderr={} stdout={}",
        result.exit_code,
        result.timed_out,
        trim_for_log(&result.stderr, 2000),
        trim_for_log(&result.stdout, 1000)
    )
}

fn log_line(settings: &Settings, level: &str, message: &str) -> Result<()> {
    fs::create_dir_all(&settings.logs_dir)?;
    rotate_logs_if_needed(settings)?;
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(settings.log_path())?;
    writeln!(file, "{} [{}] {}", now_string(), level, message)?;
    Ok(())
}

fn rotate_logs_if_needed(settings: &Settings) -> Result<()> {
    let path = settings.log_path();
    if !path.exists() || fs::metadata(&path)?.len() < LOG_MAX_BYTES {
        return Ok(());
    }
    for idx in (1..=LOG_ROTATIONS).rev() {
        let from = if idx == 1 {
            path.clone()
        } else {
            settings.logs_dir.join(format!("publisher.log.{}", idx - 1))
        };
        let to = settings.logs_dir.join(format!("publisher.log.{idx}"));
        if from.exists() {
            let _ = fs::rename(from, to);
        }
    }
    Ok(())
}

fn notify(message: &str, urgency: &str) {
    let title = if urgency == "action_needed" {
        "Knowledge publisher action needed"
    } else {
        "Knowledge publisher"
    };
    let escaped_message = applescript_escape(message);
    let escaped_title = applescript_escape(title);
    let script =
        format!("display notification \"{escaped_message}\" with title \"{escaped_title}\"");
    let _ = Command::new("osascript")
        .args(["-e", &script])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

fn applescript_escape(input: &str) -> String {
    input
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .chars()
        .take(180)
        .collect()
}

fn trim_for_log(input: &str, limit: usize) -> String {
    if input.len() <= limit {
        input.to_string()
    } else {
        format!(
            "{}… [truncated {} bytes]",
            &input[..limit],
            input.len() - limit
        )
    }
}

fn system_time_to_rfc3339(time: SystemTime) -> String {
    let dt: DateTime<Utc> = time.into();
    dt.to_rfc3339()
}

fn now_string() -> String {
    Utc::now().to_rfc3339()
}

const SITE_JS: &str = r#"
window.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('pre code.language-mermaid').forEach((block) => {
    const pre = block.parentElement;
    const div = document.createElement('div');
    div.className = 'mermaid';
    div.textContent = block.textContent;
    pre.replaceWith(div);
  });
  if (window.hljs) window.hljs.highlightAll();
  if (window.mermaid) window.mermaid.initialize({ startOnLoad: true, securityLevel: 'strict' });
});
"#;

const SITE_CSS: &str = r#"
:root {
  color-scheme: light;
  --font-body: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  --font-serif: "Iowan Old Style", Charter, Georgia, Cambria, "Times New Roman", serif;
  --font-mono: "Berkeley Mono", ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  --bg: #f7f4ee;
  --paper: #fffdf8;
  --paper-warm: #f2eadc;
  --ink: #171713;
  --muted: #59564e;
  --line: #171713;
  --hairline: rgba(23, 23, 19, .22);
  --yellow: #efd42d;
  --red: #d9583a;
  --orange: #e97832;
  --green: #3e7a2c;
  --blue: #2f8bb6;
  --purple: #a781a7;
  --band-yellow: #beb15e;
  --band-red: #b17162;
  --band-orange: #bb8360;
  --band-green: #486640;
  --band-blue: #517f94;
  --band-purple: #9d8a9d;
  --max: 1280px;
}
* { box-sizing: border-box; }
html { font-size: 16px; scroll-behavior: smooth; }
body {
  margin: 0;
  color: var(--ink);
  background: var(--bg);
  font-family: var(--font-body);
  line-height: 1.55;
}
::selection { background: var(--yellow); color: var(--ink); }
a { color: inherit; text-decoration-thickness: .08em; text-underline-offset: .18em; }
a:hover { color: var(--red); }
code, pre { font-family: var(--font-mono); }
code { background: var(--paper-warm); border: 1px solid var(--hairline); padding: .08rem .25rem; border-radius: 2px; }
.site-nav {
  position: sticky;
  top: 0;
  z-index: 10;
  background: var(--bg);
}
.site-nav__inner {
  min-height: 58px;
  width: min(var(--max), 92vw);
  margin-inline: auto;
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto auto;
  align-items: center;
  gap: clamp(.75rem, 1.6vw, 1.6rem);
  padding: .62rem 0;
  border-top: 4px solid var(--line);
  border-bottom: 2px solid var(--line);
}
.site-nav__title {
  color: var(--ink);
  font-weight: 950;
  font-size: clamp(.9rem, 1.75vw, 1.35rem);
  letter-spacing: -.045em;
  line-height: .98;
  text-transform: uppercase;
  text-decoration: none;
}
.site-nav__title:hover { color: var(--ink); text-decoration: none; }
.site-nav__kicker,
.site-nav__links a,
.eyebrow,
.breadcrumbs,
.card__footer,
.card__band,
.box__header,
.site-footer,
.badge,
.doc-meta,
.metadata,
.status-list {
  font-family: var(--font-mono);
  text-transform: uppercase;
  letter-spacing: .095em;
}
.site-nav__kicker { color: var(--muted); font-size: .7rem; white-space: nowrap; }
.site-nav__links { justify-self: end; display: flex; gap: .55rem; align-items: center; }
.site-nav__links a,
.button-link {
  color: var(--ink);
  font-size: .68rem;
  text-decoration: none;
  border: 1px solid var(--line);
  padding: .32rem .52rem;
  background: var(--paper);
}
.site-nav__links a:hover,
.button-link:hover { color: var(--ink); background: var(--yellow); }
.site-main { width: min(var(--max), 92vw); margin: 2rem auto 4.5rem; }
.site-footer {
  width: min(var(--max), 92vw);
  margin: 3.5rem auto 2rem;
  padding-top: 1rem;
  border-top: 2px solid var(--line);
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  color: var(--muted);
  font-size: .7rem;
}
.hero { margin-bottom: clamp(2rem, 5vw, 3.5rem); }
.hero__body {
  border: 2px solid var(--line);
  background: var(--red);
  padding: clamp(1rem, 2.4vw, 1.8rem);
}
.hero h1,
.section-head h1,
.section-head h2,
.doc > .doc__header h1,
.prose h1,
.card__title {
  font-weight: 950;
  letter-spacing: -.065em;
  line-height: .96;
}
.hero h1 {
  margin: 0;
  color: var(--paper);
  font-size: clamp(2.2rem, 6vw, 5.3rem);
  text-transform: uppercase;
}
.hero__subtitle {
  margin: .25rem 0 0;
  color: rgba(255,253,248,.92);
  font-size: clamp(1rem, 2vw, 1.75rem);
  font-weight: 850;
  letter-spacing: -.035em;
  line-height: 1.05;
  text-transform: uppercase;
}
.hero__eyebrow { color: var(--paper); opacity: .9; }
.eyebrow,
.breadcrumbs { color: var(--red); font-size: .7rem; margin: 0 0 .75rem; }
.breadcrumbs { display: flex; flex-wrap: wrap; gap: .5rem; }
.section-head {
  margin: 2.8rem 0 1.05rem;
  padding-top: .9rem;
  border-top: 3px solid var(--line);
}
.section-head h1,
.section-head h2 { margin: 0; font-size: clamp(1.9rem, 4.8vw, 4.6rem); text-transform: uppercase; }
.section-head p:not(.eyebrow),
.subtitle { color: var(--muted); max-width: 78ch; }
.box { border: 2px solid var(--line); background: var(--paper); }
.box__header { background: var(--paper-warm); border-bottom: 2px solid var(--line); padding: .5rem .72rem; color: var(--muted); font-size: .7rem; }
.box__body { padding: 1rem; }
.status-box { margin: clamp(1.5rem, 4vw, 2.8rem) 0 2.4rem; }
.cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(310px, 1fr));
  gap: clamp(1rem, 2.6vw, 2.1rem);
  align-items: stretch;
}
.card {
  display: grid;
  grid-template-rows: auto 1fr;
  min-height: 300px;
  color: var(--ink);
  background: var(--paper);
  border: 2px solid var(--line);
  text-decoration: none;
  transition: transform .12s ease, box-shadow .12s ease, background .12s ease;
}
.card:hover { color: var(--ink); text-decoration: none; transform: translateY(-3px); box-shadow: 0 10px 0 rgba(23,23,19,.14); }
.card__band {
  min-height: 2.45rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: .48rem .75rem;
  border-bottom: 2px solid var(--line);
  background: var(--band-red);
  color: var(--paper);
  font-size: .66rem;
}
.card:nth-child(2n) .card__band { background: var(--band-purple); }
.card:nth-child(3n) .card__band { background: var(--band-orange); }
.card:nth-child(4n) .card__band { background: var(--band-green); }
.card:nth-child(5n) .card__band { background: var(--band-blue); }
.card:nth-child(6n) .card__band { background: var(--band-yellow); color: var(--ink); }
.card__band-label { display: block; font-weight: 800; line-height: 1; }
.card__body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  justify-content: space-between;
  gap: .95rem;
  padding: clamp(1.15rem, 2.5vw, 1.75rem);
  background: var(--paper);
}
.card__title { display: block; font-size: clamp(1.28rem, 2.56vw, 2.14rem); overflow-wrap: anywhere; }
.card__teaser { display: block; color: var(--muted); font-size: .86rem; line-height: 1.45; overflow-wrap: anywhere; }
.card__footer { display: flex; flex-wrap: wrap; justify-content: space-between; gap: .55rem .85rem; color: var(--ink); font-size: .68rem; }
.doc-list { list-style: none; padding: 0; margin: 0; }
.doc-list li { border-bottom: 1px solid var(--hairline); }
.doc-list li:last-child { border-bottom: 0; }
.doc-list a {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 1rem;
  padding: .65rem 0;
  color: var(--ink);
  text-decoration: none;
}
.doc-list a:hover .doc-title { text-decoration: underline; }
.doc-title-wrap { display: grid; gap: .25rem; min-width: 0; }
.doc-title { font-weight: 750; overflow-wrap: anywhere; }
.doc-teaser { color: var(--muted); font-family: var(--font-serif); font-size: .9rem; line-height: 1.42; overflow-wrap: anywhere; }
.doc-meta { display: flex; gap: .55rem; align-items: center; color: var(--muted); font-size: .68rem; text-align: right; white-space: nowrap; }
.badge {
  display: inline-flex;
  align-items: center;
  border: 1px solid var(--hairline);
  background: var(--paper-warm);
  color: var(--muted);
  padding: .16rem .36rem;
  font-size: .64rem;
}
.doc {
  width: min(1180px, 100%);
  margin-inline: auto;
  background: var(--paper);
  border: 2px solid var(--line);
  padding: clamp(1.2rem, 3vw, 3.1rem);
}
.doc--solo { width: min(880px, 100%); }
.doc > .doc__header {
  max-width: 960px;
  margin-bottom: clamp(1rem, 2vw, 1.5rem);
}
.doc > .doc__header h1 {
  margin: .15rem 0 0;
  font-size: clamp(1.65rem, 3.05vw, 2.85rem);
  line-height: .99;
  letter-spacing: -.058em;
  overflow-wrap: anywhere;
  word-break: break-word;
  text-wrap: balance;
  text-transform: uppercase;
}
.doc__layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(13rem, 16rem);
  gap: clamp(1.5rem, 4vw, 3rem);
  align-items: start;
}
.doc__main { min-width: 0; }
.doc__sidebar {
  position: sticky;
  top: 5rem;
  min-width: 0;
}
.doc__side-block {
  padding-top: .65rem;
  border-top: 2px solid var(--line);
}
.doc__side-block h2 {
  margin: 0 0 .35rem;
  color: var(--muted);
  font-family: var(--font-mono);
  font-size: .62rem;
  font-weight: 700;
  letter-spacing: .095em;
  text-transform: uppercase;
}
.lede {
  max-width: 82ch;
  margin: .15rem 0 1.35rem;
  padding: 0;
  border: 0;
  background: transparent;
  color: #37352f;
  font-size: clamp(1rem, 1.35vw, 1.18rem);
}
.lede p { margin: 0 0 .7rem; font-family: var(--font-serif); }
.lede p:last-child { margin-bottom: 0; }
.toc {
  max-width: 44rem;
  margin: 1.25rem 0 2.25rem;
}
.toc__title {
  margin: 0 0 .45rem;
  font-family: var(--font-serif);
  font-size: 1rem;
  font-weight: 800;
  line-height: 1.35;
}
.toc__list {
  margin: 0;
  padding-left: 1.15rem;
  font-family: var(--font-serif);
  font-size: 1rem;
  line-height: 1.55;
}
.toc__item { margin: .08rem 0; padding-left: .15rem; color: var(--ink); }
.toc__item--h3 { margin-left: .9rem; font-size: .94rem; }
.toc a { color: var(--red); text-decoration-thickness: .06em; text-underline-offset: .15em; }
.toc a:hover { color: var(--ink); }
.metadata,
.status-list { display: grid; gap: .5rem; margin: 0; font-size: .68rem; }
.metadata div,
.status-list div { display: grid; grid-template-columns: minmax(9rem, 14rem) 1fr; gap: 1rem; }
.doc__sidebar .metadata { display: block; font-size: .62rem; }
.doc__sidebar .metadata div {
  display: block;
  padding: .55rem 0;
  border-bottom: 1px solid var(--hairline);
}
.doc__sidebar .metadata div:last-child { border-bottom: 0; }
.doc__sidebar .metadata dt { margin-bottom: .2rem; font-size: .58rem; }
.doc__sidebar .metadata dd { font-size: .66rem; line-height: 1.35; }
dt { color: var(--muted); }
dd { margin: 0; text-transform: none; letter-spacing: normal; font-family: var(--font-mono); overflow-wrap: anywhere; }
.prose { max-width: none; }
.prose img { max-width: 100%; }
.prose h1 { margin: 2.2rem 0 1rem; font-size: clamp(1.15rem, 2.8vw, 2.6rem); text-transform: uppercase; }
.prose h2 { margin-top: 2.8rem; padding-top: .85rem; border-top: 3px solid var(--line); font-size: clamp(1.1rem, 1.9vw, 1.65rem); letter-spacing: -.045em; line-height: 1; }
.prose h3 { margin-top: 2rem; color: var(--red); font-size: 1.15rem; }
.prose p,
.prose li,
.prose blockquote,
.prose table { font-family: var(--font-serif); color: #2b2a25; }
.prose p,
.prose li { overflow-wrap: anywhere; }
.prose a { color: var(--red); }
.prose table { width: 100%; border-collapse: collapse; display: block; overflow-x: auto; font-size: .9rem; }
.prose th,
.prose td { border: 1px solid var(--line); padding: .5rem .6rem; vertical-align: top; }
.prose th { background: var(--yellow); text-align: left; }
.prose blockquote { margin-left: 0; padding: .85rem 1rem; border-left: 8px solid var(--yellow); background: var(--paper-warm); color: var(--muted); }
.prose pre { overflow: auto; padding: 1rem; background: var(--ink); color: var(--paper); border: 2px solid var(--line); border-radius: 0; }
.prose pre code { display: block; background: transparent; border: 0; padding: 0; color: inherit; }
.prose :not(pre) > code { overflow-wrap: anywhere; word-break: break-word; }
.mermaid { background: var(--paper); border: 2px solid var(--line); padding: 1rem; overflow: auto; }
.local-warning { border: 2px solid var(--orange); background: var(--paper-warm); padding: .75rem 1rem; margin: 1rem 0; color: var(--ink); }
.muted { color: var(--muted); }
@media (max-width: 940px) {
  .site-nav__inner { grid-template-columns: 1fr; justify-items: start; width: 92vw; }
  .site-nav__links { justify-self: start; flex-wrap: wrap; }
  .cards-grid { grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); }
  .doc__layout { grid-template-columns: 1fr; }
  .doc__sidebar { position: static; margin-top: 2rem; }
  .doc-list a { grid-template-columns: 1fr; }
  .doc-meta { text-align: left; white-space: normal; flex-wrap: wrap; }
}
@media (max-width: 620px) {
  .site-main,
  .site-footer { width: min(var(--max), 94vw); }
  .hero__body { padding: 1rem; }
  .hero h1 { font-size: clamp(2rem, 12vw, 4rem); }
  .site-footer { flex-direction: column; align-items: flex-start; }
  .metadata div,
  .status-list div { grid-template-columns: 1fr; gap: .1rem; }
}
"#;

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn publish_contract_uses_folder_blocklist() {
        assert!(matches!(
            publish_decision(Path::new("AGENTS.md")),
            PublishDecision::Exclude { .. }
        ));
        assert!(matches!(
            publish_decision(Path::new("tuple-calls/2026/summary.md")),
            PublishDecision::Exclude { .. }
        ));
        assert!(matches!(
            publish_decision(Path::new("work-journal-evidence/a.md")),
            PublishDecision::Exclude { .. }
        ));
        assert!(matches!(
            publish_decision(Path::new("plans/a.md")),
            PublishDecision::Include { .. }
        ));
        assert!(matches!(
            publish_decision(Path::new("intentions/a.md")),
            PublishDecision::Include { .. }
        ));
        assert!(matches!(
            publish_decision(Path::new("unknown/a.md")),
            PublishDecision::Include { .. }
        ));
        assert!(matches!(
            publish_decision(Path::new("entitlements-graphql-findings.md")),
            PublishDecision::ReportOnly { .. }
        ));
    }

    #[test]
    fn publishable_collection_dirs_are_dynamic_except_blocklist() -> Result<()> {
        let tmp = tempdir()?;
        let root = tmp.path().join("knowledge");
        fs::create_dir_all(root.join("intentions"))?;
        fs::create_dir_all(root.join("dashboards"))?;
        fs::create_dir_all(root.join("tuple-calls"))?;
        fs::create_dir_all(root.join(".hidden"))?;
        fs::write(root.join("loose.md"), "# Loose\n")?;
        let settings = Settings {
            knowledge_root: root,
            cache_dir: tmp.path().join("cache"),
            site_dir: tmp.path().join("cache/site"),
            state_dir: tmp.path().join("state"),
            logs_dir: tmp.path().join("state/logs"),
            tmp_dir: tmp.path().join("state/tmp"),
            qmd_path: PathBuf::from("qmd"),
            quick_path: PathBuf::from("quick"),
            site_name: DEFAULT_SITE_NAME.to_string(),
        };
        assert_eq!(
            publishable_collection_dirs(&settings)?,
            vec!["dashboards".to_string(), "intentions".to_string()]
        );
        Ok(())
    }

    #[test]
    fn malformed_frontmatter_warns_and_renders_body_after_delimiter() {
        let mut warnings = Vec::new();
        let (metadata, body) = parse_frontmatter(
            "---\ntitle: [oops\n---\n# Body\n",
            Path::new("plans/bad.md"),
            &mut warnings,
        );
        assert!(metadata.is_empty());
        assert_eq!(body, "# Body\n");
        assert_eq!(warnings.len(), 1);
    }

    #[test]
    fn fold_summary_splits_before_more_marker() {
        let (summary, body) =
            split_fold_summary("A short public summary.\n\n<!--more-->\n\n## Details\nBody");
        assert_eq!(summary.as_deref(), Some("A short public summary."));
        assert_eq!(body, "## Details\nBody");
        assert_eq!(
            plain_text_from_markdown(summary.as_deref().unwrap()),
            "A short public summary."
        );
    }

    #[test]
    fn toc_collects_headings_with_stable_ids() {
        let toc = collect_toc("## Summary\n\n### Details\n\n## Summary\n");
        assert_eq!(toc.len(), 3);
        assert_eq!(toc[0].id, "summary");
        assert_eq!(toc[1].id, "details");
        assert_eq!(toc[2].id, "summary-2");
    }

    #[test]
    fn title_can_come_from_fold_summary_without_repeating_in_lede() {
        let body = "# CLI::Kit::Executor bypasses `ctx.ui`\n\nDate: 2026-06-12\n\nSummary.\n\n<!--more-->\n\n## TL;DR\n\n```ruby\n# areas/tools/dev/vendor/deps/cli-kit/lib/cli/kit/executor.rb\n```\n";
        let title = derive_title(&BTreeMap::new(), body, Path::new("research/dev-agent.md"));
        assert_eq!(title, "CLI::Kit::Executor bypasses ctx.ui");
        let (summary, _) = split_fold_summary(body);
        let summary = strip_leading_summary_title(summary.as_deref().unwrap(), &title);
        assert!(!summary.contains("CLI::Kit::Executor"));
        assert!(summary.starts_with("Date: 2026-06-12"));
    }

    #[test]
    fn relative_markdown_links_rewrite_when_target_is_published() {
        let mut map = HashMap::new();
        map.insert(
            PathBuf::from("plans/target.md"),
            "/docs/plans/target/".to_string(),
        );
        let mut warnings = Vec::new();
        let rewritten = rewrite_markdown_link(
            Path::new("plans/source.md"),
            "target.md#x",
            &map,
            &mut warnings,
            "https://pcasaretto-knowledge.quick.shopify.io",
        );
        assert_eq!(rewritten.as_deref(), Some("/docs/plans/target/#x"));
        assert!(warnings.is_empty());
    }

    #[test]
    fn local_knowledge_paths_rewrite_to_quick_urls() {
        let mut map = HashMap::new();
        map.insert(
            PathBuf::from("research/dev-agent-ui-stream-pollution.md"),
            "/docs/research/dev-agent-ui-stream-pollution/".to_string(),
        );
        let base = "https://pcasaretto-knowledge.quick.shopify.io";
        let expected = "https://pcasaretto-knowledge.quick.shopify.io/docs/research/dev-agent-ui-stream-pollution/";

        let text = rewrite_knowledge_paths_to_text(
            "See ~/knowledge/research/dev-agent-ui-stream-pollution.md for details.",
            &map,
            base,
        )
        .unwrap();
        assert_eq!(text, format!("See {expected} for details."));

        let html = rewrite_knowledge_paths_to_html(
            "See /Users/paulo.casaretto/knowledge/research/dev-agent-ui-stream-pollution.md.",
            &map,
            base,
        )
        .unwrap();
        assert!(html.contains(&format!("href=\"{expected}\"")));
        assert!(!html.contains("/Users/paulo.casaretto/knowledge"));

        let mut warnings = Vec::new();
        let link = rewrite_markdown_link(
            Path::new("intentions/source.md"),
            "~/knowledge/research/dev-agent-ui-stream-pollution.md#tldr",
            &map,
            &mut warnings,
            base,
        );
        let expected_with_fragment = format!("{expected}#tldr");
        assert_eq!(link.as_deref(), Some(expected_with_fragment.as_str()));
        assert!(warnings.is_empty());
    }

    #[test]
    fn generator_writes_core_pages() -> Result<()> {
        let tmp = tempdir()?;
        let root = tmp.path().join("knowledge");
        fs::create_dir_all(root.join("plans"))?;
        fs::write(
            root.join("plans/test.md"),
            "---\ntitle: Test Plan\nstatus: draft\n---\n# Test Plan\nSee [target](target.md).",
        )?;
        fs::write(root.join("plans/target.md"), "# Target\n")?;
        fs::create_dir_all(root.join("tuple-calls"))?;
        fs::write(root.join("tuple-calls/secret.md"), "# Secret\n")?;
        let settings = Settings {
            knowledge_root: root,
            cache_dir: tmp.path().join("cache"),
            site_dir: tmp.path().join("cache/site"),
            state_dir: tmp.path().join("state"),
            logs_dir: tmp.path().join("state/logs"),
            tmp_dir: tmp.path().join("state/tmp"),
            qmd_path: PathBuf::from("qmd"),
            quick_path: PathBuf::from("quick"),
            site_name: DEFAULT_SITE_NAME.to_string(),
        };
        settings.ensure_dirs()?;
        let manifest = build_manifest(&settings)?;
        assert_eq!(manifest.included_count, 2);
        assert!(!manifest
            .documents
            .iter()
            .any(|d| d.relative_path == PathBuf::from("tuple-calls/secret.md")));
        generate_site(&settings, &manifest, &Status::default())?;
        assert!(settings.site_dir.join("index.html").exists());
        assert!(settings
            .site_dir
            .join("docs/plans/test/index.html")
            .exists());
        assert!(settings
            .site_dir
            .join("collections/plans/index.html")
            .exists());
        Ok(())
    }
}
