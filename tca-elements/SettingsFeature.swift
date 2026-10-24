import ComposableArchitecture

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var showCompletedTasks = true
    }

    enum Action {
        case showCompletedTasksToggled(Bool)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .showCompletedTasksToggled(isOn):
                state.showCompletedTasks = isOn
                return .none
            }
        }
    }
}
