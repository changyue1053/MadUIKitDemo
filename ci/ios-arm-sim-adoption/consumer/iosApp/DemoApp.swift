import SwiftUI
import UIKit
import MadUIKitDemoShared

@main
struct MadUIKitDemoApp: App {
    var body: some Scene {
        WindowGroup { DemoComposeView() }
    }
}

struct DemoComposeView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        DemoControllerKt.makeDemoViewController()
    }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {}
}
