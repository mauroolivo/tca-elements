import XCTest
import ComposableArchitecture
import TasksKit
@testable import tca_elements

@MainActor
final class Stage6AReducerTests: XCTestCase {
    func testCounterSynchronousFlow() async {
        let store = TestStore(initialState: CounterFeature.State()) {
            CounterFeature()
        }

        await store.send(.incrementButtonTapped) {
            $0.count = 1
        }
        await store.send(.incrementButtonTapped) {
            $0.count = 2
        }
        await store.send(.decrementButtonTapped) {
            $0.count = 1
        }
        await store.send(.resetButtonTapped) {
            $0.count = 0
        }
    }

    func testTasksAddAndToggleCollectionState() async {
        let store = TestStore(initialState: TasksFeature.State()) {
            TasksFeature()
        }

        await store.send(.addTaskButtonTapped) {
            $0.tasks.append(
                TaskRowFeature.State(
                    task: TaskItem(id: 1_000, title: "New task #1000", isDone: false)
                )
            )
            $0.tasksPhase = .loaded
            $0.nextLocalTaskID = 1_001
        }

        await store.send(.taskRows(.element(id: 1_000, action: .toggleCompletionTapped))) {
            $0.tasks[id: 1_000]?.task.isDone = true
        }
    }

    func testTasksDeleteRoutesDelegateAndTransitionsToIdleWhenEmpty() async {
        var initial = TasksFeature.State()
        initial.tasks = [
            TaskRowFeature.State(task: TaskItem(id: 7, title: "One", isDone: false))
        ]
        initial.tasksPhase = .loaded

        let store = TestStore(initialState: initial) {
            TasksFeature()
        }

        await store.send(.taskRows(.element(id: 7, action: .deleteTapped))) {
            $0.tasks = []
            $0.tasksPhase = .idle
        }

        await store.receive(.delegate(.taskDeleted(7)))
    }

    func testAppFeatureSelectionPushesDetailPath() async {
        let selectedTask = TaskItem(id: 42, title: "Selected", isDone: false)

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.tasksFeature(.delegate(.taskSelected(selectedTask)))) {
            $0.detailPath.append(TaskDetailFeature.State(task: selectedTask))
        }
    }
}
