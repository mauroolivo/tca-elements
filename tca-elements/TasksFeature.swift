import Foundation
import ComposableArchitecture

@Reducer
struct TasksFeature {
    @Dependency(\.taskClient) var taskClient

    @ObservableState
    struct State: Equatable {
        var tasks: [TaskItem] = []
        var tasksPhase: TasksPhase = .idle
        var latestTasksRequestID = 0
    }

    enum TasksPhase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum Action {
        case loadTasksButtonTapped
        case cancelLoadTasksButtonTapped
        case tasksResponse(requestID: Int, Result<[TaskItem], TaskLoadError>)
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

            case let .tasksResponse(requestID, .success(tasks)):
                guard requestID == state.latestTasksRequestID else {
                    return .none
                }
                state.tasks = tasks
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
    }
}
