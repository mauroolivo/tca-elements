import Foundation
import ComposableArchitecture

@Reducer
struct TaskDetailFeature {
    @ObservableState
    struct State: Equatable {
        var task: TaskItem
        var heartbeatCount = 0
        var isHeartbeatRunning = false
    }

    enum Action {
        case startHeartbeat
        case stopHeartbeat
        case heartbeatTick
        case deleteButtonTapped
        case delegate(Delegate)
    }

    enum Delegate {
        case taskDeleted(TaskItem.ID)
    }

    private let heartbeatCancellationID = "taskDetail.heartbeat"

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startHeartbeat:
                guard !state.isHeartbeatRunning else {
                    return .none
                }
                state.isHeartbeatRunning = true
                return .run { send in
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(1))
                        await send(.heartbeatTick)
                    }
                }
                .cancellable(id: heartbeatCancellationID, cancelInFlight: true)

            case .stopHeartbeat:
                state.isHeartbeatRunning = false
                return .cancel(id: heartbeatCancellationID)

            case .heartbeatTick:
                state.heartbeatCount += 1
                return .none

            case .deleteButtonTapped:
                return .send(.delegate(.taskDeleted(state.task.id)))

            case .delegate:
                return .none
            }
        }
    }
}
