// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData

extension NSManagedObjectContext {
    func fetch<T: NSManagedObject>(_ entity: T.Type, _ configure: (NSFetchRequest<T>) -> Void = { _ in }) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: entity))
        configure(request)
        return try fetch(request)
    }

    func fetch<T: NSManagedObject, Value>(_ entity: T.Type, sortedBy keyPath: KeyPath<T, Value>, ascending: Bool = true,  _ configure: (NSFetchRequest<T>) -> Void = { _ in }) throws -> [T] {
        try fetch(entity) {
            $0.sortDescriptors = [NSSortDescriptor(keyPath: keyPath, ascending: ascending)]
        }
    }

    func first<T: NSManagedObject>(_ entity: T.Type, _ configure: (NSFetchRequest<T>) -> Void = { _ in }) throws -> T? {
        try fetch(entity) {
            $0.fetchLimit = 1
            configure($0)
        }.first
    }

    func count<T: NSManagedObject>(for entity: T.Type) throws -> Int {
        try count(for: NSFetchRequest<T>(entityName: String(describing: entity)))
    }
}

extension NSPersistentStoreCoordinator {
    func createCopyOfStore(at url: URL) throws {
        guard let sourceStore = persistentStores.first else {
            throw LoggerStore.Error.unknownError // Should never happen
        }

        let backupCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

        var intermediateStoreOptions = sourceStore.options ?? [:]
        intermediateStoreOptions[NSReadOnlyPersistentStoreOption] = true

        let intermediateStore = try backupCoordinator.addPersistentStore(
            ofType: sourceStore.type,
            configurationName: sourceStore.configurationName,
            at: sourceStore.url,
            options: intermediateStoreOptions
        )

        let backupStoreOptions: [AnyHashable: Any] = [
            NSReadOnlyPersistentStoreOption: true,
            // Disable write-ahead logging. Benefit: the entire store will be
            // contained in a single file. No need to handle -wal/-shm files.
            // https://developer.apple.com/library/content/qa/qa1809/_index.html
            NSSQLitePragmasOption: ["journal_mode": "DELETE"],
            // Minimize file size
            NSSQLiteManualVacuumOption: true
        ]

        try backupCoordinator.migratePersistentStore(
            intermediateStore,
            to: url,
            options: backupStoreOptions,
            withType: NSSQLiteStoreType
        )
    }
}

extension NSEntityDescription {
    convenience init<T>(name: String, class: T.Type) where T: NSManagedObject {
        self.init()
        self.name = name
        self.managedObjectClassName = T.self.description()
    }
}

extension NSAttributeDescription {
    convenience init(name: String, type: NSAttributeType, _ configure: (NSAttributeDescription) -> Void = { _ in }) {
        self.init()
        self.name = name
        self.attributeType = type
        configure(self)
    }
}

enum NSRelationshipType {
    case oneToMany
    case oneToOne(isOptional: Bool = false)
}

extension NSRelationshipDescription {
    static func make(name: String,
                     type: NSRelationshipType,
                     deleteRule: NSDeleteRule = .cascadeDeleteRule,
                     entity: NSEntityDescription) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.deleteRule = deleteRule
        relationship.destinationEntity = entity
        switch type {
        case .oneToMany:
            relationship.maxCount = 0
            relationship.minCount = 0
        case .oneToOne(let isOptional):
            relationship.maxCount = 1
            relationship.minCount = isOptional ? 0 : 1
        }
        return relationship
    }
}