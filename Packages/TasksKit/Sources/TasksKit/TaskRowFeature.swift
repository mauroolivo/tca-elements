import ComposableArchitecture

@Reducer
public struct TaskRowFeature {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public var task: TaskItem

        public var id: TaskItem.ID {
            task.id
        }

        public init(task: TaskItem) {
            self.task = task
        }
    }

    public enum Action: Equatable {
        case rowTapped
        case toggleCompletionTapped
        case deleteTapped
        case delegate(Delegate)
    }

    public enum Delegate: Equatable {
        case taskSelected(TaskItem)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
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
