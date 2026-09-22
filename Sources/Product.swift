import Foundation

struct Product: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String
    let category: String
    let price: Decimal
    let stock: Int
    let thumbnail: URL?

    var formattedPrice: String { price.formatted(.currency(code: "USD")) }
    var categoryTitle: String { category.replacingOccurrences(of: "-", with: " ").capitalized }

    static let samples: [Product] = [
        Product(id: -1, title: "Everyday Backpack", description: "A lightweight bag for work and weekends. Bundled sample product.", category: "accessories", price: Decimal(string: "49.99")!, stock: 12, thumbnail: nil),
        Product(id: -2, title: "Wireless Headphones", description: "Comfortable over-ear headphones. Bundled sample product.", category: "electronics", price: Decimal(string: "89.50")!, stock: 8, thumbnail: nil),
        Product(id: -3, title: "Ceramic Coffee Mug", description: "A simple start to your morning. Bundled sample product.", category: "home", price: Decimal(string: "16.25")!, stock: 20, thumbnail: nil),
        Product(id: -4, title: "Desk Lamp", description: "Adjustable light for your workspace. Bundled sample product.", category: "home", price: Decimal(string: "34.99")!, stock: 0, thumbnail: nil)
    ]
}

struct CartLine: Codable, Identifiable, Equatable {
    let product: Product
    var quantity: Int
    var id: Int { product.id }
    var subtotal: Decimal { product.price * Decimal(quantity) }
}

enum CatalogFilter {
    static func apply(_ products: [Product], query: String, category: String?) -> [Product] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return products.filter {
            (category == nil || $0.category == category) &&
            (term.isEmpty || $0.title.localizedCaseInsensitiveContains(term) ||
             $0.description.localizedCaseInsensitiveContains(term))
        }
    }
}
