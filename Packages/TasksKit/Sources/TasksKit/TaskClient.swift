import ComposableArchitecture

public struct TaskClient: Sendable {
    public var loadTasks: @Sendable () async throws -> [TaskItem]

    public init(loadTasks: @escaping @Sendable () async throws -> [TaskItem]) {
        self.loadTasks = loadTasks
    }
}

extension DependencyValues {
    public var taskClient: TaskClient {
        get { self[TaskClient.self] }
        set { self[TaskClient.self] = newValue }
    }
}

extension TaskClient: DependencyKey {
    public static let liveValue = TaskClient { [] }
    public static let testValue = TaskClient { [] }
    public static let previewValue = TaskClient { [] }
}
