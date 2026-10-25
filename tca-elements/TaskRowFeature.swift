import ComposableArchitecture

@Reducer
struct TaskRowFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        var task: TaskItem

        var id: TaskItem.ID {
            task.id
        }
    }

    enum Action {
        case rowTapped
        case toggleCompletionTapped
        case deleteTapped
        case delegate(Delegate)
    }

    enum Delegate {
        case taskSelected(TaskItem)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .rowTapped:
                return .send(.delegate(.taskSelected(state.task)))

            case .toggleCompletionTapped:
                state.task.isDone.toggle()
                return .none

            case .deleteTapped:
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
