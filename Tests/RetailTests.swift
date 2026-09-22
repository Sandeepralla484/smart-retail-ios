import XCTest
@testable import SmartRetail

final class RetailTests: XCTestCase {
    func testSearchCombinesCategoryAndTrimmedCaseInsensitiveQuery() {
        XCTAssertEqual(CatalogFilter.apply(Product.samples, query: "  MUG  ", category: "home").map(\.id), [-3])
        XCTAssertTrue(CatalogFilter.apply(Product.samples, query: "MUG", category: "electronics").isEmpty)
    }

    func testMoneyUsesDecimalArithmetic() {
        let product = Product(id: 1, title: "Test", description: "", category: "test", price: Decimal(string: "0.10")!, stock: 10, thumbnail: nil)
        XCTAssertEqual(CartLine(product: product, quantity: 3).subtotal, Decimal(string: "0.30")!)
    }

    @MainActor
    func testCoreDataRoundTripReplacesSnapshot() async throws {
        let store = CatalogStore(inMemory: true)
        try await store.save(Product.samples, key: "catalog.v1")
        let original = try await store.load([Product].self, key: "catalog.v1")
        XCTAssertEqual(original, Product.samples)
        try await store.save([Product.samples[0]], key: "catalog.v1")
        let replaced = try await store.load([Product].self, key: "catalog.v1")
        XCTAssertEqual(replaced?.count, 1)
    }

    @MainActor
    func testCartEnforcesStockAndSupportsRemoval() async {
        let model = ShopViewModel(api: StubAPI(products: Product.samples), store: CatalogStore(inMemory: true))
        await model.load()
        model.add(Product.samples[3])
        XCTAssertTrue(model.cart.isEmpty)
        for _ in 0..<20 { model.add(Product.samples[0]) }
        XCTAssertEqual(model.cart.first?.quantity, 12)
        model.setQuantity(id: -1, quantity: 0)
        XCTAssertTrue(model.cart.isEmpty)
    }

    @MainActor
    func testNetworkFailureUsesCachedProducts() async throws {
        let store = CatalogStore(inMemory: true)
        try await store.save([Product.samples[0]], key: "catalog.v1")
        let model = ShopViewModel(api: FailingAPI(), store: store)
        await model.load()
        XCTAssertEqual(model.products, [Product.samples[0]])
        XCTAssertTrue(model.status.contains("Saved catalog"))
    }
}

private struct StubAPI: ProductServing {
    let products: [Product]
    func fetchProducts() async throws -> [Product] { products }
}
private struct FailingAPI: ProductServing {
    func fetchProducts() async throws -> [Product] { throw URLError(.notConnectedToInternet) }
}
