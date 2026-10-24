import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var tasksFeature = TasksFeature.State()
        var settingsFeature = SettingsFeature.State()
        var taskDetailFeature: TaskDetailFeature.State?
    }

    enum Action {
        case tasksFeature(TasksFeature.Action)
        case settingsFeature(SettingsFeature.Action)
        case taskDetailFeature(TaskDetailFeature.Action)
        case dismissTaskDetailButtonTapped
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.tasksFeature, action: \.tasksFeature) {
            TasksFeature()
        }
        Scope(state: \.settingsFeature, action: \.settingsFeature) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case let .tasksFeature(.taskTapped(taskID)):
                guard let task = state.tasksFeature.tasks.first(where: { $0.id == taskID }) else {
                    return .none
                }
                state.taskDetailFeature = TaskDetailFeature.State(task: task)
                return .none

            case .dismissTaskDetailButtonTapped:
                state.taskDetailFeature = nil
                return .none

            case .tasksFeature, .settingsFeature, .taskDetailFeature:
                return .none
            }
        }
        .ifLet(\.taskDetailFeature, action: \.taskDetailFeature) {
            TaskDetailFeature()
        }
    }
}
