import SwiftUI

@main
struct SweepYourMacApp: App {
    @StateObject private var viewModelStore = ViewModelStore()
    @StateObject private var diskSpaceManager = DiskSpaceManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModelStore)
                .environmentObject(diskSpaceManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 650)
    }
}
