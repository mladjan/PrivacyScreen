// MARK: - ContentView.swift
// Bridges the UIKit DemoViewController into the SwiftUI app shell.

import SwiftUI

struct ContentView: View {
    var body: some View {
        DemoViewControllerRepresentable()
            .ignoresSafeArea()
    }
}

struct DemoViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DemoViewController {
        DemoViewController()
    }

    func updateUIViewController(_ uiViewController: DemoViewController, context: Context) {}
}
