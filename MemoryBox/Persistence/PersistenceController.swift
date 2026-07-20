import CoreData
import Foundation
import CloudKit

final class PersistenceController {
    static let shared = PersistenceController()

    static let cloudKitContainerIdentifier = "iCloud.quan.memory.box.MemoryBox"

    let container: NSPersistentContainer
    private(set) var privatePersistentStore: NSPersistentStore?
    private(set) var sharedPersistentStore: NSPersistentStore?

    init(inMemory: Bool = false) {
        let container = NSPersistentCloudKitContainer(name: "MemoryBox", managedObjectModel: Self.makeModel())
        let privateStoreDescription = Self.storeDescription(
            filename: "MemoryBox.sqlite",
            scope: .private,
            inMemory: inMemory
        )
        let sharedStoreDescription = Self.storeDescription(
            filename: "MemoryBox-shared.sqlite",
            scope: .shared,
            inMemory: inMemory
        )
        container.persistentStoreDescriptions = [privateStoreDescription, sharedStoreDescription]

        if inMemory {
            privateStoreDescription.cloudKitContainerOptions = nil
            sharedStoreDescription.cloudKitContainerOptions = nil
        }

        var loadedPrivateStore: NSPersistentStore?
        var loadedSharedStore: NSPersistentStore?
        container.loadPersistentStores { description, error in
            if let error {
                assertionFailure("Unable to load Core Data store: \(error.localizedDescription)")
            }

            guard let storeURL = description.url else { return }
            let store = container.persistentStoreCoordinator.persistentStore(for: storeURL)
            if storeURL == privateStoreDescription.url {
                loadedPrivateStore = store
            } else if storeURL == sharedStoreDescription.url {
                loadedSharedStore = store
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        self.container = container
        privatePersistentStore = loadedPrivateStore
        sharedPersistentStore = loadedSharedStore
        observeCloudKitEvents()
    }

    private static func storeDescription(filename: String, scope: CKDatabase.Scope, inMemory: Bool) -> NSPersistentStoreDescription {
        let storeURL = inMemory
            ? URL(fileURLWithPath: "/dev/null")
            : NSPersistentContainer.defaultDirectoryURL().appendingPathComponent(filename)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        let options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerIdentifier)
        options.databaseScope = scope
        description.cloudKitContainerOptions = options
        return description
    }

    private func observeCloudKitEvents() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { notification in
            guard
                let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
                event.endDate != nil
            else { return }

            if event.succeeded {
                print("MemoryBox CloudKit \(event.type.logName) succeeded")
                if event.type.shouldReloadLocalStore {
                    NotificationCenter.default.post(name: .memoryStoreDidChange, object: nil)
                    if event.type.shouldNotifyRemoteUpdate {
                        Task {
                            await LoveNotificationScheduler.notifyRemoteCoupleUpdate()
                        }
                    }
                }
            } else {
                print("MemoryBox CloudKit \(event.type.logName) failed: \(event.error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let coupleSpace = makeCoupleSpaceEntity()
        let memory = makeMemoryEntity()
        let memoryPhoto = makeMemoryPhotoEntity()
        let letter = makeLetterEntity()
        let specialDay = makeSpecialDayEntity()
        let settings = makeSettingsEntity()
        connectCoupleSpace(
            coupleSpace,
            memory: memory,
            memoryPhoto: memoryPhoto,
            letter: letter,
            specialDay: specialDay,
            settings: settings
        )
        model.entities = [coupleSpace, memory, memoryPhoto, letter, specialDay, settings]
        return model
    }

    private static func makeCoupleSpaceEntity() -> NSEntityDescription {
        entity(
            name: "CoupleSpace",
            properties: [
                attribute("id", type: .stringAttributeType, isOptional: true),
                attribute("createdAt", type: .dateAttributeType, isOptional: true)
            ]
        )
    }

    private static func connectCoupleSpace(
        _ coupleSpace: NSEntityDescription,
        memory: NSEntityDescription,
        memoryPhoto: NSEntityDescription,
        letter: NSEntityDescription,
        specialDay: NSEntityDescription,
        settings: NSEntityDescription
    ) {
        addSpaceRelationship(named: "memories", to: memory, on: coupleSpace)
        addSpaceRelationship(named: "memoryPhotos", to: memoryPhoto, on: coupleSpace)
        addSpaceRelationship(named: "letters", to: letter, on: coupleSpace)
        addSpaceRelationship(named: "specialDays", to: specialDay, on: coupleSpace)
        addSpaceRelationship(named: "settings", to: settings, on: coupleSpace)
    }

    private static func addSpaceRelationship(
        named collectionName: String,
        to entity: NSEntityDescription,
        on coupleSpace: NSEntityDescription
    ) {
        let toMany = NSRelationshipDescription()
        toMany.name = collectionName
        toMany.destinationEntity = entity
        toMany.minCount = 0
        toMany.maxCount = 0
        toMany.deleteRule = .cascadeDeleteRule
        toMany.isOptional = true

        let toOne = NSRelationshipDescription()
        toOne.name = "space"
        toOne.destinationEntity = coupleSpace
        toOne.minCount = 0
        toOne.maxCount = 1
        toOne.deleteRule = .nullifyDeleteRule
        toOne.isOptional = true

        toMany.inverseRelationship = toOne
        toOne.inverseRelationship = toMany
        coupleSpace.properties.append(toMany)
        entity.properties.append(toOne)
    }

    private static func makeMemoryEntity() -> NSEntityDescription {
        entity(
            name: "StoredMemory",
            properties: [
                attribute("id", type: .UUIDAttributeType, isOptional: true),
                attribute("title", type: .stringAttributeType, isOptional: true),
                attribute("date", type: .dateAttributeType, isOptional: true),
                attribute("place", type: .stringAttributeType, isOptional: true),
                attribute("note", type: .stringAttributeType, isOptional: true),
                attribute("kindRawValue", type: .stringAttributeType, isOptional: true),
                attribute("moodRawValue", type: .stringAttributeType, isOptional: true),
                attribute("symbolName", type: .stringAttributeType, isOptional: true),
                attribute("imagePath", type: .stringAttributeType, isOptional: true),
                attribute("imagePathsRaw", type: .stringAttributeType, isOptional: true),
                attribute("imageData", type: .binaryDataAttributeType, isOptional: true, allowsExternalBinaryDataStorage: true),
                attribute("isFavorite", type: .booleanAttributeType, isOptional: true, defaultValue: false)
            ]
        )
    }

    private static func makeMemoryPhotoEntity() -> NSEntityDescription {
        entity(
            name: "StoredMemoryPhoto",
            properties: [
                attribute("id", type: .UUIDAttributeType, isOptional: true),
                attribute("memoryID", type: .UUIDAttributeType, isOptional: true),
                attribute("relativePath", type: .stringAttributeType, isOptional: true),
                attribute("sortIndex", type: .integer64AttributeType, isOptional: true, defaultValue: 0),
                attribute("imageData", type: .binaryDataAttributeType, isOptional: true, allowsExternalBinaryDataStorage: true)
            ]
        )
    }

    private static func makeLetterEntity() -> NSEntityDescription {
        entity(
            name: "StoredLetter",
            properties: [
                attribute("id", type: .UUIDAttributeType, isOptional: true),
                attribute("title", type: .stringAttributeType, isOptional: true),
                attribute("message", type: .stringAttributeType, isOptional: true),
                attribute("date", type: .dateAttributeType, isOptional: true)
            ]
        )
    }

    private static func makeSpecialDayEntity() -> NSEntityDescription {
        entity(
            name: "StoredSpecialDay",
            properties: [
                attribute("id", type: .UUIDAttributeType, isOptional: true),
                attribute("title", type: .stringAttributeType, isOptional: true),
                attribute("date", type: .dateAttributeType, isOptional: true),
                attribute("symbolName", type: .stringAttributeType, isOptional: true)
            ]
        )
    }

    private static func makeSettingsEntity() -> NSEntityDescription {
        entity(
            name: "AppSettings",
            properties: [
                attribute("id", type: .stringAttributeType, isOptional: true),
                attribute("startDate", type: .dateAttributeType, isOptional: true),
                attribute("startDateIsSet", type: .booleanAttributeType, defaultValue: false),
                attribute("firstName", type: .stringAttributeType, isOptional: true),
                attribute("firstAvatar", type: .stringAttributeType, isOptional: true),
                attribute("firstColorRawValue", type: .stringAttributeType, isOptional: true),
                attribute("firstImagePath", type: .stringAttributeType, isOptional: true),
                attribute("firstAvatarSize", type: .doubleAttributeType, defaultValue: CoupleProfile.defaultAvatarSize),
                attribute("firstImageData", type: .binaryDataAttributeType, isOptional: true, allowsExternalBinaryDataStorage: true),
                attribute("secondName", type: .stringAttributeType, isOptional: true),
                attribute("secondAvatar", type: .stringAttributeType, isOptional: true),
                attribute("secondColorRawValue", type: .stringAttributeType, isOptional: true),
                attribute("secondImagePath", type: .stringAttributeType, isOptional: true),
                attribute("secondAvatarSize", type: .doubleAttributeType, defaultValue: CoupleProfile.defaultAvatarSize),
                attribute("secondImageData", type: .binaryDataAttributeType, isOptional: true, allowsExternalBinaryDataStorage: true)
            ]
        )
    }

    private static func entity(name: String, properties: [NSPropertyDescription]) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        entity.properties = properties
        return entity
    }

    private static func attribute(
        _ name: String,
        type: NSAttributeType,
        isOptional: Bool = false,
        allowsExternalBinaryDataStorage: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        attribute.allowsExternalBinaryDataStorage = allowsExternalBinaryDataStorage
        attribute.defaultValue = defaultValue
        return attribute
    }
}

private extension NSPersistentCloudKitContainer.EventType {
    var logName: String {
        switch self {
        case .setup:
            return "setup"
        case .import:
            return "import"
        case .export:
            return "export"
        @unknown default:
            return "event"
        }
    }

    var shouldReloadLocalStore: Bool {
        switch self {
        case .setup, .import:
            return true
        case .export:
            return false
        @unknown default:
            return true
        }
    }

    var shouldNotifyRemoteUpdate: Bool {
        switch self {
        case .import:
            return true
        case .setup, .export:
            return false
        @unknown default:
            return false
        }
    }
}

@MainActor
enum MemoryStore {
    private static let memoriesKey = "memoryLove.memories"
    private static let lettersKey = "memoryLove.letters"
    private static let specialDaysKey = "memoryLove.specialDays"
    private static let profileKey = "memoryLove.profile"
    private static let startDateKey = "memoryLove.startDate"
    private static let didMigrateKey = "memoryLove.didMigrateToCoreData"
    private static let settingsID = "main"
    private static let coupleSpaceID = "main"

    private static let context = PersistenceController.shared.container.viewContext
    private static var cloudKitContainer: NSPersistentCloudKitContainer {
        guard let container = PersistenceController.shared.container as? NSPersistentCloudKitContainer else {
            preconditionFailure("MemoryBox requires NSPersistentCloudKitContainer for sharing")
        }
        return container
    }

    static func loadMemories() -> [LoveMemory] {
        migrateUserDefaultsIfNeeded()
        let store = activeCoupleStore()
        let photosByMemoryID = fetchMemoryPhotos(in: store)
        return fetchObjects(
            entityName: "StoredMemory",
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
            in: store
        )
            .compactMap { makeMemory(from: $0, photosByMemoryID: photosByMemoryID) }
    }

    static func save(memories: [LoveMemory]) {
        migrateUserDefaultsIfNeeded()
        let space = existingOrNewCoupleSpace()
        let targetStore = persistentStore(for: space)
        replace(entityName: "StoredMemory", in: targetStore, shouldSave: false) { entity in
            memories.forEach { insert($0, into: entity, space: space, store: targetStore) }
        }
        replace(entityName: "StoredMemoryPhoto", in: targetStore, shouldSave: false) { entity in
            memories.forEach { insertPhotos(for: $0, into: entity, space: space, store: targetStore) }
        }
        saveContext()
    }

    static func loadLetters() -> [LoveLetter] {
        migrateUserDefaultsIfNeeded()
        return fetchObjects(
            entityName: "StoredLetter",
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
            in: activeCoupleStore()
        )
        .compactMap(makeLetter)
    }

    static func save(letters: [LoveLetter]) {
        migrateUserDefaultsIfNeeded()
        let space = existingOrNewCoupleSpace()
        let targetStore = persistentStore(for: space)
        replace(entityName: "StoredLetter", in: targetStore) { entity in
            letters.forEach { insert($0, into: entity, space: space, store: targetStore) }
        }
    }

    static func loadSpecialDays() -> [SpecialDay] {
        migrateUserDefaultsIfNeeded()
        return fetchObjects(
            entityName: "StoredSpecialDay",
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: true)],
            in: activeCoupleStore()
        )
        .compactMap(makeSpecialDay)
    }

    static func save(specialDays: [SpecialDay]) {
        migrateUserDefaultsIfNeeded()
        let space = existingOrNewCoupleSpace()
        let targetStore = persistentStore(for: space)
        replace(entityName: "StoredSpecialDay", in: targetStore) { entity in
            specialDays.forEach { insert($0, into: entity, space: space, store: targetStore) }
        }
    }

    static func loadProfile() -> CoupleProfile {
        migrateUserDefaultsIfNeeded()
        guard let settings = settingsObject(),
              let profile = makeProfile(from: settings)
        else { return .empty }

        backfillProfileImageDataIfNeeded(in: settings, profile: profile)
        return profile
    }

    static func save(profile: CoupleProfile) {
        migrateUserDefaultsIfNeeded()
        let settings = existingOrNewSettings()
        settings.setValue(existingOrNewCoupleSpace(), forKey: "space")
        update(settings: settings, profile: profile, startDate: currentStartDate(), startDateIsSet: loadHasStartDate())
        saveContext()
    }

    static func loadStartDate() -> Date {
        migrateUserDefaultsIfNeeded()
        return settingsObject()?.value(forKey: "startDate") as? Date ?? Date()
    }

    static func loadHasStartDate() -> Bool {
        migrateUserDefaultsIfNeeded()
        return settingsObject()?.value(forKey: "startDateIsSet") as? Bool ?? false
    }

    static func save(startDate: Date) {
        save(startDate: startDate, isSet: true)
    }

    static func save(startDate: Date, isSet: Bool) {
        migrateUserDefaultsIfNeeded()
        let settings = existingOrNewSettings()
        settings.setValue(existingOrNewCoupleSpace(), forKey: "space")
        update(settings: settings, profile: makeProfile(from: settings) ?? .empty, startDate: startDate, startDateIsSet: isSet)
        saveContext()
    }

    static func prepareCoupleShare(completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        migrateUserDefaultsIfNeeded()
        guard !isUsingSharedCoupleSpace() else {
            completion(
                nil,
                nil,
                NSError(
                    domain: "MemoryBox.CloudSharing",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "This device is already participating in a shared MemoryBox."]
                )
            )
            return
        }

        let space = existingOrNewCoupleSpace()
        backfillSpaceRelationships(space, in: persistentStore(for: space))
        saveContext()

        do {
            try context.obtainPermanentIDs(for: [space])
        } catch {
            completion(nil, nil, error)
            return
        }

        let persistentContainer = cloudKitContainer
        persistentContainer.share([space], to: nil) { _, share, container, error in
            guard let share, let container else {
                completion(nil, nil, error)
                return
            }

            share[CKShare.SystemFieldKey.title] = "MemoryBox của hai người" as CKRecordValue
            share.publicPermission = .none

            guard let store = PersistenceController.shared.privatePersistentStore else {
                completion(share, container, error)
                return
            }

            persistentContainer.persistUpdatedShare(share, in: store) { _, persistError in
                completion(share, container, persistError ?? error)
            }
        }
    }

    static func acceptShareInvitation(_ metadata: CKShare.Metadata) {
        guard let sharedStore = PersistenceController.shared.sharedPersistentStore else { return }
        cloudKitContainer.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
            if let error {
                print("MemoryBox CloudKit share accept failed: \(error.localizedDescription)")
            } else {
                NotificationCenter.default.post(name: .memoryStoreDidChange, object: nil)
            }
        }
    }

    static func isUsingSharedCoupleSpace() -> Bool {
        guard let sharedStore = PersistenceController.shared.sharedPersistentStore else { return false }
        return activeCoupleStore() == sharedStore
    }

    private static func migrateUserDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: didMigrateKey) else { return }

        let hasCoreDataContent = !fetchObjects(entityName: "StoredMemory").isEmpty
            || !fetchObjects(entityName: "StoredLetter").isEmpty
            || !fetchObjects(entityName: "StoredSpecialDay").isEmpty
            || settingsObject() != nil

        guard !hasCoreDataContent else {
            UserDefaults.standard.set(true, forKey: didMigrateKey)
            return
        }

        let memories = loadFromUserDefaults([LoveMemory].self, key: memoriesKey) ?? []
        let letters = loadFromUserDefaults([LoveLetter].self, key: lettersKey) ?? []
        let specialDays = loadFromUserDefaults([SpecialDay].self, key: specialDaysKey) ?? []
        let profile = loadFromUserDefaults(CoupleProfile.self, key: profileKey) ?? .empty
        let storedStartDateValue = UserDefaults.standard.object(forKey: startDateKey) as? Double
        let startDate = storedStartDateValue.map(Date.init(timeIntervalSince1970:)) ?? Date()
        let space = existingOrNewCoupleSpace()
        let targetStore = persistentStore(for: space)

        replace(entityName: "StoredMemory", in: targetStore, shouldSave: false) { object in
            memories.forEach { insert($0, into: object, space: space, store: targetStore) }
        }
        replace(entityName: "StoredMemoryPhoto", in: targetStore, shouldSave: false) { object in
            memories.forEach { insertPhotos(for: $0, into: object, space: space, store: targetStore) }
        }
        replace(entityName: "StoredLetter", in: targetStore, shouldSave: false) { object in
            letters.forEach { insert($0, into: object, space: space, store: targetStore) }
        }
        replace(entityName: "StoredSpecialDay", in: targetStore, shouldSave: false) { object in
            specialDays.forEach { insert($0, into: object, space: space, store: targetStore) }
        }
        let settings = existingOrNewSettings()
        settings.setValue(space, forKey: "space")
        update(settings: settings, profile: profile, startDate: startDate, startDateIsSet: storedStartDateValue != nil)
        saveContext()

        UserDefaults.standard.set(true, forKey: didMigrateKey)
    }

    private static func fetchObjects(
        entityName: String,
        sortDescriptors: [NSSortDescriptor] = [],
        in store: NSPersistentStore? = nil
    ) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.sortDescriptors = sortDescriptors
        if let store {
            request.affectedStores = [store]
        }
        return (try? context.fetch(request)) ?? []
    }

    private static func replace(
        entityName: String,
        in store: NSPersistentStore? = nil,
        shouldSave: Bool = true,
        insertObjects: (NSEntityDescription) -> Void
    ) {
        fetchObjects(entityName: entityName, in: store).forEach(context.delete)
        insertObjects(entityDescription(named: entityName))

        if shouldSave {
            saveContext()
        }
    }

    private static func insert(_ memory: LoveMemory, into entity: NSEntityDescription, space: NSManagedObject, store: NSPersistentStore?) {
        let object = NSManagedObject(entity: entity, insertInto: context)
        assign(object, to: store)
        object.setValue(memory.id, forKey: "id")
        object.setValue(memory.title, forKey: "title")
        object.setValue(memory.date, forKey: "date")
        object.setValue(memory.place, forKey: "place")
        object.setValue(memory.note, forKey: "note")
        object.setValue(memory.kind?.rawValue, forKey: "kindRawValue")
        object.setValue(memory.mood.rawValue, forKey: "moodRawValue")
        object.setValue(memory.symbolName, forKey: "symbolName")
        object.setValue(memory.imagePath, forKey: "imagePath")
        object.setValue(encodedImagePaths(memory.imagePaths), forKey: "imagePathsRaw")
        object.setValue(nil, forKey: "imageData")
        object.setValue(memory.isFavorite, forKey: "isFavorite")
        object.setValue(space, forKey: "space")
    }

    private static func insertPhotos(for memory: LoveMemory, into entity: NSEntityDescription, space: NSManagedObject, store: NSPersistentStore?) {
        for (index, imagePath) in memory.imagePaths.enumerated() {
            let object = NSManagedObject(entity: entity, insertInto: context)
            assign(object, to: store)
            object.setValue(UUID(), forKey: "id")
            object.setValue(memory.id, forKey: "memoryID")
            object.setValue(imagePath, forKey: "relativePath")
            object.setValue(Int64(index), forKey: "sortIndex")
            object.setValue(ImageFileStore.data(for: imagePath), forKey: "imageData")
            object.setValue(space, forKey: "space")
        }
    }

    private static func insert(_ letter: LoveLetter, into entity: NSEntityDescription, space: NSManagedObject, store: NSPersistentStore?) {
        let object = NSManagedObject(entity: entity, insertInto: context)
        assign(object, to: store)
        object.setValue(letter.id, forKey: "id")
        object.setValue(letter.title, forKey: "title")
        object.setValue(letter.message, forKey: "message")
        object.setValue(letter.date, forKey: "date")
        object.setValue(space, forKey: "space")
    }

    private static func insert(_ day: SpecialDay, into entity: NSEntityDescription, space: NSManagedObject, store: NSPersistentStore?) {
        let object = NSManagedObject(entity: entity, insertInto: context)
        assign(object, to: store)
        object.setValue(day.id, forKey: "id")
        object.setValue(day.title, forKey: "title")
        object.setValue(day.date, forKey: "date")
        object.setValue(day.symbolName, forKey: "symbolName")
        object.setValue(space, forKey: "space")
    }

    private static func makeMemory(from object: NSManagedObject, photosByMemoryID: [UUID: [String]]) -> LoveMemory? {
        guard
            let id = object.value(forKey: "id") as? UUID,
            let title = object.value(forKey: "title") as? String,
            let date = object.value(forKey: "date") as? Date,
            let place = object.value(forKey: "place") as? String,
            let note = object.value(forKey: "note") as? String,
            let moodRawValue = object.value(forKey: "moodRawValue") as? String,
            let mood = MemoryMood(rawValue: moodRawValue),
            let symbolName = object.value(forKey: "symbolName") as? String
        else { return nil }

        let kind = (object.value(forKey: "kindRawValue") as? String).flatMap(MemoryKind.init(rawValue:)) ?? .special
        let imagePath = object.value(forKey: "imagePath") as? String
            ?? ImageFileStore.save(data: object.value(forKey: "imageData") as? Data, category: "memories", id: id.uuidString)
        let imagePaths = (
            photosByMemoryID[id] ?? []
            + decodedImagePaths(from: object.value(forKey: "imagePathsRaw") as? String)
            + (imagePath.map { [$0] } ?? [])
        ).uniqued()
        let isFavorite = object.value(forKey: "isFavorite") as? Bool ?? false

        return LoveMemory(
            id: id,
            title: title,
            date: date,
            place: place,
            note: note,
            kind: kind,
            mood: mood,
            symbolName: symbolName,
            imagePaths: imagePaths,
            isFavorite: isFavorite
        )
    }

    private static func fetchMemoryPhotos(in store: NSPersistentStore?) -> [UUID: [String]] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "StoredMemoryPhoto")
        request.sortDescriptors = [
            NSSortDescriptor(key: "memoryID", ascending: true),
            NSSortDescriptor(key: "sortIndex", ascending: true)
        ]
        if let store {
            request.affectedStores = [store]
        }

        let objects = (try? context.fetch(request)) ?? []
        var pathsByMemoryID: [UUID: [String]] = [:]

        for object in objects {
            guard
                let memoryID = object.value(forKey: "memoryID") as? UUID,
                let relativePath = object.value(forKey: "relativePath") as? String
            else { continue }

            if let imageData = object.value(forKey: "imageData") as? Data {
                ImageFileStore.restoreIfNeeded(data: imageData, relativePath: relativePath)
            }
            pathsByMemoryID[memoryID, default: []].append(relativePath)
        }

        return pathsByMemoryID.mapValues { $0.uniqued() }
    }

    private static func makeLetter(from object: NSManagedObject) -> LoveLetter? {
        guard
            let id = object.value(forKey: "id") as? UUID,
            let title = object.value(forKey: "title") as? String,
            let message = object.value(forKey: "message") as? String,
            let date = object.value(forKey: "date") as? Date
        else { return nil }

        return LoveLetter(id: id, title: title, message: message, date: date)
    }

    private static func makeSpecialDay(from object: NSManagedObject) -> SpecialDay? {
        guard
            let id = object.value(forKey: "id") as? UUID,
            let title = object.value(forKey: "title") as? String,
            let date = object.value(forKey: "date") as? Date,
            let symbolName = object.value(forKey: "symbolName") as? String
        else { return nil }

        return SpecialDay(id: id, title: title, date: date, symbolName: symbolName)
    }

    private static func makeProfile(from object: NSManagedObject) -> CoupleProfile? {
        let emptyProfile = CoupleProfile.empty
        let firstColorRawValue = object.value(forKey: "firstColorRawValue") as? String
        let secondColorRawValue = object.value(forKey: "secondColorRawValue") as? String

        return CoupleProfile(
            firstName: object.value(forKey: "firstName") as? String ?? emptyProfile.firstName,
            firstAvatar: object.value(forKey: "firstAvatar") as? String ?? emptyProfile.firstAvatar,
            firstColor: firstColorRawValue.flatMap(AvatarColor.init(rawValue:)) ?? emptyProfile.firstColor,
            firstImagePath: restoredProfileImagePath(
                path: object.value(forKey: "firstImagePath") as? String,
                data: object.value(forKey: "firstImageData") as? Data,
                id: "first"
            ),
            firstAvatarSize: object.value(forKey: "firstAvatarSize") as? Double ?? CoupleProfile.defaultAvatarSize,
            secondName: object.value(forKey: "secondName") as? String ?? emptyProfile.secondName,
            secondAvatar: object.value(forKey: "secondAvatar") as? String ?? emptyProfile.secondAvatar,
            secondColor: secondColorRawValue.flatMap(AvatarColor.init(rawValue:)) ?? emptyProfile.secondColor,
            secondImagePath: restoredProfileImagePath(
                path: object.value(forKey: "secondImagePath") as? String,
                data: object.value(forKey: "secondImageData") as? Data,
                id: "second"
            ),
            secondAvatarSize: object.value(forKey: "secondAvatarSize") as? Double ?? CoupleProfile.defaultAvatarSize
        )
    }

    private static func restoredProfileImagePath(path: String?, data: Data?, id: String) -> String? {
        if let path {
            if let data {
                ImageFileStore.restoreIfNeeded(data: data, relativePath: path)
            }
            return path
        }

        return ImageFileStore.save(data: data, category: "profiles", id: id)
    }

    private static func backfillProfileImageDataIfNeeded(in settings: NSManagedObject, profile: CoupleProfile) {
        var didUpdate = false

        if settings.value(forKey: "firstImageData") == nil,
           let firstImageData = ImageFileStore.data(for: profile.firstImagePath) {
            settings.setValue(firstImageData, forKey: "firstImageData")
            didUpdate = true
        }

        if settings.value(forKey: "secondImageData") == nil,
           let secondImageData = ImageFileStore.data(for: profile.secondImagePath) {
            settings.setValue(secondImageData, forKey: "secondImageData")
            didUpdate = true
        }

        if didUpdate {
            saveContext()
        }
    }

    private static func update(settings: NSManagedObject, profile: CoupleProfile, startDate: Date, startDateIsSet: Bool) {
        settings.setValue(settingsID, forKey: "id")
        settings.setValue(startDate, forKey: "startDate")
        settings.setValue(startDateIsSet, forKey: "startDateIsSet")
        settings.setValue(profile.firstName, forKey: "firstName")
        settings.setValue(profile.firstAvatar, forKey: "firstAvatar")
        settings.setValue(profile.firstColor.rawValue, forKey: "firstColorRawValue")
        settings.setValue(profile.firstImagePath, forKey: "firstImagePath")
        settings.setValue(profile.firstAvatarSize, forKey: "firstAvatarSize")
        settings.setValue(ImageFileStore.data(for: profile.firstImagePath), forKey: "firstImageData")
        settings.setValue(profile.secondName, forKey: "secondName")
        settings.setValue(profile.secondAvatar, forKey: "secondAvatar")
        settings.setValue(profile.secondColor.rawValue, forKey: "secondColorRawValue")
        settings.setValue(profile.secondImagePath, forKey: "secondImagePath")
        settings.setValue(profile.secondAvatarSize, forKey: "secondAvatarSize")
        settings.setValue(ImageFileStore.data(for: profile.secondImagePath), forKey: "secondImageData")
    }

    private static func existingOrNewCoupleSpace() -> NSManagedObject {
        if let space = coupleSpaceObject() {
            return space
        }

        let space = NSManagedObject(entity: entityDescription(named: "CoupleSpace"), insertInto: context)
        assign(space, to: PersistenceController.shared.privatePersistentStore)
        space.setValue(coupleSpaceID, forKey: "id")
        space.setValue(Date(), forKey: "createdAt")
        return space
    }

    private static func coupleSpaceObject() -> NSManagedObject? {
        firstObject(
            entityName: "CoupleSpace",
            predicate: NSPredicate(format: "id == %@", coupleSpaceID),
            preferSharedStore: true
        )
    }

    private static func backfillSpaceRelationships(_ space: NSManagedObject, in store: NSPersistentStore?) {
        ["StoredMemory", "StoredMemoryPhoto", "StoredLetter", "StoredSpecialDay", "AppSettings"]
            .flatMap { fetchObjects(entityName: $0, in: store) }
            .filter { $0.value(forKey: "space") == nil }
            .forEach { $0.setValue(space, forKey: "space") }
    }

    private static func currentStartDate() -> Date {
        settingsObject()?.value(forKey: "startDate") as? Date ?? Date()
    }

    private static func existingOrNewSettings() -> NSManagedObject {
        if let settings = settingsObject() {
            return settings
        }

        let settings = NSManagedObject(entity: entityDescription(named: "AppSettings"), insertInto: context)
        let space = existingOrNewCoupleSpace()
        assign(settings, to: persistentStore(for: space))
        settings.setValue(space, forKey: "space")
        return settings
    }

    private static func settingsObject() -> NSManagedObject? {
        firstObject(
            entityName: "AppSettings",
            predicate: NSPredicate(format: "id == %@", settingsID),
            preferSharedStore: true
        )
    }

    private static func firstObject(
        entityName: String,
        predicate: NSPredicate,
        preferSharedStore: Bool
    ) -> NSManagedObject? {
        let stores = preferredStores(preferSharedStore: preferSharedStore)
        for store in stores {
            if let object = fetchFirstObject(entityName: entityName, predicate: predicate, in: store) {
                return object
            }
        }

        return fetchFirstObject(entityName: entityName, predicate: predicate, in: nil)
    }

    private static func fetchFirstObject(
        entityName: String,
        predicate: NSPredicate,
        in store: NSPersistentStore?
    ) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.fetchLimit = 1
        request.predicate = predicate
        if let store {
            request.affectedStores = [store]
        }
        return try? context.fetch(request).first
    }

    private static func preferredStores(preferSharedStore: Bool) -> [NSPersistentStore] {
        let persistence = PersistenceController.shared
        let preferred = preferSharedStore
            ? [persistence.sharedPersistentStore, persistence.privatePersistentStore]
            : [persistence.privatePersistentStore, persistence.sharedPersistentStore]
        return preferred.compactMap { $0 }
    }

    private static func activeCoupleStore() -> NSPersistentStore? {
        if let sharedStore = PersistenceController.shared.sharedPersistentStore,
           fetchFirstObject(
                entityName: "CoupleSpace",
                predicate: NSPredicate(format: "id == %@", coupleSpaceID),
                in: sharedStore
           ) != nil {
            return sharedStore
        }

        return coupleSpaceObject().flatMap(persistentStore(for:))
    }

    private static func entityDescription(named name: String) -> NSEntityDescription {
        guard let entity = NSEntityDescription.entity(forEntityName: name, in: context) else {
            preconditionFailure("Missing Core Data entity named \(name)")
        }
        return entity
    }

    private static func persistentStore(for object: NSManagedObject) -> NSPersistentStore? {
        object.objectID.persistentStore ?? PersistenceController.shared.privatePersistentStore
    }

    private static func assign(_ object: NSManagedObject, to store: NSPersistentStore?) {
        guard let store else { return }
        context.assign(object, to: store)
    }

    private static func saveContext() {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            assertionFailure("Unable to save Core Data changes: \(error.localizedDescription)")
        }
    }

    private static func encodedImagePaths(_ imagePaths: [String]) -> String? {
        guard !imagePaths.isEmpty,
              let data = try? JSONEncoder().encode(imagePaths)
        else { return nil }

        return String(data: data, encoding: .utf8)
    }

    private static func decodedImagePaths(from rawValue: String?) -> [String] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let paths = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }

        return paths
    }

    private static func loadFromUserDefaults<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
