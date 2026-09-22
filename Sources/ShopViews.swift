import SwiftUI

struct CatalogView: View {
    @EnvironmentObject private var model: ShopViewModel
    private let columns = [GridItem(.adaptive(minimum: 155), spacing: 16)]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Find your everyday favorites.").font(.largeTitle.bold())
                        Text(model.status).font(.footnote).foregroundStyle(.secondary)
                    }
                    Picker("Category", selection: $model.category) {
                        Text("All categories").tag(String?.none)
                        ForEach(model.categories, id: \.self) { category in
                            Text(category.replacingOccurrences(of: "-", with: " ").capitalized).tag(Optional(category))
                        }
                    }.pickerStyle(.menu)
                    if model.isLoading { ProgressView("Refreshing products…") }
                    if model.filteredProducts.isEmpty && !model.isLoading {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass").font(.largeTitle)
                            Text("No products found").font(.headline)
                            Text("Try another search or category.").foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(model.filteredProducts) { product in
                            NavigationLink {
                                ProductDetailView(product: product)
                            } label: { ProductCard(product: product) }
                            .buttonStyle(.plain)
                        }
                    }
                }.padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Smart Retail")
            .searchable(text: $model.query, prompt: "Search products")
            .refreshable { await model.load() }
            .toolbar { Button { Task { await model.load() } } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Refresh catalog").disabled(model.isLoading) }
        }
    }
}

struct ProductImage: View {
    let product: Product
    var body: some View {
        AsyncImage(url: product.thumbnail) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Image(systemName: "shippingbox").font(.system(size: 45)).foregroundStyle(.indigo.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

struct ProductCard: View {
    let product: Product
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProductImage(product: product).frame(height: 130)
            Text(product.categoryTitle).font(.caption).foregroundStyle(.secondary)
            Text(product.title).font(.headline).lineLimit(3)
            Text(product.formattedPrice).font(.title3.bold()).foregroundStyle(.indigo)
            Text(product.stock > 0 ? "In stock" : "Sold out").font(.caption)
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject private var model: ShopViewModel
    @State private var added = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ProductImage(product: product).frame(height: 260)
                Text(product.categoryTitle.uppercased()).font(.caption.bold()).foregroundStyle(.secondary)
                Text(product.title).font(.largeTitle.bold())
                Text(product.formattedPrice).font(.title.bold()).foregroundStyle(.indigo)
                Text(product.description).font(.body)
                Label(product.stock > 0 ? "\(product.stock) available in demo inventory" : "Currently sold out", systemImage: "shippingbox")
                Button {
                    model.add(product); added = true
                } label: { Label("Add to cart", systemImage: "cart.badge.plus").frame(maxWidth: .infinity).padding(8) }
                .buttonStyle(.borderedProminent).disabled(product.stock == 0 || !model.hasLoaded)
                if added { Text("Check the Cart tab to review your items.").font(.footnote).foregroundStyle(.secondary) }
            }.padding()
        }.navigationTitle("Product details").navigationBarTitleDisplayMode(.inline)
    }
}

struct CartView: View {
    @EnvironmentObject private var model: ShopViewModel
    var body: some View {
        NavigationStack {
            List {
                if model.cart.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cart").font(.largeTitle)
                        Text("Your cart is empty").font(.headline)
                        Text("Browse the Shop tab to add products.").foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 32)
                } else {
                    ForEach(model.cart) { line in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(line.product.title).font(.headline)
                            Text(line.subtotal.formatted(.currency(code: "USD"))).foregroundStyle(.indigo)
                            Stepper("Quantity: \(line.quantity)", value: Binding(get: { model.cart.first(where: { $0.id == line.id })?.quantity ?? 0 }, set: { model.setQuantity(id: line.id, quantity: $0) }), in: 0...max(1, line.product.stock))
                        }.padding(.vertical, 8)
                        .swipeActions { Button("Remove", role: .destructive) { model.setQuantity(id: line.id, quantity: 0) } }
                    }
                    Section("Order summary") {
                        HStack { Text("Subtotal").bold(); Spacer(); Text(model.total.formatted(.currency(code: "USD"))).bold() }
                        Text("Portfolio demo. No checkout, payments, tax, or shipping calculation.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }.navigationTitle("Your cart")
        }
    }
}
