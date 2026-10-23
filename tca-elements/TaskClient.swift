import Foundation
import ComposableArchitecture

struct TaskItem: Equatable, Identifiable, Sendable {
    let id: Int
    var title: String
    var isDone: Bool
}

struct TaskClient {
    var loadTasks: @Sendable () async throws -> [TaskItem]
}

extension TaskClient {
    static let fixture = Self {
        try await Task.sleep(for: .milliseconds(500))
        return [
            TaskItem(id: 1, title: "Draft Stage 2 notes", isDone: false),
            TaskItem(id: 2, title: "Run reducer flow mentally", isDone: true),
            TaskItem(id: 3, title: "Capture one trade-off", isDone: false)
        ]
    }

    // Optional live implementation for experimenting with a real async boundary.
    static let live = Self {
        let url = URL(string: "https://jsonplaceholder.typicode.com/todos?_limit=5")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let todos = try JSONDecoder().decode([TodoDTO].self, from: data)
        return todos.map { todo in
            TaskItem(id: todo.id, title: todo.title, isDone: todo.completed)
        }
    }

    // Deterministic for Stage 2 Exercise B: first call fails, retry succeeds.
    static let failFirstThenFixture: Self = {
        let gate = FailFirstGate()
        return Self {
            if await gate.shouldFail {
                throw Stage2Error.simulatedFailure
            }
            return try await fixture.loadTasks()
        }
    }()
}

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

private struct TodoDTO: Decodable {
    let id: Int
    let title: String
    let completed: Bool
}

private actor FailFirstGate {
    private var failedOnce = false

    var shouldFail: Bool {
        get {
            if failedOnce {
                return false
            }
            failedOnce = true
            return true
        }
    }
}

private enum Stage2Error: LocalizedError {
    case simulatedFailure

    var errorDescription: String? {
        "Simulated failure for Stage 2B. Tap Load tasks again to retry."
    }
}
