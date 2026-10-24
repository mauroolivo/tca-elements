//

import Foundation
import SwiftUI
import ComposableArchitecture

struct ContentView: View {
    let store: StoreOf<CounterFeature>

    private var timestampText: String {
        guard let lastUpdated = store.lastUpdated else {
            return "Not captured yet"
        }

        return lastUpdated.formatted(date: .abbreviated, time: .standard)
    }

    private var isLoadingTasks: Bool {
        if case .loading = store.tasksPhase {
            return true
        }
        return false
    }

    var body: some View {
        content
    }

    private var content: some View {
        NavigationStack {
            Form {
                Section("Counter") {
                    Text("Count: \(store.count)")
                        .font(.title2.monospacedDigit())

                    HStack {
                        Button("-1") {
                            store.send(.decrementButtonTapped)
                        }
                        .buttonStyle(.bordered)

                        Button("Reset") {
                            store.send(.resetButtonTapped)
                        }
                        .buttonStyle(.bordered)

                        Button("+1") {
                            store.send(.incrementButtonTapped)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Section("Dependency preview") {
                    Text("Last captured now: \(timestampText)")

                    Button("Capture now via @Dependency") {
                        store.send(.captureNowButtonTapped)
                    }
                }

                Section("Stage 2: Async tasks") {
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
                        Text("Idle. Tap load to run TaskClient (rapid taps cancel in-flight work).")
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
            .navigationTitle("Stage 2 Effects")
        }
    }
}

#Preview {
    ContentView(
        store: Store(initialState: CounterFeature.State()) {
            CounterFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }
    )
}
