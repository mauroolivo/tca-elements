import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var tasksFeature = TasksFeature.State()
        var settingsFeature = SettingsFeature.State()
    }

    enum Action {
        case tasksFeature(TasksFeature.Action)
        case settingsFeature(SettingsFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.tasksFeature, action: \.tasksFeature) {
            TasksFeature()
        }
        Scope(state: \.settingsFeature, action: \.settingsFeature) {
            SettingsFeature()
        }
        Reduce { _, _ in
            .none
        }
    }
}
