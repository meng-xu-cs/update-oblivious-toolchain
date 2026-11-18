//! What a crash leaves of a file store's files: a model for tests.
//!
//! A process reads back every byte it wrote, but a power failure keeps less.
//! A file's bytes are on the device once the file is synced, and a name in a
//! directory, a file's or another directory's, once that directory is
//! synced. A sync that fails leaves the bytes written before it off the
//! device, and a later sync of the file does not put them there: the
//! operating system may have marked them written, and `fsync(2)` promises
//! nothing after a failure. So the files a process reads after a failed sync
//! can hold bytes that a crash then takes away.
//!
//! A file store tells this model of each file operation it makes under a
//! directory a test watches (`CrashModel::watch`). The model keeps, for each
//! file, what a process reads and what the device holds, and for each
//! directory, the names a process sees and the names the device holds. A
//! test asks it for the files a crash would leave (`CrashModel::crash_into`),
//! and can make an operation fail (`CrashModel::fail_next`). A watched
//! directory starts empty and on the device.
//!
//! Only a test or a diagnostics build has the model.

use anyhow::{anyhow, bail, Context, Result};
use std::collections::BTreeMap;
use std::ffi::OsString;
use std::fs;
use std::ops::Range;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, MutexGuard};

/// A file operation of a file store that a test can make fail.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FileOperation {
    /// Creating a file to write it whole: a snapshot, or a journal a store
    /// opened again publishes.
    Write,
    /// Syncing a file.
    SyncFile,
    /// Renaming a file over another.
    Rename,
    /// Syncing a directory.
    SyncDirectory,
}

#[derive(Clone, Copy, Debug)]
enum Node {
    File(usize),
    Directory,
}

#[derive(Debug, Default)]
struct File {
    /// What the device holds.
    durable: Vec<u8>,
    /// The bytes a sync failed to put on the device, which no later sync
    /// puts there: the device keeps what it held at each of them.
    lost: Option<Range<usize>>,
}

#[derive(Debug, Default)]
struct Directory {
    visible: BTreeMap<OsString, Node>,
    durable: BTreeMap<OsString, Node>,
}

#[derive(Debug)]
struct Model {
    root: PathBuf,
    files: Vec<File>,
    directories: BTreeMap<PathBuf, Directory>,
    armed: Vec<(PathBuf, FileOperation)>,
}

static MODELS: Mutex<Vec<Model>> = Mutex::new(Vec::new());

fn models() -> MutexGuard<'static, Vec<Model>> {
    MODELS
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// Apply `change` to the model that watches `path`, if one does.
fn with_model(path: &Path, change: impl FnOnce(&mut Model)) {
    let mut models = models();
    if let Some(model) = models
        .iter_mut()
        .find(|model| path.starts_with(&model.root))
    {
        change(model);
    }
}

impl Model {
    fn node(&self, path: &Path) -> Option<Node> {
        let directory = self.directories.get(path.parent()?)?;
        directory.visible.get(path.file_name()?).copied()
    }

    fn file(&mut self, path: &Path) -> Option<&mut File> {
        match self.node(path)? {
            Node::File(index) => self.files.get_mut(index),
            Node::Directory => None,
        }
    }

    fn name(&mut self, path: &Path, node: Node) {
        if let (Some(parent), Some(name)) = (path.parent(), path.file_name()) {
            if let Some(directory) = self.directories.get_mut(parent) {
                directory.visible.insert(name.to_owned(), node);
            }
        }
    }

    /// Write into `target` what the device holds under `directory`.
    fn materialize(&self, directory: &Path, target: &Path) -> Result<()> {
        let Some(entries) = self.directories.get(directory) else {
            return Ok(());
        };
        for (name, node) in &entries.durable {
            let at = target.join(name);
            match node {
                Node::File(index) => fs::write(&at, &self.files[*index].durable)?,
                Node::Directory => {
                    fs::create_dir(&at)?;
                    self.materialize(&directory.join(name), &at)?;
                }
            }
        }
        Ok(())
    }
}

/// A watch over the files under a directory. It ends when it is dropped.
#[derive(Debug)]
pub struct CrashModel {
    root: PathBuf,
}

impl CrashModel {
    /// Watch the files under `root`, an empty directory on the device, and
    /// the operations a file store makes on them.
    pub fn watch(root: impl AsRef<Path>) -> Result<Self> {
        let root = root.as_ref().to_path_buf();
        if !root.is_absolute() {
            bail!("a watched directory is named by its absolute path");
        }
        let mut entries =
            fs::read_dir(&root).with_context(|| format!("reading {}", root.display()))?;
        if entries.next().is_some() {
            bail!("{} is not empty", root.display());
        }
        let mut models = models();
        if models
            .iter()
            .any(|model| model.root.starts_with(&root) || root.starts_with(&model.root))
        {
            bail!("{} is watched already", root.display());
        }
        models.push(Model {
            root: root.clone(),
            files: Vec::new(),
            directories: BTreeMap::from([(root.clone(), Directory::default())]),
            armed: Vec::new(),
        });
        Ok(Self { root })
    }

    /// Make the next `operation` on `path` fail, as a device or a file system
    /// could: a file that cannot be created, a sync that fails, a rename
    /// that does not happen.
    pub fn fail_next(&self, operation: FileOperation, path: impl AsRef<Path>) {
        let path = path.as_ref().to_path_buf();
        with_model(&self.root, |model| model.armed.push((path, operation)));
    }

    /// Write into `target`, a directory that does not exist yet, the files a
    /// crash now would leave under the watched directory: the names each
    /// directory held when it was last synced, each file with the bytes it
    /// held when it was last synced, but those a failed sync lost.
    pub fn crash_into(&self, target: impl AsRef<Path>) -> Result<()> {
        let target = target.as_ref();
        let models = models();
        let model = models
            .iter()
            .find(|model| model.root == self.root)
            .ok_or_else(|| anyhow!("{} is not watched", self.root.display()))?;
        fs::create_dir(target).with_context(|| format!("creating {}", target.display()))?;
        model.materialize(&model.root, target)
    }
}

impl Drop for CrashModel {
    fn drop(&mut self) {
        models().retain(|model| model.root != self.root);
    }
}

/// Whether a test armed the next `operation` on `path` to fail. The arming
/// is spent.
pub(crate) fn fails(path: &Path, operation: FileOperation) -> bool {
    let mut armed = false;
    with_model(path, |model| {
        if let Some(at) = model
            .armed
            .iter()
            .position(|(target, kind)| target == path && *kind == operation)
        {
            model.armed.remove(at);
            armed = true;
        }
    });
    armed
}

/// `path` is a directory the store created.
pub(crate) fn created_directory(path: &Path) {
    with_model(path, |model| {
        model.name(path, Node::Directory);
        model.directories.entry(path.to_path_buf()).or_default();
    });
}

/// `path` is a file the store created, or emptied if it was there.
pub(crate) fn created_file(path: &Path) {
    with_model(path, |model| {
        if let Some(file) = model.file(path) {
            // The bytes a failed sync lost go with the file's bytes.
            file.lost = None;
            return;
        }
        model.files.push(File::default());
        let index = model.files.len() - 1;
        model.name(path, Node::File(index));
    });
}

/// The file at `path` was cut to `len` bytes.
pub(crate) fn truncated(path: &Path, len: u64) {
    let len = usize::try_from(len).unwrap_or(usize::MAX);
    with_model(path, |model| {
        if let Some(file) = model.file(path) {
            file.lost = file
                .lost
                .take()
                .filter(|lost| lost.start < len)
                .map(|lost| lost.start..lost.end.min(len));
        }
    });
}

/// A sync of the file at `path` ended, as `synced` says. A sync puts on the
/// device the bytes a process reads from the file, but those a failed sync
/// lost; a failed one loses those it did not put there.
pub(crate) fn synced_file(path: &Path, synced: bool) {
    with_model(path, |model| {
        let read = fs::read(path).unwrap_or_default();
        let Some(file) = model.file(path) else {
            return;
        };
        if synced {
            let before = std::mem::take(&mut file.durable);
            let mut durable = read;
            if let Some(lost) = &file.lost {
                for at in lost.clone() {
                    if let Some(byte) = durable.get_mut(at) {
                        *byte = before.get(at).copied().unwrap_or(0);
                    }
                }
            }
            file.durable = durable;
        } else {
            let start = read
                .iter()
                .zip(&file.durable)
                .position(|(read, durable)| read != durable)
                .unwrap_or_else(|| read.len().min(file.durable.len()));
            if start < read.len() {
                let lost = match file.lost.take() {
                    Some(lost) => lost.start.min(start)..lost.end.max(read.len()),
                    None => start..read.len(),
                };
                file.lost = Some(lost);
            }
        }
    });
}

/// The file at `from` was renamed to `to`, over the file there if any.
pub(crate) fn renamed(from: &Path, to: &Path) {
    with_model(from, |model| {
        let node = from
            .parent()
            .and_then(|parent| model.directories.get_mut(parent))
            .zip(from.file_name())
            .and_then(|(directory, name)| directory.visible.remove(name));
        if let Some(node) = node {
            model.name(to, node);
        }
    });
}

/// A sync of the directory at `path` ended, as `synced` says: one that
/// returned puts on the device the names a process sees in it.
pub(crate) fn synced_directory(path: &Path, synced: bool) {
    with_model(path, |model| {
        if let (true, Some(directory)) = (synced, model.directories.get_mut(path)) {
            directory.durable = directory.visible.clone();
        }
    });
}
