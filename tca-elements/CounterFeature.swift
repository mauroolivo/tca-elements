import Foundation
import ComposableArchitecture

@Reducer
struct CounterFeature {
    @Dependency(\.date.now) var now
    @Dependency(\.taskClient) var taskClient

    @ObservableState
    struct State: Equatable {
        var count = 0
        var lastUpdated: Foundation.Date?
        var tasks: [TaskItem] = []
        var tasksPhase: TasksPhase = .idle
    }

    enum TasksPhase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum Action {
        case incrementButtonTapped
        case decrementButtonTapped
        case resetButtonTapped
        case captureNowButtonTapped
        case loadTasksButtonTapped
        case tasksResponse(Result<[TaskItem], TaskLoadError>)
    }

    enum TaskLoadError: Error, Equatable {
        case message(String)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .incrementButtonTapped:
                state.count += 1
                return .none

            case .decrementButtonTapped:
                state.count -= 1
                return .none

            case .resetButtonTapped:
                state.count = 0
                return .none

            case .captureNowButtonTapped:
                state.lastUpdated = now
                return .none

            case .loadTasksButtonTapped:
                state.tasksPhase = .loading
                return .run { send in
                    do {
                        let tasks = try await taskClient.loadTasks()
                        await send(.tasksResponse(.success(tasks)))
                    } catch {
                        await send(.tasksResponse(.failure(.message(error.localizedDescription))))
                    }
                }

            case let .tasksResponse(.success(tasks)):
                state.tasks = tasks
                state.tasksPhase = .loaded
                return .none

            case let .tasksResponse(.failure(.message(message))):
                state.tasks = []
                state.tasksPhase = .failed(message)
                return .none
            }
        }
    }
}
