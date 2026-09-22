import Foundation

protocol ProductServing {
    func fetchProducts() async throws -> [Product]
}

struct ProductAPI: ProductServing {
    private struct Response: Decodable { let products: [Product] }
    let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func fetchProducts() async throws -> [Product] {
        // This deliberately small portfolio catalog loads all products in one call.
        let url = URL(string: "https://dummyjson.com/products?limit=0&select=id,title,description,category,price,stock,thumbnail")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Response.self, from: data).products
    }
}
