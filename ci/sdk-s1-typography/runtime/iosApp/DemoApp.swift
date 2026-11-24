import SwiftUI
import UIKit
import MadUIKitS1Adopter

@main
struct MadUIKitDemoApp: App {
    var body: some Scene {
        WindowGroup { DemoComposeView() }
    }
}

struct DemoComposeView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        FixtureViewControllerKt.fixtureViewController()
    }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {}
}
