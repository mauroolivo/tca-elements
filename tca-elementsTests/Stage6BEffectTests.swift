import XCTest
import ComposableArchitecture
@testable import tca_elements

@MainActor
final class Stage6BEffectTests: XCTestCase {
    func testLoadTasksSuccessFlow() async {
        let loadedTasks = [
            TaskItem(id: 10, title: "Read Stage 6B", isDone: false),
            TaskItem(id: 11, title: "Write effect tests", isDone: true)
        ]

        let store = TestStore(initialState: TasksFeature.State()) {
            TasksFeature()
        } withDependencies: {
            $0.taskClient.loadTasks = { loadedTasks }
        }

        await store.send(.loadTasksButtonTapped) {
            $0.latestTasksRequestID = 1
            $0.tasksPhase = .loading
        }

        await store.receive(.tasksResponse(requestID: 1, .success(loadedTasks))) {
            $0.tasks = IdentifiedArray(uniqueElements: loadedTasks.map { TaskRowFeature.State(task: $0) })
            $0.tasksPhase = .loaded
        }
    }

    func testLoadTasksFailureThenRetrySuccess() async {
        enum TestError: LocalizedError {
            case expectedFailure

            var errorDescription: String? {
                "Expected test failure"
            }
        }

        actor Attempts {
            var count = 0
            func next() -> Int {
                count += 1
                return count
            }
        }

        let attempts = Attempts()
        let loadedTasks = [TaskItem(id: 21, title: "Recovered task", isDone: false)]

        let store = TestStore(initialState: TasksFeature.State()) {
            TasksFeature()
        } withDependencies: {
            $0.taskClient.loadTasks = {
                let attempt = await attempts.next()
                if attempt == 1 {
                    throw TestError.expectedFailure
                }
                return loadedTasks
            }
        }

        await store.send(.loadTasksButtonTapped) {
            $0.latestTasksRequestID = 1
            $0.tasksPhase = .loading
        }

        await store.receive(
            .tasksResponse(requestID: 1, .failure(.message("Expected test failure")))
        ) {
            $0.tasks = []
            $0.tasksPhase = .failed("Expected test failure")
        }

        await store.send(.loadTasksButtonTapped) {
            $0.latestTasksRequestID = 2
            $0.tasksPhase = .loading
        }

        await store.receive(.tasksResponse(requestID: 2, .success(loadedTasks))) {
            $0.tasks = IdentifiedArray(uniqueElements: loadedTasks.map { TaskRowFeature.State(task: $0) })
            $0.tasksPhase = .loaded
        }
    }

    func testCancelLoadTasksCancelsInFlightEffect() async {
        let store = TestStore(initialState: TasksFeature.State()) {
            TasksFeature()
        } withDependencies: {
            $0.taskClient.loadTasks = {
                try await Task.sleep(for: .seconds(60))
                return []
            }
        }

        await store.send(.loadTasksButtonTapped) {
            $0.latestTasksRequestID = 1
            $0.tasksPhase = .loading
        }

        await store.send(.cancelLoadTasksButtonTapped) {
            $0.tasksPhase = .idle
        }

        await store.finish()
    }

    func testStaleTasksResponseIsIgnored() async {
        var initialState = TasksFeature.State()
        initialState.latestTasksRequestID = 2
        initialState.tasksPhase = .loading

        let store = TestStore(initialState: initialState) {
            TasksFeature()
        }

        let staleTasks = [TaskItem(id: 30, title: "Stale", isDone: false)]
        let latestTasks = [TaskItem(id: 31, title: "Fresh", isDone: true)]

        await store.send(.tasksResponse(requestID: 1, .success(staleTasks)))

        await store.send(.tasksResponse(requestID: 2, .success(latestTasks))) {
            $0.tasks = IdentifiedArray(uniqueElements: latestTasks.map { TaskRowFeature.State(task: $0) })
            $0.tasksPhase = .loaded
        }
    }
}
