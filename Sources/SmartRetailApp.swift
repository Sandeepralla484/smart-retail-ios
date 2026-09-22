import SwiftUI

@main
@MainActor
struct SmartRetailApp: App {
    @StateObject private var model = ShopViewModel(store: CatalogStore())
    var body: some Scene {
        WindowGroup {
            TabView {
                CatalogView().tabItem { Label("Shop", systemImage: "bag") }
                CartView().tabItem { Label("Cart", systemImage: "cart") }.badge(model.itemCount)
            }
            .tint(.indigo)
            .environmentObject(model)
            .task { await model.load() }
            .alert("Shopping update", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
                Button("OK") { model.message = nil }
            } message: { Text(model.message ?? "") }
        }
    }
}
