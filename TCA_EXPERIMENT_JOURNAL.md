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

### Takeaway
- In observation-era TCA, action names express user intent, reducers mutate state synchronously, and views simply send actions.
- Store lifetime matters: placing the root store in `App` gives stable identity across SwiftUI view refreshes.

## Stage 1 - Exercise B (State boundaries)
- Added a computed derived value in reducer state:
  - `displayCount` is computed from `count` and has no independent storage.
- Added an intentionally duplicated stored value:
  - `cachedDisplayCount` duplicates the same concept and can drift.
- Added deliberate inconsistency actions:
  - `corruptCachedDisplayTapped` makes duplicate state stale on purpose.
  - `repairCachedDisplayTapped` re-syncs duplicate state from source.
- Added a transient UI concern as local SwiftUI state in `ContentView`:
  - `@State private var showRawCount` controls visibility only and does not belong in domain state.

### Takeaway
- Keep canonical domain data in reducer state (`count`), compute derived display values when possible (`displayCount`), and avoid duplicate stored derivations (`cachedDisplayCount`) unless there is a strong, explicit reason.
- Purely presentational toggles with no domain meaning can remain local to the view.
## Stage 1 - Exercise C (Dependency preview)
- Re-centered the active screen from the Stage 1B inconsistency demo to a minimal dependency-focused variant.
- Added a reducer dependency:
  - `@Dependency(\.date.now) var now`
- Added a new action:
  - `captureNowButtonTapped` assigns `state.lastUpdated = now`
- Kept synchronous counter actions unchanged to isolate dependency learning.
- Updated preview store dependencies for determinism:
  - `withDependencies { $0.date.now = Date(timeIntervalSince1970: 1_700_000_000) }`

### Takeaway
- Dependencies in TCA are read where behavior needs them (the reducer), not from the view.
- Previews can override dependencies to produce stable, repeatable output while still exercising real reducer logic.

## Stage 2 - Async effect + custom dependency key
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

### Stage 2 Verification Checklist
- [ ] Tapping "Load tasks" transitions from `.idle` to `.loading` and then `.loaded`.
- [ ] Loaded tasks render from fixture data.
- [ ] Counter actions (`+1`, `-1`, `Reset`) still work unchanged.
- [ ] `captureNowButtonTapped` still updates `lastUpdated`.
- [ ] Failure branch renders a readable `.failed(message)` state if `taskClient` throws.

### Takeaway
- A custom dependency in TCA is exposed in two places: a `DependencyValues` computed property (for key-path access) and `DependencyKey` conformance (for default values).
- Async side effects stay in the reducer, while the view remains a projection of state plus action sends.

## Stage 2 - Exercise B (Failure and retry)
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

### Takeaway
- Failure and retry work best when modeled as a single state machine (`idle/loading/loaded/failed`) rather than separate, potentially contradictory booleans.

## Stage 2 - Exercise C (Cancellation and races)
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

### Takeaway
- Cancellation IDs control effect lifetime, while request IDs guard state against stale async responses.
- `cancelInFlight: true` makes repeated user intent (reload) deterministic: newest request wins.
