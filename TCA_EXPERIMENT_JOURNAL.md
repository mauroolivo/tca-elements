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


## Stage 3 - Exercise C (Delegation)

### Goal
- Let a child feature communicate user intent to its parent without importing parent concerns or forcing the parent to inspect child internals.
- Compare intent delegation with shared state coupling and direct parent coordination.

### Hands-on changes
- Added an explicit delegate channel in `tca-elements/TasksFeature.swift`:
  - `Action.delegate(Delegate)`
  - `Delegate.taskSelected(TaskItem)`
- Converted task row tap flow:
  - child still receives `.taskTapped(id)` from the view
  - child maps that local event to `.delegate(.taskSelected(task))`
  - parent reacts to delegated intent in `tca-elements/AppFeature.swift`
- Updated parent coordination in `tca-elements/AppFeature.swift`:
  - replaced direct `case .tasksFeature(.taskTapped(...))` handling
  - now handles `case .tasksFeature(.delegate(.taskSelected(task)))`
  - parent creates `taskDetailFeature` from delegated payload

### Key decisions
- **Intent-first communication:** child emits what happened (`taskSelected`) instead of how parent should react.
- **Parent stays coordinator:** parent decides navigation/presence by setting optional detail state.
- **Avoid structural coupling:** parent no longer reaches into `tasksFeature.tasks` to reconstruct selection context.

### Trade-offs
- Delegation adds one extra action layer, but it makes ownership boundaries clearer as features scale.
- Passing full `TaskItem` simplifies parent coordination; passing only `id` would keep payload smaller but requires parent lookup logic.

### Takeaway
- Delegate actions are a focused cross-boundary contract: child reports intent, parent decides orchestration.
- This pattern scales better than shared mutable state when feature boundaries and responsibilities need to stay explicit.


## Stage 4 - Exercise A (Task collection)

### Goal
- Move from a plain array to identity-driven collection state so row actions can be routed safely and predictably.
- Add, complete, and delete tasks while preserving stable IDs and explicit reducer ownership.

### Hands-on changes
- Added `tca-elements/TaskRowFeature.swift` as a focused row reducer:
  - row state wraps a `TaskItem` and exposes `id`
  - row actions: select, toggle completion, delete
  - row delegate emits task-selection intent upward
- Refactored `tca-elements/TasksFeature.swift`:
  - `tasks` changed to `IdentifiedArrayOf<TaskRowFeature.State>`
  - introduced `taskRows(IdentifiedActionOf<TaskRowFeature>)`
  - added `addTaskButtonTapped`
  - composed row reducer with `.forEach(\.tasks, action: \.taskRows)`
  - routes row delegate selection to parent-level `delegate(.taskSelected)`
  - handles row deletion by ID in the collection owner
- Updated `tca-elements/ContentView.swift`:
  - Tasks section now includes an `Add` button
  - rows render from scoped row stores using `ForEach(store.scope(state: \.tasks, action: \.taskRows))`
  - added `TaskRowView` with row tap, complete toggle, and delete actions

### Key decisions
- **Collection ownership stays in `TasksFeature`:** row reducers mutate local row state, but collection structural changes (remove by ID) happen in the parent collection reducer.
- **Stable identity first:** `IdentifiedArrayOf` + `IdentifiedActionOf` make action routing explicit and resilient to ordering changes.
- **Delegation remains selective:** only row selection delegates upward; not every row action becomes a parent concern.

### Caveats
- `TaskDetailFeature` still holds a snapshot of a selected task; completion/deletion while detail is visible is intentionally left for Stage 4C lifecycle edge-case exploration.

### Takeaway
- `IdentifiedArrayOf` and `.forEach` turn list behavior into explicit state/action topology.
- Row actions become addressable by identity rather than index, reducing accidental coupling to collection order.

## Stage 4 - Exercise B (Stack navigation)

### Goal
- Move detail presentation from optional inline state to explicit stack navigation state.
- Push task detail from domain actions, then pop back without duplicating navigation truth in view-local state.

### Hands-on changes
- Updated `tca-elements/AppFeature.swift`:
  - replaced `taskDetailFeature: TaskDetailFeature.State?` with `detailPath = StackState<TaskDetailFeature.State>()`
  - replaced optional-child action with `detailPath(StackActionOf<TaskDetailFeature>)`
  - on `tasksFeature.delegate(.taskSelected(task))`, appends `TaskDetailFeature.State(task:)` to path
  - replaced `.ifLet` composition with `.forEach(\.detailPath, action: \.detailPath) { TaskDetailFeature() }`
- Updated `tca-elements/ContentView.swift`:
  - migrated root container to `NavigationStack(path: $store.scope(state: \.detailPath, action: \.detailPath))`
  - replaced inline optional detail section with `destination` rendering of `TaskDetailView`
  - `TaskDetailView` starts heartbeat on appear and exposes a pop button via `dismiss()`

### Key decisions
- **Single navigation source of truth:** path lives in reducer state, not in local `@State` or ad-hoc booleans.
- **State-driven push:** row selection delegates intent; parent maps it to path append.
- **Feature reuse:** detail reducer remains the same domain, now hosted as stack destination state.

### Trade-offs
- Stack navigation is more explicit and testable than implicit view routing, but adds ceremony and action/state types.
- `dismiss()` is convenient in SwiftUI destination views; path mutation still remains reducer-observable via scoped stack binding.

### Takeaway
- `StackState` + `StackAction` makes navigation transitions part of domain state, so push/pop flows are inspectable and deterministic.
- Parent remains coordinator while children keep local behavior boundaries.

## Stage 4 - Exercise C (Lifecycle edge cases)

### Goal
- Validate navigation/lifecycle behavior when collection state changes under an active destination.
- Make edge cases explicit: deleting a task while its detail is visible, and stopping in-flight detail work before popping.

### Hands-on changes
- Updated `tca-elements/TasksFeature.swift`:
  - added delegate case `taskDeleted(TaskItem.ID)`
  - on row delete, collection still removes by ID and now sends delegate intent upward
- Updated `tca-elements/AppFeature.swift`:
  - handles `.tasksFeature(.delegate(.taskDeleted(taskID)))`
  - removes matching detail destinations from `detailPath`
- Updated `tca-elements/ContentView.swift`:
  - `TaskDetailView` pop button now sends `.stopHeartbeat` before `dismiss()`

### What we observed
- If the currently visible task is deleted from the list, parent path state now removes that detail destination, preventing stale detail screens.
- Explicitly stopping heartbeat before pop makes the effect lifetime decision obvious in reducer flow (instead of relying solely on automatic teardown).

### Caveats
- Only programmatic pop button currently sends `.stopHeartbeat`; gesture/back-button pops still rely on stack lifecycle teardown.
- Detail still holds a snapshot of task content; if row data changes elsewhere, the visible detail state may not automatically mirror those edits.

### Takeaway
- Collection and navigation state must be coordinated when identity can disappear mid-flow.
- Stage 4C is less about new API and more about enforcing lifecycle invariants in reducer logic.

## Stage 5 - Exercise A (Sheet + draft commit/discard)

### Goal
- Model edit-task presentation as explicit transient state using `@Presents` and `PresentationAction`.
- Separate draft edits from committed task state, then choose save (commit) vs discard (dismiss).

### Hands-on changes
- Updated `tca-elements/TaskDetailFeature.swift`:
  - added nested `EditSheetFeature` with `BindingReducer`
  - added `@Presents var editSheet: EditSheetFeature.State?`
  - added actions: `editButtonTapped`, `editSheet(PresentationAction<...>)`
  - `editButtonTapped` seeds draft fields from current task
  - `saveButtonTapped` commits draft into `state.task`, dismisses sheet, and delegates `.taskUpdated`
  - `cancelButtonTapped` dismisses sheet without committing
  - composed sheet reducer with `.ifLet(\.$editSheet, action: \.editSheet)`
- Updated `tca-elements/ContentView.swift`:
  - `TaskDetailView` now has an `Edit task` button
  - added sheet presentation via `.sheet(item: $store.scope(state: \.editSheet, action: \.editSheet))`
  - added `TaskEditSheetView` form for title/completed draft editing with Save/Discard toolbar actions
- Updated `tca-elements/AppFeature.swift`:
  - handles detail delegate `.taskUpdated(task)` to sync list row state with committed edits

### Key decisions
- **Primitive draft fields** (`draftTitle`, `draftIsDone`) were used instead of binding through full `TaskItem` to avoid isolated-conformance issues under the project actor-isolation settings.
- **Commit happens in detail domain first**, then parent synchronization updates list row projection.
- **Discard is state-only dismissal**: no accidental mutation leaks into canonical task state.

### Caveats
- Gesture-driven sheet dismissal currently behaves like cancel (no commit), which is acceptable for this exercise but should be explicitly tested in Stage 6.

### Takeaway
- `@Presents` cleanly models transient presentation lifecycle in reducer state.
- Draft state provides controlled edit semantics: mutate locally, commit intentionally, or dismiss safely.

## Stage 5 - Exercise B (Alerts and confirmation)

### Goal
- Model destructive confirmation and user-facing validation errors as reducer state.
- Keep alert presentation and button intents explicit in domain actions.

### Hands-on changes
- Updated `tca-elements/TaskDetailFeature.swift`:
  - added `@Presents var alert: AlertState<Action.Alert>?`
  - added `Action.alert(PresentationAction<Alert>)`
  - added nested `Action.Alert` cases:
    - `confirmDeleteTapped`
    - `validationErrorOkTapped`
  - `deleteButtonTapped` now sets alert state for destructive confirmation instead of deleting immediately
  - `alert(.presented(.confirmDeleteTapped))` delegates actual deletion
  - save validation now checks empty/whitespace titles and raises an error alert
  - composed alert reducer with `.ifLet(\.$alert, action: \.alert)`
- Updated `tca-elements/ContentView.swift`:
  - `TaskDetailView` now presents reducer-driven alerts via `.alert($store.scope(state: \.alert, action: \.alert))`

### Key decisions
- **Alerts are state:** the UI does not decide alert existence; reducer does.
- **Buttons are actions:** destructive and acknowledgement button taps are explicit domain events.
- **Validation remains deterministic:** invalid save does not mutate canonical task state.

### Takeaway
- Confirmation and errors are not incidental UI effects; they are part of feature behavior and belong in state/action modeling.

## Stage 5 - Exercise C (Bindings and ownership)

### Goal
- Compare TCA binding support with explicit action-based updates and local native view state.
- Keep mutation ownership explicit and avoid cross-feature uncontrolled two-way mutation.

### Hands-on changes
- Updated `tca-elements/TaskDetailFeature.swift` (`EditSheetFeature`):
  - retained `BindingReducer` and `BindableAction` for text editing (`draftTitle`)
  - added explicit action `completionToggled(Bool)` for completion state mutation path
- Updated `tca-elements/ContentView.swift` (`TaskEditSheetView`):
  - `TextField` still uses `$store.draftTitle` (TCA binding action flow)
  - `Toggle("Completed")` now uses manual `Binding(get:set:)` sending `.completionToggled`
  - added local `@State` toggle (`showBindingNotes`) to show purely view-local UI state that does not belong in reducer state

### Comparison snapshot
- **TCA binding support (`BindingReducer`)**: minimal boilerplate for form fields that map directly to feature state.
- **Explicit actions**: clearer intent boundaries when each mutation should be semantically named.
- **Native local state (`@State`)**: best for purely presentational concerns with no domain meaning.

### Takeaway
- Use binding reducers for ergonomic form editing inside feature boundaries.
- Prefer explicit actions when a mutation represents domain intent.
- Keep local UI-only toggles out of reducer state to avoid unnecessary domain churn.

## Stage 6 - Exercise A (Reducer tests with TestStore)

### Goal
- Make synchronous reducer behavior concrete with executable assertions, especially around collection updates and parent coordination.
- Demonstrate that TCA tests assert state transitions and action flow, not SwiftUI rendering.

### Hands-on changes
- Added a new unit test target and source directory:
  - `tca-elementsTests/Stage6AReducerTests.swift`
- Added four reducer-focused tests using `TestStore`:
  - `testCounterSynchronousFlow`
  - `testTasksAddAndToggleCollectionState`
  - `testTasksDeleteRoutesDelegateAndTransitionsToIdleWhenEmpty`
  - `testAppFeatureSelectionPushesDetailPath`
- Coverage emphasis for this exercise:
  - direct action -> state mutation assertions
  - collection identity updates (`IdentifiedArrayOf`) through row actions
  - delegate emission after delete
  - parent coordination of navigation path append

### Specific considerations
- The delete test intentionally asserts both structural state mutation and follow-up delegate action receipt; this captures a common mistake where teams verify only one side of the flow.
- Stage 6A stays synchronous on purpose; async effect/cancellation assertions are deferred to Stage 6B for tighter mental separation.
- Tests are reducer-domain assertions; they do not prove view layout, button wiring, or animation behavior.

### Takeaway
- `TestStore` turns architecture claims into verifiable contracts: given an action, we can assert exact state deltas and emitted follow-up actions.
- Collection behavior becomes safer when tested by identity (`id`) instead of index assumptions.
- Parent-child coordination can be validated without rendering a single SwiftUI view, which keeps failures localized and actionable.

## Stage 6 - Exercise B (Effect tests)

### Goal
- Verify async reducer behavior deterministically: success, failure/retry, cancellation, and stale-response protection.
- Assert effect-driven action flow in `TasksFeature` without involving SwiftUI rendering.

### Hands-on changes
- Added effect-focused `TestStore` coverage in `tca-elementsTests/Stage6BEffectTests.swift`:
  - `testLoadTasksSuccessFlow`
  - `testLoadTasksFailureThenRetrySuccess`
  - `testCancelLoadTasksCancelsInFlightEffect`
  - `testStaleTasksResponseIsIgnored`
- Dependency overrides used in tests:
  - direct `taskClient.loadTasks` success fixture
  - fail-first then success behavior using an actor-backed attempt counter
  - long-running load (`Task.sleep`) to assert cancellation path
- State/action assertions emphasize:
  - `latestTasksRequestID` increments
  - `tasksPhase` transitions (`idle -> loading -> loaded/failed`)
  - stale `tasksResponse(requestID:)` is ignored when request ID is old

### Specific considerations
- Cancellation is asserted through resulting state and `store.finish()`, which ensures no unexpected trailing effects are emitted.
- The stale-response test encodes a key race invariant: only the latest in-flight request may mutate tasks state.
- Error assertions stay user-facing (`.failed("Expected test failure")`) rather than binding tests to low-level thrown error types.

### Verification
- Ran:
  - `xcodebuild test -project tca-elements.xcodeproj -scheme tca-elements -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' -only-testing:tca-elementsTests/Stage6BEffectTests`
- Result: `** TEST SUCCEEDED **` (all 4 Stage 6B tests passed).

### Takeaway
- Effect tests make concurrency behavior explicit, repeatable, and safe to refactor.
- Request IDs + cancellation IDs are not implementation noise; they are testable domain invariants.

## Stage 6 - Exercise C (Regression tests)

### Goal
- Capture lifecycle and synchronization regressions between task list state and stack-based detail navigation state.
- Lock in behavior for delete/update flows crossing feature boundaries.

### Hands-on changes
- Added regression suite in `tca-elementsTests/Stage6CRegressionTests.swift`:
  - `testDeletingTaskFromListAlsoRemovesMatchingDetail`
  - `testDeletingTaskFromDetailAlsoRemovesListRowAndResetsIdleWhenEmpty`
  - `testUpdatingTaskFromDetailKeepsListInSync`
- Updated parent coordination in `tca-elements/AppFeature.swift` for list-originated deletes:
  - on `.tasksFeature(.delegate(.taskDeleted(taskID)))`, parent now removes the row from `tasksFeature.tasks`, sets `tasksPhase = .idle` when the list becomes empty, and removes matching detail destinations from `detailPath`.
- Aligned test expectation with reducer invariant:
  - when last task is deleted, expected `tasksPhase` is `.idle` (not `.loaded`).

### Specific considerations
- `detailPath` is `StackState<TaskDetailFeature.State>`, so clearing assertions use `StackState()`.
- Stage 6C focuses on cross-feature invariants rather than isolated child behavior.
- The update-flow test intentionally asserts list synchronization while the pushed detail state remains a snapshot, documenting current ownership boundaries.

### Verification
- Ran:
  - `xcodebuild test -project tca-elements.xcodeproj -scheme tca-elements -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' -only-testing:tca-elementsTests/Stage6CRegressionTests`
- Result: `** TEST SUCCEEDED **` (all 3 Stage 6C tests passed).

### Takeaway
- Regression tests encode feature-boundary contracts that are easy to break during refactors.
- Keeping list and navigation state synchronized on deletion avoids stale destination state and UI drift.

## Stage 7 - Exercise A (Modular boundaries)

### Goal
- Evaluate whether extracting feature code into local Swift packages improves architecture clarity, dependency direction, and test/build scope for this project state.
- Identify the smallest useful extraction without introducing micro-modules.

### Current project state
- Project remains single-target app + tests (`tca-elements`, `tca-elementsTests`).
- Resolved TCA version remains `1.26.2`.
- No local Swift package manifest currently exists in workspace (no `Package.swift`).

### Prediction question
- If we extract task-domain code first, what breaks earliest: navigation coordination, model ownership, or dependency registration?

### Hands-on changes (analysis pass)
- Audited boundaries across:
  - `tca-elements/AppFeature.swift`
  - `tca-elements/TasksFeature.swift`
  - `tca-elements/TaskRowFeature.swift`
  - `tca-elements/TaskDetailFeature.swift`
  - `tca-elements/TaskClient.swift`
  - `tca-elements/SettingsFeature.swift`
  - Stage 6 test files
- Identified coupling and ownership:
  - parent orchestration and cross-feature synchronization live in `AppFeature`
  - task model and client dependency key are currently colocated in `TaskClient.swift`
  - `SettingsFeature` is already isolated
- Chosen minimal extraction candidate for next step:
  - package scope tentatively named `TasksKit`
  - include `TasksFeature`, `TaskRowFeature`, and task-domain model/dependency interfaces
  - keep app-specific client implementations and parent coordination in app target

### Hands-on changes (implementation pass)
- Created local Swift package at `Packages/TasksKit`:
  - `Packages/TasksKit/Package.swift`
  - `Packages/TasksKit/Sources/TasksKit/TaskItem.swift`
  - `Packages/TasksKit/Sources/TasksKit/TaskClient.swift`
  - `Packages/TasksKit/Sources/TasksKit/TaskRowFeature.swift`
  - `Packages/TasksKit/Sources/TasksKit/TasksFeature.swift`
- Added local package linkage in `tca-elements.xcodeproj/project.pbxproj`:
  - `XCLocalSwiftPackageReference` for `Packages/TasksKit`
  - app target `packageProductDependencies` includes `TasksKit`
  - app Frameworks phase now links `TasksKit`
- Converted app feature files to package bridges:
  - `tca-elements/TasksFeature.swift` -> `typealias TasksFeature = TasksKit.TasksFeature`
  - `tca-elements/TaskRowFeature.swift` -> `typealias TaskRowFeature = TasksKit.TaskRowFeature`
  - `tca-elements/TaskClient.swift` now bridges `TaskItem`/`TaskClient` via typealias and keeps only concrete app implementations (`fixture`, `live`, `failFirstThenFixture`)
- Added explicit `import TasksKit` where required under member-import visibility checks:
  - app: `AppFeature.swift`, `ContentView.swift`, `TaskDetailFeature.swift`, `CounterFeature.swift`, `tca_elementsApp.swift`
  - tests: `Stage6AReducerTests.swift`, `Stage6BEffectTests.swift`, `Stage6CRegressionTests.swift`

### Why this result occurs (State -> Action -> Reducer -> Effect)
- Parent (`AppFeature`) currently enforces multi-feature invariants (list/detail sync on delete/update), so moving it too early would spread orchestration across package boundaries.
- Child task reducers are already mostly self-contained and communicate via delegate actions, making them better first extraction candidates.
- Dependency injection already passes through `DependencyValues`, so package boundaries can remain explicit if interfaces are extracted without concrete runtime wiring.

### Alternative native SwiftUI approach
- Keep everything app-local and rely on folders + conventions until either:
  - compile times become problematic, or
  - ownership boundaries become repeatedly violated.
- This remains simpler short-term, but does not enforce import-level architectural direction.

### Journal decision and takeaway
- Decision: perform a **small, feature-first extraction** (tasks domain only) rather than splitting every feature into separate modules.
- Main risk to control: avoid circular ownership between `TaskItem`, reducer code, and concrete `TaskClient` implementations.
- Evidence-based boundary rule: extract reducers + model interfaces first, keep app orchestration and live wiring local until a later step proves additional modularization value.

### Verification
- Ran:
  - `xcodebuild test -project tca-elements.xcodeproj -scheme tca-elements -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' -only-testing:tca-elementsTests/Stage6BEffectTests -only-testing:tca-elementsTests/Stage6CRegressionTests`
- Result: `** TEST SUCCEEDED **` (7 tests passed across Stage 6B + Stage 6C).
