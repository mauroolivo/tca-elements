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
        var latestTasksRequestID = 0
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
        case cancelLoadTasksButtonTapped
        case tasksResponse(requestID: Int, Result<[TaskItem], TaskLoadError>)
    }

    private let loadTasksCancellationID = "loadTasks"

    enum TaskLoadError: Error, Equatable {
        case message(String)
    }

    //this function is the reducer function that takes the current state and an action, and returns an effect that produces new actions. It is responsible for handling the logic of how the state changes in response to actions, and can also initiate side effects such as asynchronous tasks.
    // (inout State, Action) -> Effect<Action>
    // The closure returns an effect that may emit more actions later.
    // So reducers do 2 things
    // 1 Synchronous state mutation now.
    // 2 Return an effect describing async/side work (or none)
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
                state.latestTasksRequestID += 1
                let requestID = state.latestTasksRequestID
                state.tasksPhase = .loading
                
                // .run is non-isolated by default
                // the .run closure is @Sendable async work, and it is not automatically @MainActor.
                // .run work is non-isolated by default, but await send(...) re-enters the store pipeline before this reducer code runs.
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
