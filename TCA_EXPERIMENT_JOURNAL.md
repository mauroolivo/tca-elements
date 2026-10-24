# TCA Experiment Journal

## Course Setup
- Date: 2026-10-22
- Project: `tca-elements`
- Stage: 2
- Exercise: Async effect + custom dependency key

## Environment Snapshot
- Xcode: 27.1 (Build 27A9269)
- Swift toolchain: Apple Swift 6.4 (`swift-driver` 1.168.6)
- Project object version: 110
- Deployment target: iOS 27.0
- Swift language setting in project: `SWIFT_VERSION = 5.0`
- Swift-related build settings enabled:
  - `SWIFT_APPROACHABLE_CONCURRENCY = YES`
  - `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  - `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`

## TCA Package Status
- `swift-composable-architecture` is added and pinned in `tca-elements.xcodeproj/project.pbxproj`.
- Resolved version: `1.26.2`.
- Resolved source package file: `tca-elements.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

## Version Policy For This Lab
- Add TCA from the official repo URL:
  - `https://github.com/pointfreeco/swift-composable-architecture`
- Pin policy: prefer latest compatible `1.x` release for this project/toolchain.
- Current observed latest release on GitHub at time of setup: `1.26.2` (Aug 28, 2026).
- After adding the package, record the exact resolved version from `Package.resolved` before implementing features.

## Exercise Notes
- Emphasis: observation-era TCA APIs (`@Reducer`, `@ObservableState`, `StoreOf`, `Reduce`) unless resolved version requires adaptation.
- Avoid mixing historical `ViewStore`-centric examples with modern observation style unless explicitly comparing historical APIs.

## Decisions / Constraints (User Preferences)
- Prefer code edits during exercises.
- No test-writing requirement for now.
- Journal starts immediately in Stage 0.

## Stage 0 - Exercise B (Establish baseline)
- Minimal baseline screen created in `tca-elements/ContentView.swift`.
- Replaced template hello-world content with a small lab status view and explicit root-store ownership note.
- Root store ownership decision recorded in `tca-elements/tca_elementsApp.swift`: app entry point will own root store for stable identity/lifetime.
- No TCA code introduced yet because package is not installed/resolved.

### Takeaway
- Before adding feature reducers, confirm stable ownership location: `App` entry point, not recreated inside transient child views.

## Stage 1 - Exercise A (Counter)
### Goal
- Build the smallest complete TCA loop (state, action, reducer, store, view) and make each user intent traceable to one explicit mutation.

- Added first reducer feature in `tca-elements/CounterFeature.swift` using modern APIs:
  - `@Reducer`
  - `@ObservableState`
  - `Reduce`
- Implemented explicit actions:
  - `incrementButtonTapped`
  - `decrementButtonTapped`
  - `resetButtonTapped`
- Integrated store-driven UI in `tca-elements/ContentView.swift` using `StoreOf<CounterFeature>` and `store.send(...)`.
- Established root store ownership in `tca-elements/tca_elementsApp.swift` with a stable `Store(initialState:reducer:)` at app entry.
- Build verification: app builds successfully via `xcodebuild` with `-skipMacroValidation`.

### Deliberate Failure and Repair
- Initial reducer body used `var body: some ReducerOf<Self>`, which triggered a macro circular-reference compiler error in this project configuration.
- Repaired by changing to `var body: some Reducer<State, Action>`, after which build succeeded.

### Specific considerations
- Action names were intentionally intent-based (`incrementButtonTapped`) instead of imperative method names to keep event flow explicit.
- Root store ownership at `App` level prevents accidental state resets during SwiftUI view identity churn.
- The reducer stays synchronous and side-effect free in this exercise to isolate the core mental model before introducing effects.

### Takeaway
- In observation-era TCA, action names express user intent, reducers mutate state synchronously, and views simply send actions.
- Store lifetime matters: placing the root store in `App` gives stable identity across SwiftUI view refreshes.
- The main win in this stage is not abstraction; it is inspectability: every state transition has a named cause.

## Stage 1 - Exercise B (State boundaries)
### Goal
- Practice state ownership discipline by separating canonical domain state, derived values, and purely presentational view state.

- Added a computed derived value in reducer state:
  - `displayCount` is computed from `count` and has no independent storage.
- Added an intentionally duplicated stored value:
  - `cachedDisplayCount` duplicates the same concept and can drift.
- Added deliberate inconsistency actions:
  - `corruptCachedDisplayTapped` makes duplicate state stale on purpose.
  - `repairCachedDisplayTapped` re-syncs duplicate state from source.
- Added a transient UI concern as local SwiftUI state in `ContentView`:
  - `@State private var showRawCount` controls visibility only and does not belong in domain state.

### Specific considerations
- The inconsistency demo is intentional technical debt: it demonstrates why denormalized state requires strict synchronization rules.
- Keeping `showRawCount` in view-local state avoids polluting domain state with ephemeral presentation concerns.
- This exercise is a concrete guardrail against over-centralizing every boolean in reducer state.

### Takeaway
- Keep canonical domain data in reducer state (`count`), compute derived display values when possible (`displayCount`), and avoid duplicate stored derivations (`cachedDisplayCount`) unless there is a strong, explicit reason.
- Purely presentational toggles with no domain meaning can remain local to the view.
- A useful heuristic emerges: if a value can be recomputed from canonical state, persistence of that value needs explicit justification.

## Stage 1 - Exercise C (Dependency preview)
### Goal
- Introduce dependency injection in the reducer with the smallest possible surface area and prove deterministic behavior in previews.

- Re-centered the active screen from the Stage 1B inconsistency demo to a minimal dependency-focused variant.
- Added a reducer dependency:
  - `@Dependency(\.date.now) var now`
- Added a new action:
  - `captureNowButtonTapped` assigns `state.lastUpdated = now`
- Kept synchronous counter actions unchanged to isolate dependency learning.
- Updated preview store dependencies for determinism:
  - `withDependencies { $0.date.now = Date(timeIntervalSince1970: 1_700_000_000) }`

### Specific considerations
- The dependency was introduced where behavior lives (reducer), not where rendering happens (view), preserving directional architecture.
- Overriding `date.now` in preview demonstrates that deterministic dependencies are not only for tests; they also improve UI verification.
- We intentionally avoided premature protocol layering and kept the dependency boundary concrete and minimal.

### Takeaway
- Dependencies in TCA are read where behavior needs them (the reducer), not from the view.
- Previews can override dependencies to produce stable, repeatable output while still exercising real reducer logic.
- This stage establishes the dependency pattern that later scales to async clients, clocks, persistence, and deterministic tests.

## Stage 2 - Async effect + custom dependency key
### Goal
- Move asynchronous task loading out of view callbacks and into reducer-managed effects, while introducing a first custom dependency key in a version-accurate TCA style.

- Extended `CounterFeature` state for async loading flow:
  - `tasks: [TaskItem]`
  - `tasksPhase: .idle | .loading | .loaded | .failed(String)`
- Added async actions in `CounterFeature.Action`:
  - `loadTasksButtonTapped`
  - `tasksResponse(Result<[TaskItem], TaskLoadError>)`
- Implemented effect pipeline in reducer:
  - `.loadTasksButtonTapped` sets `tasksPhase = .loading`
  - runs `taskClient.loadTasks()` via `.run`
  - maps success/failure into `.tasksResponse`
- Introduced custom dependency:
  - reducer usage: `@Dependency(\.taskClient) var taskClient`
  - exposure in `tca-elements/TaskClient.swift` via:
    - `extension DependencyValues { var taskClient: TaskClient { get/set } }`
    - `extension TaskClient: DependencyKey { liveValue/testValue/previewValue }`
- Wired root store dependency in `tca-elements/tca_elementsApp.swift`:
  - `withDependencies { $0.taskClient = .fixture }`
- Updated `tca-elements/ContentView.swift` to render Stage 2 async states:
  - idle/loading/loaded/failed UI
  - load button disabled during `.loading`

### Specific considerations
- We intentionally modeled async UI as a single state machine (`tasksPhase`) to avoid contradictory combinations such as "has error" + "is loading".
- We kept fixture data deterministic so behavior can be reasoned about and later tested without relying on network timing.
- Dependency registration was done at app root to make override points explicit and easy to audit.

### Stage 2 Verification Checklist
- [ ] Tapping "Load tasks" transitions from `.idle` to `.loading` and then `.loaded`.
- [ ] Loaded tasks render from fixture data.
- [ ] Counter actions (`+1`, `-1`, `Reset`) still work unchanged.
- [ ] `captureNowButtonTapped` still updates `lastUpdated`.
- [ ] Failure branch renders a readable `.failed(message)` state if `taskClient` throws.

### Takeaway
- A custom dependency in TCA is exposed in two places: a `DependencyValues` computed property (for key-path access) and `DependencyKey` conformance (for default values).
- Async side effects stay in the reducer, while the view remains a projection of state plus action sends.
- This separation is the first practical shift from callback-driven UI to an effect-driven state machine, which scales better as feature complexity increases.

## Stage 2 - Exercise B (Failure and retry)
### Goal
- Validate that failure is a first-class state transition, not an exceptional path hidden in logs, and ensure retries reuse the same reducer pipeline.

- Switched app wiring to a deterministic fail-first client:
  - `withDependencies { $0.taskClient = .failFirstThenFixture }` in `tca-elements/tca_elementsApp.swift`.
- Added `TaskClient.failFirstThenFixture` in `tca-elements/TaskClient.swift`:
  - first load throws a simulated error
  - subsequent retry returns fixture data
- Kept reducer flow intentional in `tca-elements/CounterFeature.swift`:
  - `loadTasksButtonTapped` sets `.loading`
  - `tasksResponse(.failure)` stores a user-facing message in `.failed(String)`
  - retry reuses the same action/effect path, no extra booleans
- Clarified failed-state UX in `tca-elements/ContentView.swift` with explicit retry guidance.

### Specific considerations
- Reusing `loadTasksButtonTapped` for first attempt and retry keeps behavior centralized and avoids drift between similar code paths.
- Error handling remains data-oriented (`.failed(String)`) so UI can render failure deterministically and recover with one next intent.

### Takeaway
- Failure and retry work best when modeled as a single state machine (`idle/loading/loaded/failed`) rather than separate, potentially contradictory booleans.
- Deterministic fail-first dependencies are useful pedagogically: they make the failure path visible on demand and remove timing ambiguity.

## Stage 2 - Exercise C (Cancellation and races)
### Goal
- Make effect lifetime explicit and deterministic under rapid user input, including cancellation and stale response protection.

- Extended task-loading flow to support explicit cancellation:
  - Added `cancelLoadTasksButtonTapped` action.
  - Added `.cancellable(id:cancelInFlight:)` to the load effect.
  - Added `.cancel(id:)` handling when cancel is tapped.
- Added request identity tracking in reducer state:
  - `latestTasksRequestID` increments per load trigger.
  - `tasksResponse(requestID: ...)` ignores stale responses from older effects.
- Updated `ContentView` Stage 2 UI:
  - "Load tasks" remains available for rapid re-taps.
  - Added "Cancel" button enabled only while loading.
- Increased fixture latency in `TaskClient.fixture` to `1s` to make in-flight cancellation visible in UI.

### Specific considerations
- `cancelInFlight: true` handles duplicate in-flight work for same-intent reloads; request-ID guards add protection against stale response ordering.
- Cancellation updates state to `.idle` immediately while task teardown happens in the effect layer, keeping UI responsive to intent.
- Actor-isolation note: `.run` work is non-isolated by default, while state mutation re-enters serialized store processing through `send`.

### Takeaway
- Cancellation IDs control effect lifetime, while request IDs guard state against stale async responses.
- `cancelInFlight: true` makes repeated user intent (reload) deterministic: newest request wins.
- This is the first concrete example where concurrency behavior becomes explicit domain logic rather than incidental callback timing.

## Stage 3 - Exercise A (Compose parent and child features)
### Goal
- Introduce explicit reducer composition so domain boundaries are visible in code: one parent feature (`AppFeature`) owns orchestration, while child features (`TasksFeature`, `SettingsFeature`) own their local state and actions.

- Created `tca-elements/AppFeature.swift` with:
  - parent `State` containing `tasksFeature` and `settingsFeature`
  - parent `Action` namespacing child actions (`.tasksFeature(...)`, `.settingsFeature(...)`)
  - `Scope` composition for both child reducers
- Extracted async loading logic from `CounterFeature` into `tca-elements/TasksFeature.swift`:
  - task state machine (`idle/loading/loaded/failed`)
  - cancellation and stale-response handling
  - `TaskClient` dependency usage unchanged
- Added `tca-elements/SettingsFeature.swift` as a minimal second child:
  - local settings state and toggle action
  - intentionally small footprint for composition focus
- Updated root wiring in `tca-elements/tca_elementsApp.swift`:
  - app now owns `Store(initialState: AppFeature.State()) { AppFeature() }`
- Updated `tca-elements/ContentView.swift`:
  - accepts `StoreOf<AppFeature>`
  - renders child sections using scoped stores

### Specific considerations
- The parent currently coordinates structure, not behavior. This keeps Stage 3A focused on composition mechanics before introducing parent-child communication rules.
- Extracting `TasksFeature` preserves Stage 2 effect behavior while reducing cognitive load in `CounterFeature`; each reducer now has a clearer reason to change.
- The `SettingsFeature` is intentionally simple to prove that scoped stores are not only for complex domains; they are a boundary tool even for small state.
- We retained app-level dependency injection (`taskClient`) so child reducers consume dependencies without needing global singletons.

### Takeaway
- `Scope` is the key bridge between parent topology and child autonomy: parent owns placement, child owns behavior.
- Namespaced child actions make data flow auditable and avoid accidental cross-feature mutation.
- Composition does not require immediate abstraction of every shared rule; start with boundaries, then add coordination only when behavior demands it.

## Stage 3 - Exercise B (Optional child with `ifLet`)

### Goal
- Model detail flow as optional state (`TaskDetailFeature.State?`) so the child reducer only exists when the parent says it exists.
- Observe how child effects behave when optional state is removed.

### Hands-on changes
- Added a new optional child reducer in `tca-elements/TaskDetailFeature.swift`:
  - state: selected `TaskItem` + `heartbeatCount`
  - effect: long-running heartbeat loop started by `.startHeartbeat`
- Extended `tca-elements/AppFeature.swift`:
  - added `taskDetailFeature: TaskDetailFeature.State?`
  - added child action routing and dismiss action
  - composed child with `.ifLet(\.taskDetailFeature, action: \.taskDetailFeature)`
  - mapped `TasksFeature.Action.taskTapped` to parent-owned detail creation
- Extended `tca-elements/TasksFeature.swift` with `taskTapped(Int)` intent action.
- Updated `tca-elements/ContentView.swift`:
  - task rows now send `.taskTapped`
  - optional detail section is rendered only when scoped optional store exists
  - dismiss button sets child state back to `nil`

### Key decisions
- **Parent owns navigation/presence state:** task detail is represented in `AppFeature.State`, not inside `TasksFeature`.
- **Child owns detail-local behavior:** heartbeat logic stays fully inside `TaskDetailFeature`.
- **Intent over coupling:** tasks child emits `taskTapped` intent; parent decides what that means.

### What we observed
- Optional scoping in the view (`if let detailStore = store.scope(...)`) mirrors optional reducer composition in the parent.
- When parent sets `taskDetailFeature = nil`, the optional child disappears and its in-flight effect is torn down by `ifLet` lifecycle behavior.

### Caveats
- The detail feature currently holds a snapshot of a selected `TaskItem`; edits are not synchronized back to the tasks list yet.
- Heartbeat is intentionally synthetic for lifecycle visibility; real features should tie long-lived effects to actual product behavior.

### Takeaway
- `ifLet` is more than conditional rendering: it is state-driven reducer composition with lifecycle-aware effect management.
- Optional child state gives a precise answer to "does this feature exist right now?" and keeps parent/child ownership boundaries explicit.
