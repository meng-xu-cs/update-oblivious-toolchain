//! Wall-clock time the instrumented runtime spends on the parts of a call
//! that a measurement tells apart from the call's own work: copying the
//! committed state for the call to run on, loading the call's objects from
//! the copy, the hidden position-map witnesses of the call's start and end,
//! and the execution trace with the proof bundles it builds and checks. The
//! runtime keeps the witness from call to call and moves it by each call's
//! leaf transitions; it decodes one from storage for the first call, after a
//! load that no call made, and for an audit, which compares the kept witness
//! with that decode. Every call audits its witness before and after, unless
//! a measurement turns the audit off for its thread. The module also counts
//! the sealed records those decodes open, which no trace records.
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
    /// Copying the committed state, ciphertext included, for a call to run
    /// on.
    pub staging_ns: u128,
    /// Loading the call's objects from that copy: copying each one's storage
    /// again and decoding it.
    pub load_ns: u128,
    /// The position-map witnesses of the calls: copying the kept one,
    /// moving it by a call's leaf transitions, and decoding it from storage
    /// where that is done.
    pub witness_ns: u128,
    /// Building and checking the execution trace and its proof bundles.
    pub proof_objects_ns: u128,
    /// Sealed records the decodes of position-map witnesses opened.
    pub witness_records_opened: u64,
}

#[cfg(feature = "diagnostics")]
thread_local! {
    static TOTALS: Cell<InstrumentationTotals> = const {
        Cell::new(InstrumentationTotals {
            staging_ns: 0,
            load_ns: 0,
            witness_ns: 0,
            proof_objects_ns: 0,
            witness_records_opened: 0,
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

/// Run `f`, the copying of the committed state for a call.
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
