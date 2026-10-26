import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var tasksFeature = TasksFeature.State()
        var settingsFeature = SettingsFeature.State()
        var detailPath = StackState<TaskDetailFeature.State>()
    }

    enum Action {
        case tasksFeature(TasksFeature.Action)
        case settingsFeature(SettingsFeature.Action)
        case detailPath(StackActionOf<TaskDetailFeature>)
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
            case let .tasksFeature(.delegate(.taskSelected(task))):
                state.detailPath.append(TaskDetailFeature.State(task: task))
                return .none

            case let .tasksFeature(.delegate(.taskDeleted(taskID))):
                state.tasksFeature.tasks.remove(id: taskID)
                if state.tasksFeature.tasks.isEmpty {
                    state.tasksFeature.tasksPhase = .idle
                }
                state.detailPath.removeAll { $0.task.id == taskID }
                return .none

            case let .detailPath(.element(id: _, action: .delegate(.taskDeleted(taskID)))):
                state.tasksFeature.tasks.remove(id: taskID)
                if state.tasksFeature.tasks.isEmpty {
                    state.tasksFeature.tasksPhase = .idle
                }
                state.detailPath.removeAll { $0.task.id == taskID }
                return .none

            case let .detailPath(.element(id: _, action: .delegate(.taskUpdated(task)))):
                state.tasksFeature.tasks[id: task.id]?.task = task
                return .none

            case .tasksFeature, .settingsFeature, .detailPath:
                return .none
            }
        }
        .forEach(\.detailPath, action: \.detailPath) {
            TaskDetailFeature()
        }
    }
}
