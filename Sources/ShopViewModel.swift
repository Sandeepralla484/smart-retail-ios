import Foundation
import Combine

@MainActor
final class ShopViewModel: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var cart: [CartLine] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var status = "Loading catalog…"
    @Published var message: String?
    @Published var query = ""
    @Published var category: String?
    private let api: ProductServing
    private let store: CatalogStore
    private var cartSaveTask: Task<Void, Never>?
    private var bootstrapped = false
    // Track where products came from; product IDs do not identify the data source.
    private var isShowingBundledSamples = false

    init(api: ProductServing = ProductAPI(), store: CatalogStore) {
        self.api = api; self.store = store
    }

    var filteredProducts: [Product] { CatalogFilter.apply(products, query: query, category: category) }
    var categories: [String] { Set(products.map(\.category)).sorted() }
    var total: Decimal { cart.reduce(Decimal.zero) { $0 + $1.subtotal } }
    var itemCount: Int { cart.reduce(0) { $0 + $1.quantity } }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false; hasLoaded = true }
        if !bootstrapped {
            bootstrapped = true
            do {
                products = try await store.load([Product].self, key: "catalog.v1") ?? []
                cart = try await store.load([CartLine].self, key: "cart.v1") ?? []
                if !products.isEmpty { status = "Saved catalog • refreshing…" }
            } catch { message = "Could not read saved data. \(error.localizedDescription)" }
        }
        do {
            products = try await api.fetchProducts()
            isShowingBundledSamples = false
            status = "Live demo catalog • USD"
            if let category, !categories.contains(category) { self.category = nil }
            reconcileCart()
            do { try await store.save(products, key: "catalog.v1") }
            catch { message = "Catalog loaded, but offline saving failed. \(error.localizedDescription)" }
        } catch {
            if products.isEmpty {
                products = Product.samples
                isShowingBundledSamples = true
                status = "Bundled samples • live catalog unavailable"
            } else {
                status = isShowingBundledSamples
                    ? "Bundled samples • live catalog unavailable"
                    : "Saved catalog • prices and stock may be outdated"
            }
        }
    }

    func add(_ product: Product) {
        guard hasLoaded else { return }
        let current = products.first { $0.id == product.id } ?? product
        guard current.stock > 0 else { return }
        if let index = cart.firstIndex(where: { $0.id == current.id }) {
            guard cart[index].quantity < current.stock else { message = "Available stock limit reached."; return }
            cart[index].quantity += 1
        } else { cart.append(CartLine(product: current, quantity: 1)) }
        persistCart()
    }

    func setQuantity(id: Int, quantity: Int) {
        guard let index = cart.firstIndex(where: { $0.id == id }) else { return }
        if quantity <= 0 { cart.remove(at: index) }
        else { cart[index].quantity = min(quantity, cart[index].product.stock) }
        persistCart()
    }

    private func reconcileCart() {
        let updated = cart.compactMap { line -> CartLine? in
            guard let product = products.first(where: { $0.id == line.id }), product.stock > 0 else { return nil }
            return CartLine(product: product, quantity: min(line.quantity, product.stock))
        }
        if updated != cart {
            cart = updated
            message = "Your cart was updated with current demo prices and availability."
            persistCart()
        }
    }

    private func persistCart() {
        // Serialize writes so an older quantity cannot overwrite a newer one.
        let previous = cartSaveTask
        let snapshot = cart
        cartSaveTask = Task {
            await previous?.value
            do { try await store.save(snapshot, key: "cart.v1") }
            catch { message = "Could not save the cart. \(error.localizedDescription)" }
        }
    }
}
