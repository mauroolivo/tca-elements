# TCA Cheatsheet (Project Version: 1.26.2)

This cheatsheet is aligned with the APIs used in this workspace (`swift-composable-architecture` 1.26.2) and the course exercises.

## 1) Core mental model

- **State**: single source of truth for a feature.
- **Action**: all events that can change state or trigger effects.
- **Reducer**: pure state transition + effect description.
- **Store**: runtime that holds state and processes actions.
- **Effect**: async/side work that can emit follow-up actions.

Flow:

`View -> Action -> Reducer -> State mutation -> View update`

With async work:

`View -> Action -> Reducer -> Effect(.run) -> send(new Action) -> Reducer -> State`

## 2) Feature template (observation-era)

```swift
import ComposableArchitecture

@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable {
    var count = 0
  }

  enum Action {
    case incrementButtonTapped
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .incrementButtonTapped:
        state.count += 1
        return .none
      }
    }
  }
}
```

Notes:
- `ReducerOf<Self>` and `Reducer<State, Action>` are equivalent styles in practice.
- `return .none` means no side effect.

## 3) Store wiring

Root store at app entry (stable ownership):

```swift
let store = Store(initialState: AppFeature.State()) {
  AppFeature()
}
```

In a view:

```swift
struct ContentView: View {
  @Bindable var store: StoreOf<AppFeature>

  var body: some View {
    Button("Tap") { store.send(.someAction) }
  }
}
```

## 4) Dependencies

Read in reducer:

```swift
@Dependency(\.date.now) var now
@Dependency(\.taskClient) var taskClient
```

Expose custom dependency key:

```swift
extension DependencyValues {
  var taskClient: TaskClient {
    get { self[TaskClient.self] }
    set { self[TaskClient.self] = newValue }
  }
}

extension TaskClient: DependencyKey {
  static let liveValue = TaskClient.fixture
  static let testValue = TaskClient.fixture
  static let previewValue = TaskClient.fixture
}
```

Override at root/preview/test:

```swift
withDependencies {
  $0.taskClient = .fixture
}
```

## 5) Async effects and cancellation

Start effect:

```swift
return .run { send in
  let tasks = try await taskClient.loadTasks()
  await send(.tasksResponse(requestID: requestID, .success(tasks)))
}
.cancellable(id: loadTasksCancellationID, cancelInFlight: true)
```

Cancel effect:

```swift
return .cancel(id: loadTasksCancellationID)
```

Guidelines:
- Use a cancellation ID for long-running or repeatable work.
- Use request IDs to ignore stale responses when needed.

## 6) Composition

Always-on child:

```swift
Scope(state: \.settingsFeature, action: \.settingsFeature) {
  SettingsFeature()
}
```

Optional child:

```swift
.ifLet(\.taskDetailFeature, action: \.taskDetailFeature) {
  TaskDetailFeature()
}
```

Collection child routing:

```swift
.forEach(\.tasks, action: \.taskRows) {
  TaskRowFeature()
}
```

## 7) Navigation (stack)

State/action:

```swift
var detailPath = StackState<TaskDetailFeature.State>()
case detailPath(StackActionOf<TaskDetailFeature>)
```

Reducer composition:

```swift
.forEach(\.detailPath, action: \.detailPath) {
  TaskDetailFeature()
}
```

View binding:

```swift
NavigationStack(path: $store.scope(state: \.detailPath, action: \.detailPath)) {
  // root
} destination: { detailStore in
  TaskDetailView(store: detailStore)
}
```

## 8) Presentation

Sheet state:

```swift
@Presents var editSheet: EditSheetFeature.State?
case editSheet(PresentationAction<EditSheetFeature.Action>)
```

Compose:

```swift
.ifLet(\.$editSheet, action: \.editSheet) {
  EditSheetFeature()
}
```

Handle child-presented action:

```swift
case .editSheet(.presented(.saveButtonTapped)):
  // commit draft
```

Alerts:

```swift
@Presents var alert: AlertState<Action.Alert>?
case alert(PresentationAction<Alert>)
```

View:

```swift
.alert($store.scope(state: \.alert, action: \.alert))
```

## 9) Bindings

Reducer support:

```swift
enum Action: BindableAction {
  case binding(BindingAction<State>)
}

var body: some ReducerOf<Self> {
  BindingReducer()
  Reduce { state, action in
    .none
  }
}
```

View usage:

```swift
TextField("Title", text: $store.draftTitle)
```

Use explicit actions when mutation should carry domain intent.

## 10) Delegation pattern

Child action:

```swift
case delegate(Delegate)
enum Delegate { case taskSelected(TaskItem) }
```

Child emits:

```swift
return .send(.delegate(.taskSelected(task)))
```

Parent handles:

```swift
case let .tasksFeature(.delegate(.taskSelected(task))):
  state.detailPath.append(TaskDetailFeature.State(task: task))
  return .none
```

## 11) Practical ownership rules (used in this lab)

- Row reducer mutates row-local fields.
- Collection owner handles structural edits (add/remove).
- Parent app reducer handles cross-feature invariants and navigation.
- Detail feature can own draft/presentation state.

## 12) Common pitfalls

- Sending optional-child actions after child state is `nil` (`ifLet` warning).
- Duplicating derived state without sync rules.
- Replacing collections on load when merge/upsert semantics are required.
- Over-delegating every child action to parent.
- Treating tests as UI rendering proof (they are reducer/effect proofs).
