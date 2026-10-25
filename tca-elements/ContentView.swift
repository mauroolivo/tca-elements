//

import Foundation
import SwiftUI
import ComposableArchitecture

struct ContentView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        content
    }

    private var content: some View {
        NavigationStack(path: $store.scope(state: \.detailPath, action: \.detailPath)) {
            Form {
                TasksSectionView(
                    store: store.scope(state: \.tasksFeature, action: \.tasksFeature)
                )

                SettingsSectionView(
                    store: store.scope(state: \.settingsFeature, action: \.settingsFeature)
                )
            }
            .navigationTitle("Stage 4 Navigation")
        } destination: { detailStore in
            TaskDetailView(store: detailStore)
        }
    }
}

struct TasksSectionView: View {
    let store: StoreOf<TasksFeature>

    private var isLoadingTasks: Bool {
        if case .loading = store.tasksPhase {
            return true
        }
        return false
    }

    var body: some View {
        Section("Tasks feature") {
            HStack {
                Button("Load tasks") {
                    store.send(.loadTasksButtonTapped)
                }
                .buttonStyle(.bordered)

                Button("Cancel") {
                    store.send(.cancelLoadTasksButtonTapped)
                }
                .disabled(!isLoadingTasks)
                .buttonStyle(.bordered)

                Button("Add") {
                    store.send(.addTaskButtonTapped)
                }
                .disabled(isLoadingTasks)
                .buttonStyle(.borderedProminent)
            }

            switch store.tasksPhase {
            case .idle:
                Text("Idle. Tap load to run TaskClient.")
                    .foregroundStyle(.secondary)

            case .loading:
                ProgressView("Loading tasks...")

            case .loaded:
                ForEach(store.scope(state: \.tasks, action: \.taskRows)) { rowStore in
                    TaskRowView(store: rowStore)
                }

            case let .failed(message):
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed: \(message)")
                        .foregroundStyle(.red)
                    Text("Tap \"Load tasks\" to retry.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct TaskRowView: View {
    let store: StoreOf<TaskRowFeature>

    var body: some View {
        HStack {
            Button {
                store.send(.rowTapped)
            } label: {
                Label(store.task.title, systemImage: store.task.isDone ? "checkmark.circle.fill" : "circle")
            }

            Spacer()

            Button {
                store.send(.toggleCompletionTapped)
            } label: {
                Image(systemName: store.task.isDone ? "checkmark.circle" : "circle")
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                store.send(.deleteTapped)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
    }
}

struct TaskDetailView: View {
    @Bindable var store: StoreOf<TaskDetailFeature>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Task detail") {
                Text("Selected: \(store.task.title)")
                Text("Heartbeat ticks: \(store.heartbeatCount)")
                    .monospacedDigit()

                Text("Popping this screen removes detail state from the stack.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Pop detail") {
                    store.send(.stopHeartbeat)
                    dismiss()
                }

                Button("Edit task") {
                    store.send(.editButtonTapped)
                }

                Button("Delete task", role: .destructive) {
                    store.send(.deleteButtonTapped)
                }
            }
        }
        .navigationTitle("Task detail")
        .onAppear {
            store.send(.startHeartbeat)
        }
        .sheet(item: $store.scope(state: \.editSheet, action: \.editSheet)) { store in
            TaskEditSheetView(store: store)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

struct TaskEditSheetView: View {
    @Bindable var store: StoreOf<TaskDetailFeature.EditSheetFeature>
    @State private var showBindingNotes = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Draft") {
                    TextField("Title", text: $store.draftTitle)
                    Toggle(
                        "Completed",
                        isOn: Binding(
                            get: { store.draftIsDone },
                            set: { store.send(.completionToggled($0)) }
                        )
                    )
                }

                Section("Binding comparison") {
                    Toggle("Show notes", isOn: $showBindingNotes)
                    if showBindingNotes {
                        Text("Title uses TCA binding actions; completion uses explicit action dispatch. This note toggle is local @State only.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        store.send(.cancelButtonTapped)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.send(.saveButtonTapped)
                    }
                }
            }
        }
    }
}

struct SettingsSectionView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        Section("Settings feature") {
            Toggle(
                "Show completed tasks",
                isOn: Binding(
                    get: { store.showCompletedTasks },
                    set: { store.send(.showCompletedTasksToggled($0)) }
                )
            )

            Text("This section is intentionally small in Stage 3A to focus on parent/child wiring.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.taskClient = .fixture
        }
    )
}
