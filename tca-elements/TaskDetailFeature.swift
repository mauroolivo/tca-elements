import Foundation
import ComposableArchitecture

@Reducer
struct TaskDetailFeature {
    @Reducer
    struct EditSheetFeature {
        @ObservableState
        struct State: Equatable {
            var draftTitle: String
            var draftIsDone: Bool
        }

        enum Action: BindableAction {
            case binding(BindingAction<State>)
            case completionToggled(Bool)
            case saveButtonTapped
            case cancelButtonTapped
        }

        var body: some Reducer<State, Action> {
            BindingReducer()
            Reduce { state, action in
                switch action {
                case let .completionToggled(isDone):
                    state.draftIsDone = isDone
                    return .none

                case .binding, .saveButtonTapped, .cancelButtonTapped:
                    return .none
                }
            }
        }
    }

    @ObservableState
    struct State: Equatable {
        var task: TaskItem
        var heartbeatCount = 0
        var isHeartbeatRunning = false
        @Presents var editSheet: EditSheetFeature.State?
        @Presents var alert: AlertState<Action.Alert>?
    }

    enum Action {
        case startHeartbeat
        case stopHeartbeat
        case heartbeatTick
        case editButtonTapped
        case editSheet(PresentationAction<EditSheetFeature.Action>)
        case deleteButtonTapped
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        @CasePathable
        enum Alert {
            case confirmDeleteTapped
            case validationErrorOkTapped
        }
    }

    enum Delegate {
        case taskDeleted(TaskItem.ID)
        case taskUpdated(TaskItem)
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

            case .editButtonTapped:
                state.editSheet = EditSheetFeature.State(
                    draftTitle: state.task.title,
                    draftIsDone: state.task.isDone
                )
                return .none

            case .editSheet(.presented(.saveButtonTapped)):
                guard let draft = state.editSheet else {
                    return .none
                }
                guard !draft.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    state.alert = AlertState {
                        TextState("Invalid title")
                    } actions: {
                        ButtonState(action: .validationErrorOkTapped) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("Task title cannot be empty.")
                    }
                    return .none
                }
                state.task.title = draft.draftTitle
                state.task.isDone = draft.draftIsDone
                state.editSheet = nil
                return .send(.delegate(.taskUpdated(state.task)))

            case .editSheet(.presented(.cancelButtonTapped)):
                state.editSheet = nil
                return .none

            case .editSheet:
                return .none

            case .deleteButtonTapped:
                state.alert = AlertState {
                    TextState("Delete task?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDeleteTapped) {
                        TextState("Delete")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("This action cannot be undone.")
                }
                return .none

            case .alert(.presented(.confirmDeleteTapped)):
                return .send(.delegate(.taskDeleted(state.task.id)))

            case .alert(.presented(.validationErrorOkTapped)):
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$editSheet, action: \.editSheet) {
            EditSheetFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
