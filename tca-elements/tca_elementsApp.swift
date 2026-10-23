//

import SwiftUI
import ComposableArchitecture

@main
struct tca_elementsApp: App {
    let store = Store(initialState: CounterFeature.State()) {
        CounterFeature()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
