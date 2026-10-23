//

import SwiftUI
import ComposableArchitecture

@main
struct tca_elementsApp: App {
    let store = Store(initialState: CounterFeature.State()) {
        CounterFeature()
    } withDependencies: {
        $0.taskClient = .failFirstThenFixture
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
