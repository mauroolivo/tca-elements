import Foundation
import SwiftUI
import Observation
import TasksKit

struct NativeTasksComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: NativeTasksModel

    init(client: TaskClient) {
        _model = State(initialValue: NativeTasksModel(client: client))
    }

    private var isLoadingTasks: Bool {
        if case .loading = model.phase {
            return true
        }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Native tasks controls") {
                    HStack {
                        Button("Load tasks") {
                            model.loadTasks()
                        }
                        .buttonStyle(.bordered)

                        Button("Cancel") {
                            model.cancelLoad()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!isLoadingTasks)

                        Button("Add") {
                            model.addTask()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoadingTasks)
                    }

                    switch model.phase {
                    case .idle:
                        Text("Idle. Tap load to run explicit async dependency.")
                            .foregroundStyle(.secondary)

                    case .loading:
                        ProgressView("Loading tasks...")

                    case .loaded:
                        ForEach(model.tasks) { task in
                            HStack {
                                Text(task.title)
                                Spacer()

                                Button {
                                    model.toggleCompletion(for: task.id)
                                } label: {
                                    Image(systemName: task.isDone ? "checkmark.circle" : "circle")
                                }
                                .buttonStyle(.plain)

                                Button(role: .destructive) {
                                    model.deleteTask(id: task.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
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

                Section("Comparison notes") {
                    Text("This view uses @Observable + @State ownership, explicit Task cancellation, and direct dependency injection via an initializer.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Native SwiftUI Lab")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

@MainActor
@Observable
final class NativeTasksModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    var tasks: [TaskItem] = []
    var phase: Phase = .idle

    private let client: TaskClient
    private var inFlightLoadTask: Task<Void, Never>?
    private var latestRequestID = 0
    private var nextLocalTaskID = 10_000

    init(client: TaskClient) {
        self.client = client
    }

    func loadTasks() {
        latestRequestID += 1
        let requestID = latestRequestID

        inFlightLoadTask?.cancel()
        phase = .loading

        inFlightLoadTask = Task { [client] in
            do {
                let loadedTasks = try await client.loadTasks()
                guard !Task.isCancelled else { return }
                applyLoadedTasks(loadedTasks, requestID: requestID)
            } catch {
                guard !Task.isCancelled else { return }
                applyLoadFailure(error, requestID: requestID)
            }
        }
    }

    func cancelLoad() {
        inFlightLoadTask?.cancel()
        inFlightLoadTask = nil
        phase = tasks.isEmpty ? .idle : .loaded
    }

    func addTask() {
        tasks.append(TaskItem(id: nextLocalTaskID, title: "Native task \(nextLocalTaskID)", isDone: false))
        nextLocalTaskID += 1
        phase = .loaded
    }

    func toggleCompletion(for id: TaskItem.ID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            return
        }
        tasks[index].isDone.toggle()
    }

    func deleteTask(id: TaskItem.ID) {
        tasks.removeAll { $0.id == id }
        if tasks.isEmpty {
            phase = .idle
        }
    }

    private func applyLoadedTasks(_ loadedTasks: [TaskItem], requestID: Int) {
        guard requestID == latestRequestID else {
            return
        }
        for loadedTask in loadedTasks {
            if let index = tasks.firstIndex(where: { $0.id == loadedTask.id }) {
                tasks[index] = loadedTask
            } else {
                tasks.append(loadedTask)
            }
        }
        phase = tasks.isEmpty ? .idle : .loaded
    }

    private func applyLoadFailure(_ error: Error, requestID: Int) {
        guard requestID == latestRequestID else {
            return
        }
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        phase = .failed(message)
    }
}
