//

import Foundation
import SwiftUI
import ComposableArchitecture

struct ContentView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        content
    }

    private var content: some View {
        NavigationStack {
            Form {
                TasksSectionView(
                    store: store.scope(state: \.tasksFeature, action: \.tasksFeature)
                )

                SettingsSectionView(
                    store: store.scope(state: \.settingsFeature, action: \.settingsFeature)
                )
            }
            .navigationTitle("Stage 3 Composition")
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

                Button("Cancel") {
                    store.send(.cancelLoadTasksButtonTapped)
                }
                .disabled(!isLoadingTasks)
            }

            switch store.tasksPhase {
            case .idle:
                Text("Idle. Tap load to run TaskClient.")
                    .foregroundStyle(.secondary)

            case .loading:
                ProgressView("Loading tasks...")

            case .loaded:
                ForEach(store.tasks) { task in
                    Label(task.title, systemImage: task.isDone ? "checkmark.circle.fill" : "circle")
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
