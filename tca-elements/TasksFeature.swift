import Foundation
import ComposableArchitecture

@Reducer
struct TasksFeature {
    @Dependency(\.taskClient) var taskClient

    @ObservableState
    struct State: Equatable {
        var tasks: IdentifiedArrayOf<TaskRowFeature.State> = []
        var tasksPhase: TasksPhase = .idle
        var latestTasksRequestID = 0
        var nextLocalTaskID = 1_000
    }

    enum TasksPhase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum Action: Equatable {
        case loadTasksButtonTapped
        case cancelLoadTasksButtonTapped
        case addTaskButtonTapped
        case taskRows(IdentifiedActionOf<TaskRowFeature>)
        case delegate(Delegate)
        case tasksResponse(requestID: Int, Result<[TaskItem], TaskLoadError>)
    }

    enum Delegate: Equatable {
        case taskSelected(TaskItem)
        case taskDeleted(TaskItem.ID)
    }

    private let loadTasksCancellationID = "loadTasks"

    enum TaskLoadError: Error, Equatable {
        case message(String)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .loadTasksButtonTapped:
                state.latestTasksRequestID += 1
                let requestID = state.latestTasksRequestID
                state.tasksPhase = .loading

                return .run { send in
                    do {
                        let tasks = try await taskClient.loadTasks()
                        await send(.tasksResponse(requestID: requestID, .success(tasks)))
                    } catch {
                        await send(.tasksResponse(requestID: requestID, .failure(.message(error.localizedDescription))))
                    }
                }
                .cancellable(id: loadTasksCancellationID, cancelInFlight: true)

            case .cancelLoadTasksButtonTapped:
                state.tasksPhase = .idle
                return .cancel(id: loadTasksCancellationID)

            case .addTaskButtonTapped:
                let task = TaskItem(
                    id: state.nextLocalTaskID,
                    title: "New task #\(state.nextLocalTaskID)",
                    isDone: false
                )
                state.nextLocalTaskID += 1
                state.tasks.append(TaskRowFeature.State(task: task))
                state.tasksPhase = .loaded
                return .cancel(id: loadTasksCancellationID)

            case let .taskRows(.element(_, .delegate(.taskSelected(task)))):
                return .send(.delegate(.taskSelected(task)))

            case let .taskRows(.element(id, .deleteTapped)):
                state.tasks.remove(id: id)
                if state.tasks.isEmpty {
                    state.tasksPhase = .idle
                }
                return .send(.delegate(.taskDeleted(id)))

            case .taskRows(.element):
                if state.tasks.isEmpty {
                    state.tasksPhase = .idle
                }
                return .none

            case .taskRows:
                return .none

            case .delegate:
                return .none

            case let .tasksResponse(requestID, .success(tasks)):
                guard requestID == state.latestTasksRequestID else {
                    return .none
                }
                for task in tasks {
                    state.tasks[id: task.id] = TaskRowFeature.State(task: task)
                }
                state.tasksPhase = .loaded
                return .none

            case let .tasksResponse(requestID, .failure(.message(message))):
                guard requestID == state.latestTasksRequestID else {
                    return .none
                }
                state.tasks = []
                state.tasksPhase = .failed(message)
                return .none
            }
        }
        .forEach(\.tasks, action: \.taskRows) {
            TaskRowFeature()
        }
    }
}
