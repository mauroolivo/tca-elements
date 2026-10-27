# TCA Testing Guide (Project Version: 1.26.2)

This guide summarizes the test patterns used in `tca-elementsTests` and how to scale them safely.

## 1) What TestStore proves

`TestStore` proves reducer/effect contracts:

- action sequencing,
- deterministic state transitions,
- emitted follow-up actions,
- cancellation and race handling.

It does **not** prove SwiftUI layout/rendering correctness.

## 2) Base test shape

```swift
import ComposableArchitecture
import XCTest

@MainActor
final class FeatureTests: XCTestCase {
  func testFlow() async {
    let store = TestStore(initialState: Feature.State()) {
      Feature()
    }

    await store.send(.buttonTapped) {
      $0.isLoading = true
    }

    await store.receive(\.response.success) {
      $0.isLoading = false
    }
  }
}
```

## 3) `send` vs `receive` vs `finish`

- `send`: simulate an input action and assert immediate state mutation.
- `receive`: assert effect-emitted follow-up action and resulting state mutation.
- `finish`: ensure in-flight effects complete or cancel; fail on unexpected trailing actions.

## 4) Dependency overrides

Inject deterministic behavior per test:

```swift
let store = TestStore(initialState: TasksFeature.State()) {
  TasksFeature()
} withDependencies: {
  $0.taskClient.loadTasks = {
    [TaskItem(id: 1, title: "A", isDone: false)]
  }
}
```

Tips:
- Keep fixtures small and explicit.
- Prefer behavior-based assertions over implementation details.

## 5) Synchronous reducer tests

Target:
- pure state transitions,
- collection identity updates,
- parent coordination logic.

Examples in this workspace:
- `tca-elementsTests/Stage6AReducerTests.swift`
  - counter transitions,
  - task add/toggle/delete,
  - app path append on selection.

## 6) Effect tests

Target:
- loading/success/failure/retry paths,
- cancellation behavior,
- stale response guards.

Examples:
- `tca-elementsTests/Stage6BEffectTests.swift`

Patterns:

```swift
await store.send(.loadTasksButtonTapped) {
  $0.tasksPhase = .loading
}

await store.receive(\.tasksResponse.success) {
  $0.tasksPhase = .loaded
}
```

Cancellation:

```swift
await store.send(.cancelLoadTasksButtonTapped) {
  $0.tasksPhase = .idle
}
await store.finish()
```

## 7) Regression tests

Use regression tests for cross-feature invariants and lifecycle edges.

Examples:
- `tca-elementsTests/Stage6CRegressionTests.swift`
  - deleting from list prunes matching detail destination,
  - deleting from detail removes row + resets idle when empty,
  - detail update sync behavior.

## 8) Assertions that age well

Prefer assertions on domain outcomes:
- state phase transitions,
- collection identity effects,
- navigation state updates,
- delegate contract behavior.

Avoid brittle assertions on:
- private helper ordering,
- unrelated state fields,
- presentation wording not tied to domain behavior.

## 9) Common failures and fixes

- **`receive` unavailable with action literals**
  - either conform actions to `Equatable` or use case-key-path receives.
- **Optional-child action after state nil**
  - reorder lifecycle or avoid sending from disappearing views.
- **Flaky async timing**
  - override dependencies and control latency deterministically.
- **Stale async writes**
  - assert request-ID guard behavior explicitly.

## 10) Suggested suite split

- Fast core reducer tests (always run): Stage 6A + key Stage 6C.
- Effect lifecycle tests (CI + pre-merge): Stage 6B + full Stage 6C.
- Optional UI/snapshot tests separately (outside reducer contract tests).

## 11) Useful commands

```bash
cd /Users/mauro/files/code/uimatters/tca-elements
xcodebuild test -project tca-elements.xcodeproj -scheme tca-elements -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' -only-testing:tca-elementsTests/Stage6AReducerTests
```

```bash
cd /Users/mauro/files/code/uimatters/tca-elements
xcodebuild test -project tca-elements.xcodeproj -scheme tca-elements -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' -only-testing:tca-elementsTests/Stage6BEffectTests -only-testing:tca-elementsTests/Stage6CRegressionTests
```

## 12) Testing checklist for new features

- [ ] Every user intent action has at least one reducer test.
- [ ] Every async effect has success + failure assertions.
- [ ] Cancellation behavior is asserted where applicable.
- [ ] At least one regression test covers cross-feature invariants.
- [ ] Dependency overrides are deterministic (no live network/time randomness).
