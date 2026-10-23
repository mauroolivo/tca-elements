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
            }
            .navigationTitle("Stage 1C Dependency")
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
