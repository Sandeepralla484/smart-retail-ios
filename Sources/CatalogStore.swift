import CoreData
import Foundation

/// Programmatic Core Data schema keeps this project self-contained.
/// Two versioned JSON snapshots hold the catalog and cart in a SQLite store.
@MainActor
final class CatalogStore {
    private let container: NSPersistentContainer
    private let ready: Task<Void, Error>

    init(inMemory: Bool = false) {
        let entity = NSEntityDescription()
        entity.name = "Snapshot"
        entity.managedObjectClassName = "NSManagedObject"
        let key = NSAttributeDescription()
        key.name = "key"; key.attributeType = .stringAttributeType; key.isOptional = false
        let payload = NSAttributeDescription()
        payload.name = "payload"; payload.attributeType = .binaryDataAttributeType; payload.isOptional = false
        entity.properties = [key, payload]
        entity.uniquenessConstraints = [["key"]]
        let model = NSManagedObjectModel()
        model.entities = [entity]
        let stack = NSPersistentContainer(name: "RetailCache", managedObjectModel: model)
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            stack.persistentStoreDescriptions = [description]
        }
        stack.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container = stack
        ready = Task {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                stack.loadPersistentStores { _, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
        }
    }

    func load<T: Decodable>(_ type: T.Type, key: String) async throws -> T? {
        try await ready.value
        let request = NSFetchRequest<NSManagedObject>(entityName: "Snapshot")
        request.predicate = NSPredicate(format: "key == %@", key)
        request.fetchLimit = 1
        guard let object = try container.viewContext.fetch(request).first,
              let data = object.value(forKey: "payload") as? Data else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    func save<T: Encodable>(_ value: T, key: String) async throws {
        try await ready.value
        let data = try JSONEncoder().encode(value)
        let context = container.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Snapshot")
        request.predicate = NSPredicate(format: "key == %@", key)
        let object = try context.fetch(request).first ?? NSEntityDescription.insertNewObject(forEntityName: "Snapshot", into: context)
        object.setValue(key, forKey: "key")
        object.setValue(data, forKey: "payload")
        do { try context.save() }
        catch { context.rollback(); throw error }
    }
}
