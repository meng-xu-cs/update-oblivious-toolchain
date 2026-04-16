# Stronger Import Route Feasibility

This note evaluates whether the paper can honestly upgrade from the current
citation-based theorem-source plan to a genuinely stronger import route.

Here, "stronger import route" means more than citing Path ORAM literature. It
means the paper can point to an external formal artifact that yields, or can be
cleanly adapted into, a theorem object matching:

`PaperMainPathOramTheoremSourceAt assumptions bundle.publicView bundle.leafRun`

without quietly re-proving the whole ORAM theorem inside this repo.

## Acceptance Criteria

The stronger import route is only crisp and complete if all of the following
hold.

- There is an external formal artifact, not just a paper citation.
- That artifact contains a machine-checked Path ORAM security theorem, not only
  a mechanized meta-logic or a proposal to verify Path ORAM later.
- The external theorem can either:
  map directly to `PaperMainPathOramTheoremSourceAt`, or
  be adapted to that interface by a small, explicit bridge rather than a new
  large proof project.
- The remaining wrapper assumptions are still only the repo’s explicit
  `PathOramLocalPosmapV1SecurityAssumptions` bundle.

## Candidate Review

### 1. JACM Path ORAM paper

Source:

- Emil Stefanov et al.
  "Path ORAM: An Extremely Simple Oblivious RAM Protocol."
  *Journal of the ACM* 65(4), 2018.
  DOI: <https://doi.org/10.1145/3177872>

Assessment:

- strongest literature citation for the ORAM theorem itself
- not a mechanized artifact
- good enough for the citation route
- not sufficient for the stronger import route by itself

Conclusion:

- excellent citation source
- not an external theorem object

### 2. FM 2024 Isabelle/HOL work

Source:

- Pengbo Yan, Toby Murray, Olga Ohrimenko, Van-Thuan Pham, and Robert Sison.
  "Combining Classical and Probabilistic Independence Reasoning to Verify the
  Security of Oblivious Algorithms."
  FM 2024.
  DOI: <https://doi.org/10.1007/978-3-031-71162-6_10>
  Extended version: <https://arxiv.org/abs/2407.00514>

What the primary source says:

- the logic is formalized and proved sound in Isabelle/HOL
- Path ORAM is one of the case studies
- but the paper explicitly says the case-study proofs are manual:
  the Path ORAM proof is used to show the logic can encode existing rigorous
  security arguments, not to expose a published machine-checked theorem object
  at the repo’s target interface
- the Zenodo artifact description sharpens this further: it says the uploaded
  formalization covers the logic extension and soundness proof corresponding to
  Section 3.2, Section 4, and Appendix A of the paper, which is consistent with
  a logic artifact rather than a packaged external Path ORAM theorem object
- the artifact-availability statement points to an Isabelle/HOL formalization,
  but the paper text does not claim the Path ORAM case study itself is a
  packaged external theorem object ready for import

Assessment:

- strongest visible external formal-methods candidate
- useful related work, and potentially useful as a starting point for a future
  adapter project
- not yet a crisp external theorem object for this repo’s stronger import route

Conclusion:

- promising research lead
- not currently sufficient to claim a complete stronger import route

### 3. CoqPL 2023 Path ORAM proposal

Source:

- Hannah Leung, Talia Ringer, Christopher W. Fletcher.
  "Towards Formally Verified Path ORAM in Coq."
  CoqPL 2023 extended abstract.
  <https://dependenttyp.es/pdf/oramproposal.pdf>

What the primary source says:

- this is a proposal and design discussion for verifying Path ORAM in Coq
- it describes plans, challenges, and proof-engineering questions
- it is not a completed theorem artifact

Assessment:

- relevant future-work signal
- not an importable theorem source today

Conclusion:

- not sufficient for the stronger import route

## Current Bottom Line

Based on the currently identified external sources:

- there is a strong literature theorem source for the citation route
- there is no clearly available external machine-checked Path ORAM theorem
  object that already matches, or obviously reduces to,
  `PaperMainPathOramTheoremSourceAt`

So the stronger import route is **not yet crisp and complete**.

## What Would Make It Crisp

One of the following would need to happen.

- Obtain a public external artifact whose Path ORAM theorem is already
  machine-checked and strong enough to instantiate
  `PaperMainPathOramTheoremSourceAt`.

- Build a companion theorem-adapter project that:
  starts from the FM 2024 Isabelle/HOL artifact or a similar external
  mechanization,
  machine-checks the Path ORAM case-study theorem itself,
  and exports a small explicit bridge into the repo’s frozen interface.

- Produce a separate appendix / companion mechanization that formalizes the
  JACM-style theorem directly at `PaperMainPathOramTheoremSourceAt`.

Each of those is a real research project, not a small repo-integration step.

## Recommended Interpretation

At the current evidence level:

- the theorem routes remain equivalent at the frozen interface
- the recommended paper mainline is still the external-citation route
- the stronger import route should be presented only as future strengthening
  unless and until one of the conditions above is actually met

## Manual Decision Boundary

Proceeding further now requires a research-scope choice:

- invest in a companion mechanization / theorem-adapter project around an
  external formal artifact
- or keep the paper on the citation route and present the stronger import route
  as future work

That is not a repo-plumbing decision anymore; it is a project-scope decision.
