# WP1-WP7 Closure Audit

This audit records the sequential review pass over Work Packages 1 through 7.
It is a status artifact, not a planning queue.

| WP | Requirement / intention | Current execution review | Follow-up status |
| --- | --- | --- | --- |
| WP1 | Route every secret-dependent runtime effect through a tiny confidential kernel and keep the secret-state inventory auditable. | Closed. Confidential raw-backend deployment is rejected, confidential entrypoints execute through the shared kernel machine, runtime-owned secret-state paths are visibility-restricted, and `docs/runtime-secret-state-inventory.md` names the remaining kernel-owned structures. | No in-scope follow-up. |
| WP2 | Use one canonical DSL/interpreter route across compiler, runtime, manifests, probes, and Lean. | Closed. Manifests carry named and slot kernel programs, the runtime executes the shared slot program through `uo-kernel-runtime` / `uo-core`, and Lean/probe check named-to-slot lowering plus schedule agreement. | No in-scope follow-up. |
| WP3 | Prove runtime-kernel refinement and secret confinement at the checked implementation boundary. | Closed for the paper boundary. The source-backed implementation, public-bridge, slot-adapter, residual-helper-shell, small/shared-kernel, meeting, direct machine-confinement, and outer confinement routes are all represented as Lean-checkable artifacts with tamper coverage. | Deeper semantics-of-Rust refinement below the checked boundary is out-of-charter future strengthening, not an open WP3 task. |
| WP4 | Prove source-to-kernel compiler correctness and demote direct artifact checking from the trust root. | Closed. W4.2, W4.4, W4.5, and W4.6 provide the source-to-kernel preservation, admission iff, manifest schedule exactness, and artifact-checker demotion chain for the admitted post-resolution source language. | Parser/preprocessing remains the stated front-end trust point; no open WP4 task. |
| WP5 | Minimize backend assumptions and give every surviving assumption explicit provenance. | Closed. The paper route is the cited JACM Path-ORAM route at the frozen interface; `bucketEncryptionINDCPA`, `metadataEncryptionINDCPA`, and `stashOverflowBounded` are paired with provenance records and static-drift checks. | A separately imported machine-checked external theorem is out-of-charter future strengthening. |
| WP6 | Close the hostile-host theorem over one explicit observer and deployment-assumption bundle. | Closed. The SGX observer, boundary-call model, persistent-I/O model, controller refinement, storage refinement, deployment assumptions, and six-checkpoint closure audit are pinned in Lean and in probe drift checks. | No in-scope follow-up. |
| WP7 | Canonicalize the proof architecture and artifact story. | Closed with one caveat found and fixed in this pass: `mplus-probe` still tried to execute rejected raw-confidential artifacts in correctness/leakage/overhead reports. The probe now reports those raw cases as expected rejections while requiring UO/ORAM variants to execute and match expected outcomes. | No in-scope follow-up. |

Documentation cleanup performed in this pass:

- top-level README TCB and claim-boundary wording now reflects WP4/WP5/WP6 closure
- runbook remaining-work language now records closure status instead of an active task list
- implementation roadmap no longer lists source correctness, backend provenance, or hostile-host closure as immediate next steps
- top-tier roadmap critical path / execution queue is marked retired, and stale W4 deferred/open notes are updated to point to their later closures
- trusted-kernel note now treats WP4/WP5/WP6 as closed inputs to the final paper target

Validation performed in this pass:

- `cargo test`
- `cargo fmt --check`
- `git diff --check`
