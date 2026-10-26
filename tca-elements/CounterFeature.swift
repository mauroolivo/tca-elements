import Foundation
import ComposableArchitecture
import TasksKit

@Reducer
struct CounterFeature {
    @Dependency(\.date.now) var now

    @ObservableState
    struct State: Equatable {
        var count = 0
        var lastUpdated: Foundation.Date?
    }

    enum Action {
        case incrementButtonTapped
        case decrementButtonTapped
        case resetButtonTapped
        case captureNowButtonTapped
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
            }
        }
    }
}
