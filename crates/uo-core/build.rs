use sha2::{Digest, Sha256};
use std::fs;
use std::path::{Path, PathBuf};

fn main() {
    let workspace = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(Path::parent)
        .expect("uo-core should live under crates/uo-core")
        .to_path_buf();

    emit_file_hash(
        "UO_TOOLCHAIN_RUST_TOOLCHAIN_SHA256",
        &workspace,
        "rust-toolchain.toml",
    );
    emit_file_hash("UO_TOOLCHAIN_CARGO_LOCK_SHA256", &workspace, "Cargo.lock");
    emit_file_hash(
        "UO_TOOLCHAIN_WORKSPACE_MANIFEST_SHA256",
        &workspace,
        "Cargo.toml",
    );
    emit_file_hash(
        "UO_TOOLCHAIN_LEAN_TOOLCHAIN_SHA256",
        &workspace,
        "proof/lean/lean-toolchain",
    );
    emit_file_hash(
        "UO_TOOLCHAIN_PROOF_GRADE_ROOT_SHA256",
        &workspace,
        "proof/lean/UOToolchain/ProofGradeRoot.lean",
    );

    emit_tree_hash(
        "UO_TOOLCHAIN_CRATE_MANIFESTS_SHA256",
        &workspace,
        &["crates", "compiler", "checker", "runtime", "probe"],
        |path| path.file_name().is_some_and(|name| name == "Cargo.toml"),
    );
    emit_tree_hash(
        "UO_TOOLCHAIN_PROOF_IMPORT_SET_SHA256",
        &workspace,
        &["proof/lean"],
        |path| path.extension().is_some_and(|ext| ext == "lean"),
    );
    emit_tree_hash(
        "UO_TOOLCHAIN_GENERATED_CODE_SHA256",
        &workspace,
        &["crates/uo-core/src", "runtime", "proof/lean/UOToolchain"],
        |path| {
            path.file_name()
                .and_then(|name| name.to_str())
                .is_some_and(|name| {
                    name.contains("generated")
                        || name.contains("GeneratedRust")
                        || name.ends_with("GeneratedRust.lean")
                })
        },
    );
    emit_tree_hash(
        "UO_TOOLCHAIN_RUNTIME_MODEL_SHA256",
        &workspace,
        &["crates/uo-core/src", "runtime"],
        |path| path.extension().is_some_and(|ext| ext == "rs"),
    );
    emit_tree_hash(
        "UO_TOOLCHAIN_DEPLOYMENT_MODEL_SHA256",
        &workspace,
        &["runtime/uo-evm/src", "proof/lean/UOToolchain"],
        |path| {
            if path.extension().is_some_and(|ext| ext == "rs") {
                return true;
            }
            path.file_name()
                .and_then(|name| name.to_str())
                .is_some_and(|name| {
                    name.starts_with("Sgx")
                        || name == "TeeDeployment.lean"
                        || name == "RuntimeReturnScheduleDiscipline.lean"
                        || name == "RuntimeAuditSurfaces.lean"
                })
        },
    );
}

fn emit_file_hash(var: &str, workspace: &Path, rel: &str) {
    let path = workspace.join(rel);
    println!("cargo:rerun-if-changed={}", path.display());
    let bytes = fs::read(&path).unwrap_or_else(|err| {
        panic!("failed to read {} for {var}: {err}", path.display());
    });
    println!(
        "cargo:rustc-env={var}={}",
        hex::encode(Sha256::digest(bytes))
    );
}

fn emit_tree_hash<F>(var: &str, workspace: &Path, rel_roots: &[&str], include: F)
where
    F: Fn(&Path) -> bool + Copy,
{
    let mut files = Vec::new();
    for rel_root in rel_roots {
        let root = workspace.join(rel_root);
        println!("cargo:rerun-if-changed={}", root.display());
        collect_files(workspace, &root, include, &mut files);
    }
    files.sort();
    let mut hasher = Sha256::new();
    for rel in &files {
        let path = workspace.join(rel);
        println!("cargo:rerun-if-changed={}", path.display());
        let bytes = fs::read(&path).unwrap_or_else(|err| {
            panic!("failed to read {} for {var}: {err}", path.display());
        });
        hasher.update(rel.as_bytes());
        hasher.update([0]);
        hasher.update((bytes.len() as u64).to_le_bytes());
        hasher.update([0]);
        hasher.update(bytes);
    }
    println!("cargo:rustc-env={var}={}", hex::encode(hasher.finalize()));
}

fn collect_files<F>(workspace: &Path, dir: &Path, include: F, out: &mut Vec<String>)
where
    F: Fn(&Path) -> bool + Copy,
{
    let entries = fs::read_dir(dir).unwrap_or_else(|err| {
        panic!("failed to read directory {}: {err}", dir.display());
    });
    for entry in entries {
        let entry = entry.unwrap_or_else(|err| {
            panic!(
                "failed to read directory entry under {}: {err}",
                dir.display()
            );
        });
        let path = entry.path();
        if path.is_dir() {
            collect_files(workspace, &path, include, out);
        } else if path.is_file() && include(&path) {
            out.push(to_workspace_relative(workspace, &path));
        }
    }
}

fn to_workspace_relative(workspace: &Path, path: &Path) -> String {
    path.strip_prefix(workspace)
        .expect("hashed path should be under workspace")
        .to_string_lossy()
        .replace('\\', "/")
}
