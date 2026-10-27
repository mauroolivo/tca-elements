# TCA vs Native SwiftUI (Evidence from this Lab)

This document compares the two approaches using behavior observed in this workspace, not universal claims.

## 1) Scope of comparison in this project

Compared implementations:
- **TCA path**: `AppFeature` + `TasksFeature` + `TaskDetailFeature` + tests.
- **Native path**: `NativeTasksComparisonView` + `NativeTasksModel`.

Shared baseline:
- same `TaskClient` fixture behavior,
- same load/cancel/add/toggle/delete surface,
- same high-level loading phases.

## 2) Decision summary

- Prefer **native SwiftUI** for small, local, low-coordination features.
- Prefer **TCA** when cancellation, cross-feature invariants, and deterministic testing become first-order constraints.

## 3) Side-by-side matrix

| Dimension | TCA in this lab | Native SwiftUI in this lab |
|---|---|---|
| State ownership | Explicit reducer state tree | Model + local view state composition |
| Event tracing | Named actions with parent/child routing | Method calls on observable model |
| Async effects | `.run`, `.cancellable`, `.cancel` | Manual `Task` handles + cancellation |
| Race handling | Request IDs and reducer guards | Request IDs manually implemented |
| Navigation | `StackState` + `StackAction` domain truth | Not centralized in comparison flow |
| Presentation | `@Presents` + `PresentationAction` | Local `sheet/alert` state patterns |
| Composition | `Scope`, `ifLet`, `forEach` | Manual decomposition by view/model boundaries |
| Test ergonomics | `TestStore` exhaustive action/state assertions | Requires custom async model tests |
| Boilerplate | Higher | Lower |
| Team-level guardrails | Strong compile-time contracts | Convention-driven |

## 4) Evidence from this codebase

## 4.1 Cancellation and races

TCA:
- explicit cancellation IDs,
- stale-response guards in reducer,
- tested in `Stage6BEffectTests`.

Native:
- explicit `Task` handle (`inFlightLoadTask`),
- manual request ID guard (`latestRequestID`) in `NativeTasksModel`.

Observation:
- Both can be correct.
- TCA made these rules more discoverable and test-oriented by default.

## 4.2 Cross-feature coordination

TCA:
- detail/list synchronization happens in `AppFeature` with delegate contracts.
- regressions captured in `Stage6CRegressionTests`.

Native:
- equivalent coordination would be hand-authored and test harness custom-built.

Observation:
- TCA has more ceremony but stronger protection against coordination drift.

## 4.3 Presentation and draft editing

TCA:
- draft state and commit/discard modeled in reducer (`TaskDetailFeature`).
- alert and confirmation modeled as state/actions.

Native:
- simpler to author for local use cases.
- discipline needed to avoid accidental two-way mutation leaks.

Observation:
- TCA is advantageous when presentation rules are domain-critical.

## 5) Cost profile

TCA costs:
- more types and action plumbing,
- steeper onboarding for new contributors,
- more explicit design decisions up front.

Native costs:
- less boilerplate initially,
- invariants can become implicit over time,
- async/test rigor requires extra manual structure.

## 6) Adoption criteria (practical)

### Small feature
Use native if:
- single-screen scope,
- minimal async complexity,
- low cross-feature coupling,
- lightweight test needs.

### Medium feature
Use TCA if at least two are true:
- cancellation/race behavior matters,
- parent-child coordination is non-trivial,
- reducer-level deterministic tests are required,
- navigation/presentation invariants are part of domain behavior.

### Large feature / multi-team domain
Use TCA (+ modular boundaries) when:
- ownership contracts must be explicit,
- independent refactoring velocity is needed,
- regression risk from coordination bugs is high.

## 7) Interoperability guidance

Incremental migration works well:
- keep existing MVVM/UIKit areas,
- introduce TCA at feature boundaries,
- use delegate contracts where cross-architecture coordination is needed,
- migrate vertically by flow, not by layer-wide rewrite.

## 8) Final recommendation for this lab

- Keep TCA for the task flow domain because it already benefits from:
  - explicit effect lifecycle control,
  - clear parent/child contracts,
  - deterministic tests (Stage 6).
- Keep native SwiftUI as a valid default for new low-risk utility screens and prototypes.

This is a mixed strategy: **architecture per feature pressure, not per ideology**.
