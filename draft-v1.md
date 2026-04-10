# Beyond Constant-Time: Update-Oblivious Programming Against Marker-Aware Write Oracles

**Anonymous submission**

> **Working-draft note.** This manuscript is written in submission style. Concrete attack figures are grounded in the attached pilot paper and evidence bundles. A small number of bracketed `[[FILL-IN]]` slots mark final defense-overhead values that should be populated once the generalized implementation is frozen.

## Abstract

Constant-time programming hides secret-dependent control flow and address traces, and is the standard software discipline for resisting timing and cache side channels. But many confidential-execution systems leak more than a control/address trace. When a fixed logical location is written back, an observer can often distinguish whether the write sets a distinguished default marker (`0→non-0`), clears to it (`non-0→0`), leaves the value unchanged (`X→X`), or changes one non-marker to another (`X→Y`). This marker-aware write oracle arises in value-sensitive gas metering, zero-aware storage backends, deterministic location-bound encryption, sparse/discard-aware filesystems, and cleanup paths that zero secret-bearing buffers. As a result, code can be constant-time yet still leak secrets through the semantic class of its updates.

We formalize this stronger adversary as `M+` and define **update-obliviousness**, a security property that strengthens constant-time with respect to semantic update classes. We substantiate the model across three settings. First, on stock Oasis Sapphire localnet, a host-visible `/proc/<pid>/io:wchar` counter distinguishes `0→0` from `0→1` with AUC `1.0` even when contract bytecode, control flow, touched slots, write count, wrapped-calldata gas, and public gas are fixed. Second, on a QEMU/qcow2/LUKS backend with zero-aware storage options, allocation metadata plus same-location ciphertext comparison realizes the full four-way oracle. Third, under a byte-level `M+` write oracle, we confirm 11 positive leaks in OpenSSL spanning X25519, ECDSA, RSA, and AEAD validity paths.

To defend, we present **update-oblivious programming**, a cross-layer toolchain consisting of semantic write linearization, an update-oblivious store and allocator, an `M+`-aware ORAM backend, a static verifier, and a leakage-testing harness. The design is guided by six principles: marker elimination, fresh writes, rerandomization, constant write budgets, address obliviousness, and semantic scrubbing. Together these provide an end-to-end path from constant-time to update-oblivious confidential execution. Our results identify semantic update classes as a missing axis in side-channel-secure programming and show how to close it in practice.

## 1 Introduction

Constant-time programming is the dominant software discipline for resisting timing and cache side channels. At a high level, the rule is familiar: do not let secrets influence control flow or memory addresses [1–4]. This rule has shaped modern cryptographic libraries, compiler transformations, verification tools, and secure-coding guidance [3–8].

Yet constant-time leaves a blind spot. Even if a program executes the same instructions and touches the same addresses in the same order, an observer may still learn something from **how the contents at those locations changed**. In many systems, writes are not opaque. Storage metering distinguishes writes that set a previously empty cell from writes that rewrite an occupied one. Sparse files and zero-aware block backends distinguish allocated data from logical zeros. Tweak-based encryption makes repeated plaintext at the same location comparable across time when freshness is absent or externally inferable. Cleanup code that writes zeros into secret-bearing buffers turns “was this byte already zero?” into a side channel. The resulting leakage is about the **semantic class of the update**, not the existence of the update.

This paper studies that missing axis.

We call the stronger observer `M+`. At a fixed logical location, `M+` combines two capabilities:

1. an equality/change oracle, which tells whether the old and new contents are the same; and
2. a special-marker oracle for a distinguished value, usually `0`, which tells whether old and/or new lie in the marker class.

The cross-product yields four update classes:

| Old value | New value | Class |
| --- | --- | --- |
| `0` | `non-0` | `SET` |
| `non-0` | `0` | `CLEAR` |
| `X` | `X` (including `0→0`) | `SAME` |
| `non-0 X` | `non-0 Y`, `X≠Y` | `UPDATE` |

This is strictly stronger than the usual “did it change?” model, which collapses `SET`, `CLEAR`, and `UPDATE` into one undifferentiated `CHANGED` event. The extra structure matters because distinguished marker states are semantically meaningful in real systems: empty storage cells, uninitialized pages, sparse activations, cleared secret buffers, absent balances, null pointers, and invalid tags all often map to a public default value.

The consequence is immediate and unsettling: a program can be constant-time and still leak secrets under `M+`.

A confidential smart contract is the clearest motivating example. Suppose a contract executes with fixed bytecode, fixed control flow, fixed storage-key sequence, fixed write count, and padded public gas. If it writes a fixed slot whose logical result is either `0` or `1`, a host observer may still distinguish whether the write was `0→0` or `0→1`. A preliminary EVM prototype that motivated this work already exposed this issue in terms of value-sensitive gas metering. But the problem is not really about “gas.” Gas is only one manifestation of a more general phenomenon: **semantic update leakage survives even after control-flow and address leakage have been equalized**.

The same phenomenon appears outside blockchain. In a zero-aware qcow2 backend exported through `qemu-nbd`, a host can distinguish whether a logical sector became allocated data, returned to a zero class, stayed equal, or changed ciphertext at the same location. In OpenSSL, we find that secure cleanup and deterministic-nonce code paths leak selected key predicates to an `M+` observer, even though the code was written for conventional constant-time threats. More strikingly, several of the strongest leaks arise exactly where developers attempted to be security-conscious—e.g., in `clear_free` and `secure_clear_free` paths.

This yields the central thesis of the paper:

> **Constant-time is not enough once the adversary can observe semantic update classes.**

To close the gap, we introduce **update-oblivious programming**: a programming discipline and toolchain that extends constant-time with constraints on the semantic classes of writes. Update-obliviousness requires more than fixed control and fixed addresses. It requires that, for any two secret-equivalent executions with the same public inputs, the attacker’s observed update-class trace be identical as well.

Our approach is cross-layer. At the language/compiler layer, we extend control-flow linearization into **semantic write linearization** so that secret-dependent writes are expressed through update-oblivious primitives rather than raw stores. At the runtime layer, we build an **update-oblivious store** that eliminates observable marker writes, avoids in-place secret-dependent overwrites, rerandomizes repeated logical values, equalizes write budgets, and pushes dynamic containers through full-scan or ORAM-backed abstractions. At the verification layer, we add a linter/verifier that checks whether a program is update-oblivious under `M+`. At the measurement layer, we provide a dudect-like differential-testing harness for `M+` leakage.

The point is not to replace constant-time; it is to finish it. Update-oblivious programming is a strict strengthening of constant-time for programs whose threat model includes host-visible writes, storage metadata, ciphertext equality, sparse-state provenance, or cleanup traces.

### Contributions

This paper makes four contributions.

**A new adversary model and security property.** We formalize the marker-aware write oracle `M+` and define update-obliviousness, a noninterference-style property over traces that include semantic update classes. We show that update-obliviousness strictly strengthens constant-time.

**Cross-domain evidence that the model is real.** We validate `M+` in three distinct settings: (i) a concrete attack on stock Oasis Sapphire localnet, where host-visible I/O counters distinguish confidential state transitions despite equalized public controls; (ii) a zero-aware encrypted qcow2 backend, where allocation metadata and same-location ciphertext comparison expose the full four-way oracle; and (iii) 11 positive reports on OpenSSL, covering X25519, ECDSA, RSA, and AEAD validity paths under a byte-level `M+` write oracle.

**A defense stack, not just attacks.** We present update-oblivious programming as a practical discipline and system design. Its core principles are marker elimination, fresh writes, rerandomization, constant write budgets, address obliviousness, and semantic scrubbing. We instantiate these ideas through semantic write linearization, an update-oblivious store and allocator, `M+`-aware ORAM, a verifier, and a differential leakage tester.

**A path to deployment in confidential execution systems.** We show how the defense specializes to confidential EVMs, TEEs, and CVMs; why ORAM alone is necessary but not sufficient; and how backend policies such as zero detection, discard passthrough, allocation-depth export, and deterministic same-location encryption interact with software defenses.

## 2 Preliminaries and Motivation

### 2.1 Constant-time and what it omits

Constant-time programming was created to stop attackers from learning secrets from timing variation [1]. In modern systems work, the notion is usually strengthened to an observational model over control flow and memory addresses: for a fixed public input, two executions that differ only in secrets should execute the same instruction trace and access the same sequence of memory locations [2–4]. Compiler work such as control-flow linearization makes this principle practical at larger scales [6–8].

This model is powerful, but it is intentionally value-oblivious. The observer sees *which* location is touched, not *how its contents relate before and after the write*. That omission is usually reasonable for conventional cache-based timing attacks, because the attack channel is tied to address selection or total latency rather than to semantic relationships between old and new contents.

Our claim is that this omission is no longer benign in confidential execution and storage settings.

### 2.2 A motivating example: fixed writes that still leak

Consider a confidential program that computes a secret predicate and writes the result to a fixed location:

```text
r := f(secret)          // r ∈ {0,1}
store(slot, r)          // same slot every time
```

Suppose that every execution uses the same code path, touches the same set of locations, performs the same number of reads and writes, and even pays the same public gas or emits the same public envelope size. Under the traditional constant-time observer, these executions are indistinguishable.

Under `M+`, they are not. If `slot` currently holds `0`, then `store(slot,0)` produces `SAME` while `store(slot,1)` produces `SET`. If `slot` currently holds `1`, then `store(slot,1)` produces `SAME` while `store(slot,0)` produces `CLEAR`. The semantic class of the update leaks a secret bit.

A preliminary EVM prototype already suggested this issue through storage-gas classes: zero-to-nonzero, nonzero-to-zero, same-value, and nonzero-to-different-nonzero writes must be treated separately. Our goal is to lift that insight out of the EVM and state it in its more general form.

### 2.3 Marker-aware write observations

The key observation is that many systems privilege a **marker class** of values, often but not always `0`. The marker may denote “empty,” “unallocated,” “cleared,” “default,” or “invalid.” If an observer can tell whether a location lies in that class before or after a write, and can also tell whether the location changed at all, then the observer learns more than a boolean “changed / unchanged” bit.

We therefore define the leakage alphabet:

- `SET`: old value is in the marker class, new value is not.
- `CLEAR`: old value is not in the marker class, new value is.
- `SAME`: old and new values are equal.
- `UPDATE`: neither value is in the marker class, and the values differ.

`0` is our concrete running marker because it is the most common and best motivated in the systems we study. But the abstraction generalizes to any public equivalence class `D` of distinguished values—e.g., `NULL`, “default page,” or “empty entry.”

## 3 The `M+` Adversary and Update-Obliviousness

### 3.1 Observation model

Let a program execute on public input `p` and secret input `s`. We write its concrete execution as a sequence of events over instructions, addresses, and writes. For each write to logical location `ℓ`, let `old` be the value stored at `ℓ` just before the write and `new` the value just after.

We define the marker-aware classification function with respect to a distinguished marker set `D`:

\[
\mathsf{class}_D(old,new) =
\begin{cases}
\mathsf{SAME} & \text{if } old = new \\
\mathsf{SET} & \text{if } old \in D \land new \notin D \\
\mathsf{CLEAR} & \text{if } old \notin D \land new \in D \\
\mathsf{UPDATE} & \text{if } old \notin D \land new \notin D \land old \neq new
\end{cases}
\]

In the remainder of the paper, `D = {0}` unless stated otherwise.

The ordinary memory observer `M` sees location accesses but not their semantic classes. A transition observer `MΔ` additionally sees whether `old = new`. Our adversary `M+` sees the trace

\[
\mathsf{Obs}_{M^+}(P,p,s) = \langle (\ell_i, \mathsf{class}_0(old_i,new_i)) \rangle_i
\]

possibly interleaved with the standard instruction and address trace when those channels are also available.

The importance of this formulation is that it is **mechanism-agnostic**. `M+` does not assume one particular channel. The same abstract observation may be realized by gas metering, host-visible I/O counters, page provenance, discard-aware storage metadata, ciphertext equality at a fixed location, silent-store behavior, or byte-level write tracing.

### 3.2 Security definition

Let `pub(x)` project an input onto its public fields. We say program `P` is **update-oblivious under `M+`** if for every pair of inputs `x1, x2` such that `pub(x1) = pub(x2)`,

\[
\mathsf{Obs}_{M^+}(P,x_1) = \mathsf{Obs}_{M^+}(P,x_2).
\]

This definition is intentionally strong: it requires the full `M+` trace to be a function of the public input only. As in constant-time, intended outputs may still reveal information if they are public; update-obliviousness constrains only unintended side-channel observations.

In practice, we use the definition in a modular way: primitive operations, library abstractions, and compiler transformations are shown to preserve update-obliviousness, and a verifier checks that all secret-dependent code paths are routed through those abstractions.

### 3.3 Relation to constant-time and transition-only models

`M+` strictly refines both ordinary address-trace observers and transition-only observers.

**Proposition 1 (strengthening).** If a program is update-oblivious under `M+`, then it is constant-time with respect to the usual control/address observer `M`.

**Proof sketch.** `M+` includes all the information needed to reconstruct the existence and location of writes, and our toolchain separately requires fixed control flow and fixed access schedules for secret-dependent computation. Thus indistinguishability under `M+` implies indistinguishability under the weaker observer `M`.

**Proposition 2 (strict separation).** There exists a program that is constant-time under `M` but not update-oblivious under `M+`.

**Proof sketch.** The fixed-slot write example above suffices. The program has identical control flow and address trace for all secret inputs, yet its update class at `slot` depends on whether the logical result is `0` or `1` and on the prior value of `slot`.

This separation matters because it shows that `M+` is not a cosmetic re-labeling of conventional constant-time. It captures a qualitatively different source of leakage.

### 3.4 Relation to structured leakage and constant-resource work

At a formal level, `M+` can be seen as a particular instrumented semantics in the sense of structured leakage [4]. That is a feature, not a bug: it lets us reuse the language of leakage functions, self-composition, and compilation preservation. But identifying `M+` is still a substantive contribution for three reasons.

First, the leakage alphabet is new and motivated by deployed systems rather than by a purely formal design exercise. Second, it cleanly unifies two previously separate families of leakage: **freshness/equality leaks** (e.g., ciphertext side channels, silent stores, data-at-rest prefetch leakage) and **marker-state leaks** (e.g., sparse/default-value inference, unmap/discard semantics, empty-page detection). Third, it demands new defenses. Constant-resource or constant-cost techniques equalize aggregate expenditure [4,5], but a program can have identical total cost and still reveal a per-location `SET/CLEAR/SAME/UPDATE` trace.

## 4 Where `M+` Comes From

A reasonable reviewer question is whether `M+` is contrived. This section explains why it is not.

### 4.1 Value-sensitive metering and confidential blockchains

Value-sensitive gas metering is the easiest way to see the phenomenon. In EVM storage semantics, zero-to-nonzero, nonzero-to-zero, same-value, and nonzero-to-different-nonzero writes are distinguished by public accounting rules. Equalizing only total public gas therefore does not hide confidential behavior if the runtime or host can still correlate with those underlying state transitions.

The important point for this paper is not the EVM-specific policy itself; it is the general lesson: once the system gives a distinguished treatment to the marker state, semantic update classes become observable.

### 4.2 Zero-aware encrypted storage backends

QEMU documents that `qemu-nbd` supports `--discard=unmap` and `--detect-zeroes=unmap`, and that zero writes can be converted into unmap operations when discard is also set to unmap [22]. QEMU also supports exposing allocation-depth and dirty-bitmap metadata to NBD clients [23]. The Linux kernel’s `dm-crypt` documentation states that IV construction incorporates sector numbers and warns that discard passthrough may leak information about ciphertext layout [24]. Red Hat’s LUKS documentation states that the default cipher is `aes-xts-plain64` [25]. Taken together, these facts make the following inference realistic: a host can often learn whether a logical block is in a zero/unmapped class, and whether data at a fixed logical sector stayed the same or changed across snapshots.

### 4.3 Ciphertext and sparsity channels on confidential VMs

CIPHERLEAKS showed that a privileged observer can exploit ciphertext side channels on AMD SEV, including SEV-SNP, to recover secrets from constant-time OpenSSL implementations [11]. Relocate-Vote later showed that confidential-VM memory encryption can leak sparsity or prevalent-value information through page relocation primitives, precisely because system-physical-address tweaks preserve exploitable structure [16]. SNPeek demonstrates that software-visible side channels remain practically measurable on production AMD SEV-SNP hardware and can guide mitigations such as oblivious memory and differential privacy [17].

These results expose the two ingredients that `M+` needs: same-location equality/change information and marker/default-value information.

### 4.4 Cleanup paths and memory-centric side channels

OpenSSL-style cleanup code often zeroes buffers before free. That is normally treated as good hygiene. Under `M+`, it can leak. If a secret-dependent byte is already zero, then a subsequent “secure clear” yields `SAME`; otherwise it yields `CLEAR`. The same-location comparison literature, including Cipherfix and Zebrafix, explicitly highlights freshness of memory stores as necessary to mitigate ciphertext and silent-store channels [12,21]. But freshness alone does not eliminate `SET` and `CLEAR`. Once marker states are observable, we need both **freshness** and **marker elimination**.

This is the conceptual move of the paper: `M+` unifies memory-freshness leakage with marker-state leakage.

## 5 Empirical Evidence Across Three Stacks

This section presents the evidence that motivates the paper. The point is not merely that we can construct a formal observer; it is that the observer is realized in practice across three very different settings.

### 5.1 A concrete attack on stock Oasis Sapphire localnet

Our first case study targets stock Oasis Sapphire localnet. The attack is intentionally conservative:

- the runtime binary is unmodified;
- all measured calls are wrapped confidential transactions;
- each sample uses a fresh deployment;
- contract bytecode, control flow, touched-slot sequence, write count, and final gas padding are fixed; and
- the public wrapped-calldata gas is calibrated and then enforced exactly per host session.

The canonical workload is a confidential classifier that writes either `0` or `1` into a fixed storage-slot range. Because every sample starts from empty storage, the main pair compares `0→0` against `0→1`. A same-same control compares two distinct confidential tokens that both map to `1`, isolating update-class leakage from other effects.

The primary result is striking. On the canonical workload, the host-visible channel `runtime_proc_wchar_bytes` validates across all `3/3` independent sessions with main-pair AUC `1.000`, same-same control AUC `0.4175`, and public controls near chance (`receiptGasUsed = 0.4931`, `publicTxDataGas = 0.5000`, `adjustedGas = 0.4931`). Aggregated raw separation is clean: the smallest observed `0→1` sample still exceeds the largest observed `0→0` sample by `66,537` bytes.

A secondary broadening campaign uses a simpler branchless projection workload (`value := token & 1`) to show that the phenomenon is not tied to the original equality-style classifier. In that campaign, four channels validate: `runtime_proc_wchar_bytes` and `compute_proc_wchar_bytes` (both AUC `1.000`), plus two scheduler-CPU channels (both AUC `0.9874`).

Two details matter for scientific strength.

First, the attack is not just “residual gas.” The strongest channel is a host-visible Linux process I/O counter outside the runtime boundary. Second, the public controls are unusually strict: the wrapper ciphertext size is calibrated session-locally and enforced as an exact match, so the result is not explained by accidental variation in the confidential envelope.

We stress a limitation up front: localnet uses `debug_mock_tee: true`, so this is mechanism evidence on the stock Sapphire-style confidential-execution stack, not a claim of a proven exploit against a real SGX-backed production deployment. But it is still the kind of evidence that security reviewers rightly ask for: a concrete, reproducible leak on a production-grade software stack under tight controls.

### 5.2 A four-way oracle on QEMU/qcow2/LUKS

Our second case study deliberately moves away from blockchains.

We instantiate the adversary on a qcow2 image exported through `qemu-nbd` with `discard=unmap` and `detect-zeroes=unmap`. The backing store is encrypted with LUKS, and we focus on one logical slot whose size is aligned to the qcow2 cluster size. The attacker never learns plaintext. Instead, it observes only:

1. backend map state for the target region (e.g., present / zero / data), and
2. ciphertext equality at the same logical location when both snapshots are backed by data.

When the qcow2 cluster size is reduced to `4 KiB`, aligning the backend allocation unit with the logical slot size, the system realizes the full four-way oracle:

- `SET`: target region changes from `present=false, zero=true, data=false` to `present=true, zero=false, data=true`;
- `CLEAR`: target region changes from `present=true, zero=false, data=true` to `present=true, zero=true, data=false`;
- `SAME`: metadata and ciphertext remain unchanged;
- `UPDATE`: metadata remains in the data class while ciphertext changes.

A useful lesson comes from the failed coarse-grained run. With the default `64 KiB` cluster size, `CLEAR` collapsed into an apparent `X→X` observation because the target segment was too coarse. Once the cluster size was lowered to `4 KiB`, the full oracle became visible. This shows that the leakage is real, but mediated by backend granularity.

An even subtler observation is that the backend appears to leak slightly more than our minimal four-class model. A slot that is *cleared to zero* can remain `present=true, zero=true, data=false`, while a slot that was *never allocated* remains `present=false, zero=true, data=false`. In other words, some zero-state provenance can survive. We do not rely on that stronger oracle in the rest of the paper, but it reinforces the broader point: once the backend gives special treatment to a marker value, semantic update classes become observable.

### 5.3 Eleven positive leaks in OpenSSL

Our third case study asks whether the same model matters inside conventional cryptographic software.

To isolate the phenomenon, we use a synthetic observer that classifies byte-level writes at fixed logical locations into `SET`, `CLEAR`, `SAME`, and `UPDATE`. This is deliberately stronger than a pure ciphertext side channel, but it is exactly the observer our formal model studies.

The result is 11 positive reports across four classes of OpenSSL workloads:

- **X25519 key derivation** (`ecdh_x25519_derive`): 4 positive variants.
- **ECDSA signing** (`ecdsa_signing`): 4 positive variants.
- **RSA private operation** (`rsa_private_op`): 2 positive variants.
- **AES-GCM decrypt-and-verify validity path** (`decrypt_verify_validity_path`): 1 positive variant.

Representative examples are summarized in Table 1.

| Primitive | Secret predicate inferred | Representative site | Pre-patch evidence |
| --- | --- | --- | --- |
| X25519 derive | whether private scalar byte 3 is zero | `secure_clear_free:ossl_ecx_key_free:...:32+3` | dominant split `CLEAR` vs `SAME`; MI `1.0`; AUC `1.0` |
| ECDSA signing | whether private scalar bit 96 equals 1 | `clear_free:ossl_gen_deterministic_nonce_rfc6979:...:104+87` | dominant split `CLEAR` vs `SAME`; MI `1.0`; AUC `1.0` |
| RSA private op | whether CRT exponent byte 26 is zero | `cleanse:CRYPTO_clear_free:...:128+41` | dominant split `CLEAR` vs `SAME`; MI `1.0`; AUC `1.0` |
| AES-GCM decrypt/verify | whether the supplied ciphertext/tag pair is valid | `gcm.ctx_buf.cipherfinal+0` | MI `1.0`; AUC `1.0` |

Two qualitative lessons stand out.

First, many of the strongest leaks arise in cleanup or validation code rather than in the cryptographic arithmetic itself. For example, X25519 leaks through `secure_clear_free`, ECDSA through deterministic-nonce cleanup, and RSA through `CRYPTO_clear_free`. Security-conscious zeroization is exactly where `M+` bites.

Second, the reports contain causality checks in the form of targeted local patches. These patches do not implement our full toolchain, but they are valuable mitigation evidence. For 7 of the 11 variants (all 4 X25519 variants, both RSA variants, and the AES-GCM validity-path leak), the strongest surviving post-patch signal drops all the way to mutual information `0.0` and AUC `0.5`. For the 4 ECDSA variants, the patches reduce the signal from perfect separation to residual MI `0.065508` and AUCs in the `0.546–0.575` range. In other words, the side channel is causal and locally suppressible.

This matters for paper positioning. The OpenSSL evidence shows that `M+` is not a blockchain curiosity. It is a programming problem.

### 5.4 Lessons from the evidence

Taken together, the three case studies establish three claims.

**(1) `M+` is cross-domain.** We see it in confidential smart contracts, encrypted virtual disks, and mainstream cryptographic software.

**(2) Equalizing only public signals is insufficient.** Fixed control flow, fixed address traces, padded gas, fixed write count, and even exact public-envelope equalization do not remove semantic update leakage.

**(3) Defense is possible but currently ad hoc.** The OpenSSL patch evidence suggests that individual sites can be fixed. What is missing is a general discipline and toolchain.

That is the role of update-oblivious programming.

## 6 Update-Oblivious Programming

Update-oblivious programming extends constant-time with a new requirement: secret-dependent computation must not induce secret-dependent **semantic update traces**. Achieving this requires more than one trick. The rest of the design follows from six principles.

### 6.1 Principle 1: marker elimination

Do not materialize the distinguished marker as an observable storage value.

If logical `0` is represented as physical `0`, then any observer who can tell “marker vs non-marker” immediately recovers `SET` and `CLEAR`. The remedy is to separate *logical meaning* from *physical representation*. A logical marker value is encoded as a tagged non-marker representation whose image excludes the marker class.

For a scalar cell, the simplest scheme is:

- store a nonzero payload in every version slot;
- maintain a status tag that says whether the logical value is the marker; and
- decode logical `0` only after reading the tag.

This is exactly the intuition already suggested by the preliminary EVM design, where logical zero is represented by a nonzero sentinel plus a status bit. Our contribution is to make it a general design principle rather than an EVM-specific gas workaround.

**Lemma 1 (marker elimination).** If every observable data write is drawn from an encoding whose image excludes the distinguished marker set `D`, then observable `SET` and `CLEAR` events cannot arise on those data locations.

The catch is that metadata is not exempt. Tags, pointers, allocator state, version counters, and occupancy maps must themselves be stored through the same discipline, or they simply become the new leak.

### 6.2 Principle 2: fresh writes

Do not perform secret-dependent in-place overwrites.

If a location is reused, then an observer can compare its old and new states. That is exactly what `M+` exploits. The canonical way to break the comparison is to avoid secret-dependent reuse. Each logical update is instead recorded as a fresh physical version. Old versions are retired later on a public schedule.

A preliminary EVM design already used monotonically increasing versions so that repeated logical writes never target the same storage slot. We generalize that idea to runtime stores, allocators, and ORAM-backed containers.

### 6.3 Principle 3: rerandomization

Fresh writes are necessary but not always sufficient.

If the same physical location must be reused—for example in a fixed-size scratch buffer or a mandatory layout—then the physical representation must still change on every logical write, even when the logical value is unchanged. This is the same “freshness” intuition that underlies Cipherfix and Zebrafix [12,21]. Counters, masks, or fresh nonces can achieve it.

Under `M+`, however, rerandomization alone is not enough. It removes `SAME` at a reused location, but not `SET` and `CLEAR` if raw marker values remain observable. This is why the paper insists on the joint design: **freshness plus marker elimination**.

### 6.4 Principle 4: constant write budgets and public maintenance schedules

Even with marker elimination and fresh writes, secret-dependent variation in the number or timing of physical writes can reintroduce leakage.

We therefore equalize:

- the number of physical writes per logical operation,
- the number of allocations and frees,
- the number of compaction or garbage-collection actions, and
- the timing/placement of maintenance work.

This is the store-layer analogue of constant-time padding. But unlike “pad total gas,” it is applied at the granularity that matters to `M+`: the per-operation physical write schedule.

### 6.5 Principle 5: address obliviousness

`M+` does not replace address-obliviousness; it adds to it.

If a program indexes a table with a secret key, then hiding update classes is not enough—the accessed location itself leaks. Dynamic data structures therefore need either:

1. full deterministic scans over a public-bounded container, or
2. ORAM-like abstractions that hide the logical access pattern.

This is where update-obliviousness meets classic ORAM [18]. But standard ORAM is not automatically enough, because its security goal is usually indistinguishability of physical access traces. It does not inherently prevent raw marker writes, discard/unmap semantics, or same-location comparison on physical buckets. The backend must be **`M+`-aware** as well.

### 6.6 Principle 6: semantic scrubbing

Secure deletion does not have to mean “write zero.”

For ephemeral secret buffers, the security goal of scrubbing is to destroy recoverability of the old secret, not to enforce a canonical marker byte. Under `M+`, raw zeroization is actively dangerous because it turns “was this byte already zero?” into a `CLEAR` versus `SAME` distinction. A better semantic-scrub API overwrites with fresh nonzero randomness, marks the object retired in side metadata, and postpones physical reclamation to a public schedule.

This is the principle that most directly addresses the OpenSSL cleanup leaks.

## 7 The UO Toolchain

We now package the six principles into a concrete toolchain.

### 7.1 Semantic write linearization (SWL)

Control-flow linearization eliminates secret-dependent branching by executing all relevant blocks and predicating their effects [6–8]. Our starting point is the same, but `M+` requires an extra step: secret-dependent *writes* must be routed through update-oblivious primitives rather than raw stores.

We therefore extend CFL into **semantic write linearization (SWL)**.

Given a public-bounded control-flow graph:

1. **Linearize control flow.** Compute a deterministic traversal order and derive predicates for each block, as in prior CFL work [6–8].
2. **Predicatize assignments.** Rewrite ordinary assignments as `x := select(pred, new, x)`.
3. **Lift writes.** Rewrite each write `store(ℓ, v)` as `uo_store(pred, ℓ, v)`, where `uo_store` is a primitive that emits a fixed physical action sequence regardless of `pred`.
4. **Normalize exceptional behavior.** Operations that may abort are rewritten into non-aborting forms that return status flags, so that reverts do not create secret-dependent early exits.

The crucial part is step 3. A raw predicated store such as `store(ℓ, select(pred, v, old))` is still unsafe under `M+`, because it can produce `SET`, `CLEAR`, `SAME`, or `UPDATE` depending on `pred` and the prior contents. `uo_store` instead appends a fresh encoded record, emits dummy writes when needed to equalize the budget, and updates metadata through the same discipline.

### 7.2 UO-Store

`UO-Store` is the runtime substrate that SWL targets.

At a high level, `UO-Store` is a log-structured, marker-free store with constant write budgets.

Each logical object is represented by:

- an append-only version chain or journal,
- encoded payloads that never materialize the distinguished marker,
- update metadata stored through the same encoding, and
- a public-bounded write budget that pads real updates with dummy ones.

A simplified scalar-cell write looks like this:

```text
uo_set(cell c, logical value v):
    enc  := EncodeNonMarker(v)
    slot := PublicNextSlot(c.region)
    PhysWrite(slot, enc)              // always non-marker
    PadToBudget(c.region)             // fixed number of writes
    AdvanceMetadata(c, slot)          // through UO-Store again
```

The invariant is that the underlying physical backend should see only a public-determined sequence of non-marker writes, maintenance actions, and rerandomized payloads.

#### Scalar cells and fixed records

For fixed-size scalars and records, UO-Store is relatively direct. This is where the preliminary EVM measurements are already informative: a source-level constant-gas select can be implemented with less than 30% overhead on primitive types, while scalar storage wrappers incur roughly `~2×` write overhead and `~6.5×` read overhead in the prototype baseline. These numbers are EVM-specific and not yet the final UO-Store measurements, but they establish that the scalar case is practical enough to matter.

#### Dynamic maps and associative state

Associative containers are harder because secrecy may affect both *which key is accessed* and *what update class occurs at that key*.

Our toolchain supports two backends.

**Full-scan backend.** For small public-bounded maps, every access scans the full capacity in a deterministic order. This is the direct generalization of the bounded constant-gas map idea. Its security story is simple but its overhead is severe; the preliminary prototype saw `24×–1100×` write overhead for bounded mappings depending on capacity.

**`M+`-aware ORAM backend.** For larger state, we use an ORAM or write-only ORAM substrate [18,19] but strengthen the physical-write discipline. Each bucket or block is written with rerandomized non-marker fillers, dummy and real writes are budget-equalized, and rebuild/compaction happens on a public schedule. This prevents a backend that exposes same-location comparison or marker-state metadata from learning more than the ORAM transcript should reveal.

### 7.3 Why ORAM is necessary but not sufficient

This point deserves to be explicit because it is easy to miss.

ORAM hides *which logical locations* are being accessed. `M+` leaks *how physical locations changed*. Standard ORAM security does not by itself say anything about marker-aware backend semantics. A physical bucket that becomes all-zero, is trimmed/discarded, or is repeatedly rewritten with identical data can still leak under a zero-aware or same-location observer.

Therefore, ORAM is necessary for secret-indexed data structures, but insufficient unless the ORAM implementation itself respects the six UO principles.

This observation also suggests a promising optimization frontier. Because `M+` is fundamentally a write-centric threat, update-oblivious backends can often exploit write-only ORAM or log-structured WoORAM variants [19] to achieve lower overhead than full read/write ORAM when the read side is already hidden by fixed scans or public-bounded caching.

### 7.4 UO-Allocator and semantic scrub APIs

Heap allocation is a major source of cleanup leakage.

`UO-Allocator` therefore changes the usual semantics of free:

- a free operation does **not** immediately materialize a zeroed block at the same location;
- instead, the allocator writes fresh nonzero scrub data or leaves the block in place behind retired metadata;
- the object becomes logically unavailable immediately; and
- physical reuse or reclamation occurs on a public schedule.

For languages like C and Rust, we expose this through a small API:

- `uo_alloc<T>(...)`
- `uo_free<T>(...)`
- `uo_zero<T>(...)` for logical marker assignment without physical marker writes
- `uo_wipe(ptr,n)` for semantic scrubbing

The OpenSSL reports strongly suggest that this allocator path is not a side concern but a central requirement.

### 7.5 UO-Check: a verifier/linter for `M+`

A practical discipline needs tooling.

`UO-Check` is our static verifier/linter for update-obliviousness. At minimum, it enforces four classes of rules:

1. **No raw secret-tainted stores.** Any store whose address or value is secret-tainted must target a UO primitive.
2. **No secret-tainted marker writes.** Writing a distinguished marker to an observable location requires either a UO encoding or an explicit public declassification.
3. **Public-boundedness.** Loop bounds, recursion bounds, and container capacities that affect the access schedule must be public.
4. **Backend discipline.** Metadata objects, allocators, and buffer-management paths must themselves be UO-safe.

Internally, the checker can be implemented as a combination of taint analysis, effect typing, and self-composition over an instrumented semantics that emits `M+` traces. The exact implementation language can vary by target: EVM IR for smart contracts, LLVM IR for C/C++, and MIR/HIR-level analyses for Rust.

### 7.6 `M+`-Probe: dynamic leakage testing

Static checking is necessary but not sufficient. Real systems include runtimes, allocators, libraries, host kernels, and storage backends that can invalidate source-level assumptions.

We therefore pair UO-Check with `M+`-Probe, a dynamic differential tester inspired by dudect-style workflows but specialized to marker-aware write classes. For each candidate leak, the harness:

- runs paired experiments that differ only in secrets,
- records either direct write-class traces or host-visible proxies,
- computes mutual information and AUCs,
- includes same-same and public-control experiments, and
- supports causality checks through patch/rebuild/retest.

This is the methodology already used in the Oasis and OpenSSL evidence bundles. Making it a first-class part of the toolchain is essential for end-to-end claims.

### 7.7 Specialization to a confidential EVM

A confidential EVM is a compelling deployment target because the preliminary work already identified the problem inside Solidity/EVM storage semantics.

Our specialization has two layers.

**Source-to-source front-end.** Secret-dependent Solidity code is transformed using SWL plus bounded UO containers, closely following prior control-flow linearization ideas but replacing gas-centric reasoning with general `M+` reasoning.

**Runtime backend (`UO-EVM`).** Instead of exposing raw `SSTORE` semantics to the enclave host, the EVM routes persistent state through UO-Store. Scalar state uses append-only non-marker encodings; dynamic mappings use either full-scan containers for small public capacities or `M+`-aware ORAM for larger ones. Gas equalization becomes only a surface property; the substantive protection comes from equalizing the underlying semantic update trace.

This directly addresses the concern that “constant gas” is too narrow and not end-to-end. `UO-EVM` turns the idea into a general runtime discipline.

## 8 Evaluation

This section is organized around four questions.

- **Q1.** Does `M+` arise in real stacks under strong controls?
- **Q2.** Are the observed leaks causal rather than statistical accidents?
- **Q3.** Which defenses are necessary, and which are insufficient on their own?
- **Q4.** What overhead should we expect from update-oblivious defenses?

### 8.1 Methodology and metrics

Our attack evaluations use the following metrics.

- **AUC** for binary discrimination between two secret classes.
- **Mutual information** for site-level leakage in write-class traces.
- **Same-same controls** to rule out background instability.
- **Public controls** to confirm that public gas, envelope size, or other public features remain near chance.
- **Causality checks** via targeted local patches.

A channel counts as validated only if the main-pair separation is high while same-same and public controls remain near chance.

### 8.2 Concrete attack results

Table 2 summarizes the strongest concrete evidence.

| Setting | Observation | What is fixed | Leak result |
| --- | --- | --- | --- |
| Sapphire canonical workload | `runtime_proc_wchar_bytes` | bytecode, CFG, touched slots, write count, final gas padding, exact public wrapped-calldata gas | main AUC `1.000`, control AUC `0.4175` |
| Sapphire projection workload | runtime/compute `wchar`, scheduler CPU | same as above, simpler branchless classifier | 4 validated channels, AUC `0.9874–1.000` |
| qcow2/LUKS/QEMU | allocation metadata + same-location ciphertext equality | plaintext hidden; 4 KiB cluster alignment | full `SET/CLEAR/SAME/UPDATE` oracle |
| OpenSSL X25519 | byte-level `M+` write classes | fixed public input, deterministic harness | MI `1.0`, AUC `1.0` |
| OpenSSL ECDSA | byte-level `M+` write classes | fixed public input, deterministic harness | MI up to `1.0`, AUC `1.0` |
| OpenSSL RSA | byte-level `M+` write classes | fixed public input, deterministic harness | MI `1.0`, AUC `1.0` |
| OpenSSL decrypt/verify | byte-level `M+` write classes | fixed public input, deterministic harness | MI `1.0`, AUC `1.0` |

These results answer Q1 decisively: semantic update leakage is not a single-system artifact.

### 8.3 Mitigation evidence from targeted patches

Although the full generalized UO toolchain is the main defense contribution of the paper, the current report bundles already contain meaningful mitigation evidence.

Table 3 summarizes representative pre- vs post-patch behavior from the OpenSSL case studies.

| Primitive | Pre-patch strongest signal | Post-patch strongest signal |
| --- | --- | --- |
| X25519 derive | MI `1.0`, AUC `1.0` | MI `0.0`, AUC `0.5` |
| RSA private op | MI `1.0`, AUC `1.0` | MI `0.0`, AUC `0.5` |
| AES-GCM decrypt/verify | MI `1.0`, AUC `1.0` | MI `0.0`, AUC `0.5` |
| ECDSA signing | MI `1.0`, AUC `1.0` | MI `0.065508`, AUC `0.546–0.575` |

This answers Q2: the leaks are causal. Small, localized changes at the right write sites collapse the signal.

It also answers Q3 in part. Merely “being constant-time” is not enough. Fixing the right write sites is enough to matter.

### 8.4 What the preliminary EVM baseline already tells us about cost

The source-level EVM prototype provides a useful baseline for Q4.

- update-oblivious/constant-gas conditional select on primitive fixed-width types costs **less than 30%** overhead in the evaluated microbenchmarks;
- scalar storage wrappers incur about **`~2×` write overhead** and **`~6.5×` read overhead** in that prototype; and
- naive bounded full-scan maps become extremely expensive, with read overheads ranging from roughly **`75×`** to **`2289×`** and write overheads ranging from **`24×`** to **`1099×`**, depending on capacity and value type.

These numbers are valuable for two reasons.

First, they show that the scalar case is practical enough that an `M+`-aware discipline is worth adopting. Second, they justify the paper’s emphasis on specialized runtime backends and ORAM-like designs for dynamic state: the naive full-scan solution is scientifically clean, but economically untenable at scale.

### 8.5 Final defense evaluation to report in the completed submission

The fully generalized UO toolchain should report three additional experiments in the final submission version.

1. **End-to-end UO-EVM evaluation on the Sapphire workloads.**
   - Pre-defense: canonical and projection workloads as reported above.
   - Post-defense: identical workloads compiled to `UO-EVM` or lowered through SWL + UO-Store.
   - Success criterion: no validated host-visible channels under the same decision rule; public outputs/functionality unchanged.
   - Overheads to report: gas, runtime latency, state size, and compaction overhead.

2. **Compiler/runtime evaluation on the OpenSSL harnesses.**
   - Pre-defense: 11 positive `M+` reports.
   - Post-defense: residual MI/AUC after UO allocator, semantic scrub APIs, and freshness/marker elimination passes.
   - Overheads to report: runtime slowdown, code size, and memory overhead by primitive.

3. **Map-state scalability evaluation.**
   - Compare full-scan bounded maps, `M+`-aware Path ORAM, and `M+`-aware write-only ORAM.
   - Report break-even points and asymptotic/empirical behavior.

We recommend a final summary table of the following form once the experiments complete:

| Workload | Strongest pre-defense channel | Strongest post-defense channel | Overhead |
| --- | --- | --- | --- |
| Sapphire canonical | `runtime_proc_wchar_bytes`, AUC `1.0` | `[[FILL-IN]]` | `[[FILL-IN]]` |
| Sapphire projection | 4 validated channels | `[[FILL-IN]]` | `[[FILL-IN]]` |
| X25519 derive | MI `1.0`, AUC `1.0` | `[[FILL-IN]]` | `[[FILL-IN]]` |
| ECDSA signing | MI `1.0`, AUC `1.0` | `[[FILL-IN]]` | `[[FILL-IN]]` |
| RSA private op | MI `1.0`, AUC `1.0` | `[[FILL-IN]]` | `[[FILL-IN]]` |
| Decrypt/verify | MI `1.0`, AUC `1.0` | `[[FILL-IN]]` | `[[FILL-IN]]` |

The key scientific point is that the paper already has hard attack evidence and concrete mitigation evidence. The final step is to populate the generalized defense numbers.

### 8.6 Comparison with insufficient defenses

The evidence also lets us rule out three tempting but insufficient defenses.

**Equalize total public gas.** Sapphire shows that exact public wrapped-calldata gas and padded final gas do not prevent host-visible update-class leakage.

**Use conventional ORAM alone.** ORAM hides which location is accessed, but does not by itself prevent marker-aware backend semantics or same-location comparison on physical buckets.

**Always zero on free.** OpenSSL shows that zeroization is itself a source of `M+` leakage. Secure wipe must be redefined semantically, not canonically.

## 9 Discussion

### 9.1 Why this is more than “just another leakage function”

One could object that `M+` is merely one more point in the large space of possible leakage functions. Formally, that is true. But security research advances precisely by identifying which leakage functions are both realistic and previously neglected.

`M+` matters because it captures a recurring systems pattern:

- a value class with privileged semantics (`0`, empty, default, invalid);
- an observer who can compare a location to itself across time; and
- code that developers already believe to be “constant-time enough.”

The paper’s novelty is not only the formalization. It is the recognition that these ingredients recur across confidential smart contracts, encrypted storage, confidential VMs, and cryptographic cleanup code, and that they require a common defense story.

### 9.2 Choosing the marker set

We use `0` throughout because it is the most pervasive marker in practice. But other applications may want:

- `NULL` or all-ones sentinels,
- default pages or sparse tensors,
- “erased” vs “never allocated,”
- special IEEE floating-point values,
- application-defined empty-entry encodings.

Our definitions generalize to any public set `D` of distinguished marker values. The engineering challenge grows with `|D|`, but the principle does not change: the attacker learns membership in `D`, not exact content.

### 9.3 Deployment guidance

The paper’s defense recommendations split naturally by layer.

**Application/compiler layer.** Use SWL, UO cells/maps, public bounds, and UO-Check.

**Runtime layer.** Replace raw stores, allocators, and frees with UO-Store and UO-Allocator. Treat metadata as sensitive.

**Backend/storage layer.** Disable or avoid zero-detection, discard passthrough, and provenance-rich metadata exports on confidential workloads when possible. If same-location encryption lacks freshness, add it. If the backend forces zero-aware semantics, compensate above it.

**System-operator layer.** Treat `/proc` counters, file-I/O traces, scheduler metrics, and storage metadata as potential side channels in confidential deployments.

### 9.4 Approximate defenses

Exact update-obliviousness will sometimes be too expensive, especially for large associative state. In those cases, the system designer has three fallback options:

1. shrink the trusted/output surface so the leak is irrelevant;
2. use approximate defenses such as randomized batching or differential privacy, as suggested by recent CVM work [17]; or
3. isolate the sensitive component into a smaller exact-UO region and let the rest remain merely constant-time.

We do not claim that exact UO is always cheap. We claim that without it, a significant class of leaks remains unaddressed.

### 9.5 Threats to validity and limitations

Our work has several limitations.

**Oasis localnet is not production SGX.** The Sapphire result is concrete mechanism evidence on stock localnet, not a production exploit claim.

**OpenSSL uses a synthetic observer.** The byte-level `M+` oracle is stronger than any one deployed channel. Its purpose is to isolate the programming error class. The Sapphire and qcow2 case studies then show that the ingredients exist in realistic stacks.

**Unbounded structures remain difficult.** As with constant-time, public bounds or trusted backends are often required for practical enforcement.

**Update-obliviousness is not total secrecy.** It must be combined with constant-time, address obliviousness, memory safety, and ordinary cryptographic hygiene. It does not replace those properties.

### 9.6 Ethics and disclosure

We restricted our blockchain experiments to local reproduction, did not target production users or funds, and preserved the distinction between mechanism evidence and production exploit claims. The Sapphire issue was reported to the vendor via the supplied reporting materials. The OpenSSL and qcow2 case studies were carried out in controlled local environments.

## 10 Related Work

### Constant-time, structured leakage, and compiler support

Constant-time and its variants have a deep literature, from early timing attacks [1] and the program-counter model [2] to formal verification and secure compilation [3,4]. Compiler techniques such as Constantine and partial control-flow linearization brought these ideas closer to real software [6–8]. Constant-resource work similarly studies observationally uniform resource consumption [4,5]. Our contribution is orthogonal: even a program with fixed control flow, fixed addresses, and fixed aggregate cost can still leak a structured `SET/CLEAR/SAME/UPDATE` trace.

### Side channels in TEEs, CVMs, and encrypted memory

Leaky Cauldron established the broader risk of side channels in SGX [10]. CIPHERLEAKS showed that ciphertext side channels can break constant-time OpenSSL under AMD SEV [11]. Cipherfix mitigates ciphertext side channels by masking sensitive writes [12]. Augury and GoFetch showed how data-memory-dependent prefetchers can leak “data at rest” even without architectural reads [13–15]. Relocate-Vote showed that sparse/default values can be inferred via ciphertext-side observations and relocation primitives on SEV-SNP [16]. SNPeek systematizes such leakage evaluation on production CVMs and demonstrates practical mitigations [17].

Our work sits at the intersection of these lines: it unifies freshness/equality-style write leakage with marker/default-state leakage, and extends the discussion from memory-resident secrets to persistent state and storage backends.

### Freshness-based mitigations and memory-centric leakage

Zebrafix argues that ciphertext side channels, silent stores, and related memory-centric leaks can be mitigated by ensuring store freshness [21]. That insight is important and complementary. We adopt the freshness principle, but show that freshness alone is not enough once a distinguished marker class is observable. `M+` requires **freshness plus marker elimination plus budget equalization**. This distinction is precisely what the qcow2 and OpenSSL cleanup examples expose.

### ORAM and write-only ORAM

ORAM [18] and write-only ORAM [19] hide access patterns to untrusted storage. They are natural ingredients for update-oblivious data structures, especially maps. But classic ORAM security abstracts over physical read/write transcripts, not backend semantics like trim/unmap, zero classes, or same-location ciphertext comparison. Our `M+`-aware ORAM layer strengthens the physical-write discipline to close that gap.

### Robust constant-time

Robust constant-time asks that cryptographic code remain safe even when linked into less trustworthy contexts [20]. Our concern is different: we strengthen the **observer** rather than the **context**. The two are complementary. A future end-to-end theorem should combine both.

## 11 Conclusion

Constant-time programming solved a major class of side channels by equalizing control flow and address traces. This paper argues that one important residual channel remains: the semantic class of writes.

We formalized that channel as the marker-aware write oracle `M+`, showed that it is strictly stronger than traditional constant-time observers, and substantiated it across three settings: a concrete attack on stock Sapphire localnet, a four-way oracle on a zero-aware encrypted qcow2 backend, and 11 positive leaks in OpenSSL. We then presented update-oblivious programming, a defense stack built from six principles: marker elimination, fresh writes, rerandomization, constant write budgets, address obliviousness, and semantic scrubbing.

The broader lesson is simple. For confidential execution, it is no longer enough to ask whether a location was touched. We must also ask what the observer can infer from how that location changed.

That is the step from constant-time to update-obliviousness.

## Appendix A: Security statements and proof sketches

### A.1 Strictness theorem

**Theorem 1.** Update-obliviousness under `M+` strictly strengthens constant-time.

**Sketch.** The “strengthens” direction follows from Proposition 1. Strictness follows from the fixed-slot classifier example or from the preliminary EVM contract that writes an authentication result into a fixed storage slot while keeping code and access pattern constant.

### A.2 Soundness of the six principles

Let `P` be a program satisfying:

1. all secret-dependent control flow has been linearized;
2. all secret-dependent locations are accessed through full-scan or `M+`-aware ORAM abstractions;
3. all observable writes use non-marker encodings;
4. logical updates are recorded as fresh writes or rerandomized same-location writes;
5. each logical operation emits a public-determined physical write budget; and
6. metadata and allocators obey the same invariants.

**Theorem 2.** The physical `M+` trace induced by `P` is a function of the public input only.

**Sketch.** Conditions 1 and 2 fix the control and address components. Condition 3 removes `SET/CLEAR` on data slots. Condition 4 removes `SAME/UPDATE` comparisons on reused physical locations. Condition 5 equalizes the number and schedule of remaining writes. Condition 6 prevents metadata from reintroducing the channel. The resulting observable trace is public-determined.

A full mechanized proof is future work, but the structure is directly compatible with instrumented-semantics and self-composition styles already used in constant-time verification [3,4].

## Appendix B: Example APIs and transformation rules

### B.1 Example UO scalar API

```text
trait UOCell<T> {
    fn get(&self) -> T;
    fn set(&mut self, v: T);
}
```

Required invariant: `set` must not materialize the distinguished marker physically, must not reuse a secret-dependent slot in place, and must emit a fixed write budget.

### B.2 Example transformation rule

Raw store:

```text
if (secret) x = 0 else x = y
```

SWL form:

```text
p  := secret_predicate
v  := select(p, 0, y)
uo_store(true, x, v)
```

The key difference from conventional predication is that `uo_store` is itself update-oblivious; it does not simply write `v` in place.

### B.3 Example semantic scrub rule

Raw scrub:

```text
memset(buf, 0, n)
```

UO scrub:

```text
uo_wipe(buf, n)        // overwrite with fresh non-marker data
retire_metadata(buf)
public_schedule_reclaim(buf)
```

## References

[1] Paul C. Kocher. Timing Attacks on Implementations of Diffie-Hellman, RSA, DSS, and Other Systems. CRYPTO, 1996.

[2] David Molnar, Matt Piotrowski, David Schultz, and David Wagner. The Program Counter Security Model: Automatic Detection and Removal of Control-Flow Side Channel Attacks. USENIX Security, 2005.

[3] João Barbosa Almeida, Manuel Barbosa, Gilles Barthe, François Dupressoir, and Michael Emmi. Verifying Constant-Time Implementations. USENIX Security, 2016.

[4] Gilles Barthe, Benjamin Grégoire, Vincent Laporte, and Swarn Priya. Structured Leakage and Applications to Cryptographic Constant-Time and Cost. CCS, 2021.

[5] Van Chan Ngo, Mario Dehesa-Azuara, Matthew Fredrikson, and Jan Hoffmann. Verifying and Synthesizing Constant-Resource Implementations with Types. IEEE S&P, 2018.

[6] Pietro Borrello, Daniele Cono D’Elia, Leonardo Querzoni, and Cristiano Giuffrida. Constantine: Automatic Side-Channel Resistance Using Efficient Control and Data Flow Linearization. CCS, 2021.

[7] Leonardo Soares, Matheus Canesche, and Fernando M. Q. Pereira. Side-Channel Elimination via Partial Control-Flow Linearization. TOPLAS, 2023.

[8] Leonardo Soares and Fernando M. Q. Pereira. Memory-Safe Elimination of Side Channels. CGO, 2021.

[9] Victor Costan and Srinivas Devadas. Intel SGX Explained. IACR ePrint 2016/086, 2016.

[10] Wenhao Wang, Guoxing Chen, Panruo Zhang, et al. Leaky Cauldron on the Dark Land: Understanding Memory Side-Channel Hazards in SGX. CCS, 2017.

[11] Mengyuan Li, Yinqian Zhang, Huibo Wang, Kang Li, and Yueqiang Cheng. CIPHERLEAKS: Breaking Constant-time Cryptography on AMD SEV via the Ciphertext Side Channel. USENIX Security, 2021.

[12] Jan Wichelmann, Anna Pätschke, Luca Wilke, and Thomas Eisenbarth. Cipherfix: Mitigating Ciphertext Side-Channel Attacks in Software. USENIX Security, 2023.

[13] Jose Rodrigo Sanchez Vicarte, Michael Flanders, Riccardo Paccagnella, et al. Augury: Using Data Memory-Dependent Prefetchers to Leak Data at Rest. IEEE S&P, 2022.

[14] Jose Rodrigo Sanchez Vicarte, Pavan Kumar Shome, Nandita Nayak, et al. Opening Pandora’s Box: A Systematic Study of New Ways Microarchitecture Can Leak Private Data. ISCA, 2021.

[15] Ben Chen, Yujin Wang, Prannoy Shome, et al. GoFetch: Breaking Constant-Time Cryptographic Implementations Using Data Memory-Dependent Prefetchers. USENIX Security, 2024.

[16] Yuqin Yan, et al. Relocate-Vote: Using Sparsity Information to Exploit Ciphertext Side-Channels. USENIX Security, 2025.

[17] Ruiyi Zhang, Albert Cheu, Adria Gascon, Daniel Moghimi, Phillipp Schoppmann, Michael Schwarz, and Octavian Suciu. SNPeek: Side-Channel Analysis for Privacy Applications on Confidential VMs. NDSS, 2026.

[18] Emil Stefanov, Elaine Shi, and Dawn Song. Towards Practical Oblivious RAM. NDSS, 2012.

[19] Daniel S. Roche, Adam J. Aviv, Seung Geol Choi, and Travis Mayberry. Deterministic, Stash-Free Write-Only ORAM. CCS, 2017.

[20] Matthew Kolosick, Basavesh Ammanaghatta Shivakumar, Sunjay Cauligi, Marco Patrignani, Marco Vassena, Ranjit Jhala, and Deian Stefan. Robust Constant-Time Cryptography. PLDI, 2025.

[21] Anna Pätschke, Jan Wichelmann, and Thomas Eisenbarth. Zebrafix: Mitigating Memory-Centric Side-Channel Leakage via Interleaving. RAID, 2025.

[22] QEMU Project. qemu-nbd Documentation.

[23] QEMU Project. Dirty Bitmaps and Incremental Backup; NBD Metadata Context Documentation.

[24] Linux Kernel Documentation. dm-crypt.

[25] Red Hat Enterprise Linux Documentation. Encrypting Block Devices Using LUKS.
