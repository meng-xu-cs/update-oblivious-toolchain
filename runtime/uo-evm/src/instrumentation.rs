//! Wall-clock time the instrumented runtime spends on the proof objects a call
//! exports, apart from the call's own work: the hidden position-map witnesses
//! it decodes from storage at the call's start and end, and the execution
//! trace with the proof bundles it builds and checks. Diagnostics builds keep
//! the totals per thread; other builds run the timed work as is.

#[cfg(feature = "diagnostics")]
use std::cell::Cell;
#[cfg(feature = "diagnostics")]
use std::time::Instant;

/// Time spent on proof objects, in nanoseconds, since the last
/// `take_instrumentation_timings` on this thread.
#[cfg(feature = "diagnostics")]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct InstrumentationTimings {
    /// Decoding every Path ORAM map's position-map witness from storage.
    pub witness_ns: u128,
    /// Building and checking the execution trace and its proof bundles.
    pub proof_objects_ns: u128,
}

#[cfg(feature = "diagnostics")]
thread_local! {
    static TIMINGS: Cell<InstrumentationTimings> = const {
        Cell::new(InstrumentationTimings {
            witness_ns: 0,
            proof_objects_ns: 0,
        })
    };
}

/// The timings accumulated on this thread, which start again from zero.
#[cfg(feature = "diagnostics")]
pub fn take_instrumentation_timings() -> InstrumentationTimings {
    TIMINGS.with(|timings| timings.replace(InstrumentationTimings::default()))
}

#[cfg(feature = "diagnostics")]
fn timed<T>(f: impl FnOnce() -> T, add: impl FnOnce(&mut InstrumentationTimings, u128)) -> T {
    let started = Instant::now();
    let out = f();
    let elapsed = started.elapsed().as_nanos();
    TIMINGS.with(|timings| {
        let mut total = timings.get();
        add(&mut total, elapsed);
        timings.set(total);
    });
    out
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
