//! Wall-clock time the instrumented runtime spends on the parts of a call
//! that a measurement tells apart from the call's own work: copying the
//! committed state for the call to run on, loading the call's objects from
//! the copy, the hidden position-map witnesses it decodes from storage at the
//! call's start and end, and the execution trace with the proof bundles it
//! builds and checks. It also counts the sealed records the witnesses open,
//! which no trace records. Diagnostics builds keep the totals per thread;
//! other builds run the timed work as is.

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
    /// Decoding every Path ORAM map's position-map witness from storage.
    pub witness_ns: u128,
    /// Building and checking the execution trace and its proof bundles.
    pub proof_objects_ns: u128,
    /// Sealed records the position-map witnesses opened.
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

/// Run `f`, the decoding of position-map witnesses.
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

/// Record that a position-map witness opened `records` sealed records.
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
