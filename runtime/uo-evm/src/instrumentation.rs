//! Wall-clock time the instrumented runtime spends on the parts of a call
//! that a measurement tells apart from the call's own work: staging the
//! call on the committed state, loading the call's objects from it, the
//! hidden position-map witnesses of the call's start and end,
//! the execution trace with the proof bundles it builds and checks, and the
//! store's commit of the call's records. The
//! runtime keeps the witness from call to call and moves it by each call's
//! leaf transitions; it decodes one from storage for the first call, after a
//! load that no call made, and for an audit, which compares the kept witness
//! with that decode. Every call audits its witness before and after, unless
//! a measurement turns the audit off for its thread. The module also counts
//! the sealed records those decodes open, which no trace records, and the
//! public objects whose state a public-state snapshot decodes.
//! Diagnostics builds keep the totals, the audit switch and the count of
//! audits per thread; other builds run the timed work as is.

#[cfg(feature = "diagnostics")]
use std::cell::Cell;
#[cfg(feature = "diagnostics")]
use std::time::Instant;

/// Time, in nanoseconds, and work since the last
/// `take_instrumentation_totals` on this thread.
#[cfg(feature = "diagnostics")]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct InstrumentationTotals {
    /// Staging a call: making the table of the committed objects that the
    /// call runs on. The objects are shared, so none is copied.
    pub staging_ns: u128,
    /// Loading the call's objects from that table: opening an exact
    /// object's slots, and for a Path ORAM map taking a reference to each
    /// of its sealed records and decoding its metadata pages.
    pub load_ns: u128,
    /// The position-map witnesses of the calls: copying the kept one,
    /// moving it by a call's leaf transitions, and decoding it from storage
    /// where that is done.
    pub witness_ns: u128,
    /// Building and checking the execution trace and its proof bundles.
    pub proof_objects_ns: u128,
    /// The store's commit of a call's records: nothing to speak of for a
    /// store in memory, and the append to the journal, with its sync, for
    /// one in files.
    pub storage_commit_ns: u128,
    /// Sealed records the decodes of position-map witnesses opened.
    pub witness_records_opened: u64,
    /// Public objects whose state the public-state snapshots decoded from
    /// storage: an object keeps the digest of its state, so those loaded or
    /// changed since a snapshot last read them.
    pub public_state_objects_decoded: u64,
    /// The bytes of the JSON of the states those decodes gave.
    pub public_state_bytes_decoded: u64,
}

#[cfg(feature = "diagnostics")]
thread_local! {
    static TOTALS: Cell<InstrumentationTotals> = const {
        Cell::new(InstrumentationTotals {
            staging_ns: 0,
            load_ns: 0,
            witness_ns: 0,
            proof_objects_ns: 0,
            storage_commit_ns: 0,
            witness_records_opened: 0,
            public_state_objects_decoded: 0,
            public_state_bytes_decoded: 0,
        })
    };
}

#[cfg(feature = "diagnostics")]
thread_local! {
    /// Whether the calls of this thread leave out the audit of their kept
    /// witness. They audit it unless a measurement says otherwise.
    static WITNESS_AUDIT_OFF: Cell<bool> = const { Cell::new(false) };
    /// How many times this thread compared a kept witness with its decode.
    static WITNESS_AUDITS: Cell<u64> = const { Cell::new(0) };
}

/// Turn the audit of the kept position-map witness on or off for the calls
/// of this thread, and return whether it was on. It is on until it is turned
/// off: every instrumented call compares the witness it keeps with the
/// decode of the whole store, before and after the call, and fails when the
/// two differ. So the witness under every proof object is the store's own.
/// The decode is what every call did before the witness was kept, and an
/// audited call costs what a call cost then. A measurement of calls turns
/// the audit off for as long as it measures, and audits where it does not.
#[cfg(feature = "diagnostics")]
pub fn set_position_map_witness_audit(on: bool) -> bool {
    WITNESS_AUDIT_OFF.with(|off| !off.replace(!on))
}

/// How many times this thread has compared a kept position-map witness
/// with its decode from storage, in calls and when asked.
#[cfg(feature = "diagnostics")]
pub fn position_map_witness_audits() -> u64 {
    WITNESS_AUDITS.with(Cell::get)
}

/// The totals accumulated on this thread, which start again from zero.
#[cfg(feature = "diagnostics")]
pub fn take_instrumentation_totals() -> InstrumentationTotals {
    TOTALS.with(|totals| totals.replace(InstrumentationTotals::default()))
}

#[cfg(feature = "diagnostics")]
fn timed<T>(f: impl FnOnce() -> T, add: impl FnOnce(&mut InstrumentationTotals, u128)) -> T {
    let started = Instant::now();
    let out = f();
    let elapsed = started.elapsed().as_nanos();
    TOTALS.with(|totals| {
        let mut total = totals.get();
        add(&mut total, elapsed);
        totals.set(total);
    });
    out
}

/// Run `f`, the staging of a call on the committed state.
pub(crate) fn time_staging<T>(f: impl FnOnce() -> T) -> T {
    #[cfg(feature = "diagnostics")]
    {
        timed(f, |total, elapsed| total.staging_ns += elapsed)
    }
    #[cfg(not(feature = "diagnostics"))]
    {
        f()
    }
}

/// Run `f`, the loading of a call's objects from the staged state.
pub(crate) fn time_load<T>(f: impl FnOnce() -> T) -> T {
    #[cfg(feature = "diagnostics")]
    {
        timed(f, |total, elapsed| total.load_ns += elapsed)
    }
    #[cfg(not(feature = "diagnostics"))]
    {
        f()
    }
}

/// Run `f`, work on the position-map witnesses of a call. Only a build that
/// can export a call's evidence has witnesses.
#[cfg(any(test, feature = "diagnostics"))]
pub(crate) fn time_witness<T>(f: impl FnOnce() -> T) -> T {
    #[cfg(feature = "diagnostics")]
    {
        timed(f, |total, elapsed| total.witness_ns += elapsed)
    }
    #[cfg(not(feature = "diagnostics"))]
    {
        f()
    }
}

/// Run `f`, the building of the execution trace and its proof bundles.
pub(crate) fn time_proof_objects<T>(f: impl FnOnce() -> T) -> T {
    #[cfg(feature = "diagnostics")]
    {
        timed(f, |total, elapsed| total.proof_objects_ns += elapsed)
    }
    #[cfg(not(feature = "diagnostics"))]
    {
        f()
    }
}

/// Run `f`, the store's commit of a call's records.
pub(crate) fn time_store_persistence<T>(f: impl FnOnce() -> T) -> T {
    #[cfg(feature = "diagnostics")]
    {
        timed(f, |total, elapsed| total.storage_commit_ns += elapsed)
    }
    #[cfg(not(feature = "diagnostics"))]
    {
        f()
    }
}

/// Whether a call audits its kept position-map witness: unless a
/// measurement has turned the audit off for this thread. A test build
/// audits every call.
#[cfg(any(test, feature = "diagnostics"))]
pub(crate) fn witness_audit_enabled() -> bool {
    #[cfg(feature = "diagnostics")]
    {
        cfg!(test) || !WITNESS_AUDIT_OFF.with(Cell::get)
    }
    #[cfg(not(feature = "diagnostics"))]
    {
        true
    }
}

/// Record one comparison of a kept witness with its decode from storage.
#[cfg(any(test, feature = "diagnostics"))]
pub(crate) fn count_witness_audit() {
    #[cfg(feature = "diagnostics")]
    {
        WITNESS_AUDITS.with(|audits| audits.set(audits.get().saturating_add(1)));
    }
}

/// Record that one object's sealed records were read for a digest of the
/// ciphertext. An object keeps its digest, so a test counts here the
/// objects a digest could not take from before: those written since.
#[cfg(test)]
pub(crate) fn count_sealed_records_digest() {
    sealed_records_digests::count();
}

/// A build other than a test's counts nothing.
#[cfg(not(test))]
pub(crate) fn count_sealed_records_digest() {}

/// How many times this thread has read an object's sealed records for a
/// digest of the ciphertext.
#[cfg(test)]
pub(crate) fn sealed_records_digests_computed() -> u64 {
    sealed_records_digests::computed()
}

/// Record that a public-state snapshot decoded the state of object
/// `object_id`, whose JSON is `bytes` long: a test keeps the object, and a
/// diagnostics build adds the decode to its totals. A production build
/// counts nothing.
pub(crate) fn count_public_state_decode(object_id: u32, bytes: usize) {
    record_public_state_decode(object_id);
    add_public_state_decode(bytes);
}

/// Keep the object a test's snapshot decoded.
#[cfg(test)]
fn record_public_state_decode(object_id: u32) {
    public_state_decodes::record(object_id);
}

/// A build other than a test's keeps no object.
#[cfg(not(test))]
fn record_public_state_decode(_object_id: u32) {}

/// Add a decode to the totals of a diagnostics build.
#[cfg(feature = "diagnostics")]
fn add_public_state_decode(bytes: usize) {
    TOTALS.with(|totals| {
        let mut total = totals.get();
        total.public_state_objects_decoded = total.public_state_objects_decoded.saturating_add(1);
        total.public_state_bytes_decoded = total
            .public_state_bytes_decoded
            .saturating_add(u64::try_from(bytes).unwrap_or(u64::MAX));
        totals.set(total);
    });
}

/// A build without diagnostics keeps no totals.
#[cfg(not(feature = "diagnostics"))]
fn add_public_state_decode(_bytes: usize) {}

/// The objects whose public state this thread's snapshots decoded since
/// the last time this was asked, in the order they were decoded.
#[cfg(test)]
pub(crate) fn take_public_state_decodes() -> Vec<u32> {
    public_state_decodes::take()
}

/// Record that a position-map witness opened `records` sealed records.
#[cfg(any(test, feature = "diagnostics"))]
pub(crate) fn count_witness_records(records: usize) {
    #[cfg(feature = "diagnostics")]
    {
        TOTALS.with(|totals| {
            let mut total = totals.get();
            total.witness_records_opened = total
                .witness_records_opened
                .saturating_add(u64::try_from(records).unwrap_or(u64::MAX));
            totals.set(total);
        });
    }
    #[cfg(not(feature = "diagnostics"))]
    {
        let _ = records;
    }
}

#[cfg(test)]
mod sealed_records_digests {
    thread_local! {
        static DIGESTS: std::cell::Cell<u64> = const { std::cell::Cell::new(0) };
    }

    pub(super) fn count() {
        DIGESTS.with(|digests| digests.set(digests.get().saturating_add(1)));
    }

    pub(super) fn computed() -> u64 {
        DIGESTS.with(std::cell::Cell::get)
    }
}

#[cfg(test)]
mod public_state_decodes {
    thread_local! {
        static DECODED: std::cell::RefCell<Vec<u32>> = const { std::cell::RefCell::new(Vec::new()) };
    }

    pub(super) fn record(object_id: u32) {
        DECODED.with(|decoded| decoded.borrow_mut().push(object_id));
    }

    pub(super) fn take() -> Vec<u32> {
        DECODED.with(|decoded| std::mem::take(&mut *decoded.borrow_mut()))
    }
}
