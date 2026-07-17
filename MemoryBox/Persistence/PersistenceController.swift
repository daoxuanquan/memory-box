import CoreData
import Foundation

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let container = NSPersistentCloudKitContainer(name: "MemoryBox", managedObjectModel: Self.makeModel())
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        storeDescription?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        if inMemory {
            storeDescription?.url = URL(fileURLWithPath: "/dev/null")
            storeDescription?.cloudKitContainerOptions = nil
        }

        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Unable to load Core Data store: \(error.localizedDescription)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        self.container = container
        observeCloudKitEvents()
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
                }
            } else {
                print("MemoryBox CloudKit \(event.type.logName) failed: \(event.error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            makeMemoryEntity(),
            makeMemoryPhotoEntity(),
            makeLetterEntity(),
            makeSpecialDayEntity(),
            makeSettingsEntity()
        ]
        return model
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

    private static let context = PersistenceController.shared.container.viewContext

    static func loadMemories() -> [LoveMemory] {
        migrateUserDefaultsIfNeeded()
        let photosByMemoryID = fetchMemoryPhotos()
        return fetchObjects(entityName: "StoredMemory", sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)])
            .compactMap { makeMemory(from: $0, photosByMemoryID: photosByMemoryID) }
    }

    static func save(memories: [LoveMemory]) {
        migrateUserDefaultsIfNeeded()
        replace(entityName: "StoredMemory", shouldSave: false) { entity in
            memories.forEach { insert($0, into: entity) }
        }
        replace(entityName: "StoredMemoryPhoto", shouldSave: false) { entity in
            memories.forEach { insertPhotos(for: $0, into: entity) }
        }
        saveContext()
    }

    static func loadLetters() -> [LoveLetter] {
        migrateUserDefaultsIfNeeded()
        return fetchObjects(entityName: "StoredLetter", sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]).compactMap(makeLetter)
    }

    static func save(letters: [LoveLetter]) {
        migrateUserDefaultsIfNeeded()
        replace(entityName: "StoredLetter") { entity in
            letters.forEach { insert($0, into: entity) }
        }
    }

    static func loadSpecialDays() -> [SpecialDay] {
        migrateUserDefaultsIfNeeded()
        return fetchObjects(entityName: "StoredSpecialDay", sortDescriptors: [NSSortDescriptor(key: "date", ascending: true)]).compactMap(makeSpecialDay)
    }

    static func save(specialDays: [SpecialDay]) {
        migrateUserDefaultsIfNeeded()
        replace(entityName: "StoredSpecialDay") { entity in
            specialDays.forEach { insert($0, into: entity) }
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
        update(settings: settings, profile: makeProfile(from: settings) ?? .empty, startDate: startDate, startDateIsSet: isSet)
        saveContext()
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

        replace(entityName: "StoredMemory", shouldSave: false) { object in
            memories.forEach { insert($0, into: object) }
        }
        replace(entityName: "StoredMemoryPhoto", shouldSave: false) { object in
            memories.forEach { insertPhotos(for: $0, into: object) }
        }
        replace(entityName: "StoredLetter", shouldSave: false) { object in
            letters.forEach { insert($0, into: object) }
        }
        replace(entityName: "StoredSpecialDay", shouldSave: false) { object in
            specialDays.forEach { insert($0, into: object) }
        }
        update(settings: existingOrNewSettings(), profile: profile, startDate: startDate, startDateIsSet: storedStartDateValue != nil)
        saveContext()

        UserDefaults.standard.set(true, forKey: didMigrateKey)
    }

    private static func fetchObjects(entityName: String, sortDescriptors: [NSSortDescriptor] = []) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.sortDescriptors = sortDescriptors
        return (try? context.fetch(request)) ?? []
    }

    private static func replace(
        entityName: String,
        shouldSave: Bool = true,
        insertObjects: (NSEntityDescription) -> Void
    ) {
        fetchObjects(entityName: entityName).forEach(context.delete)
        insertObjects(entityDescription(named: entityName))

        if shouldSave {
            saveContext()
        }
    }

    private static func insert(_ memory: LoveMemory, into entity: NSEntityDescription) {
        let object = NSManagedObject(entity: entity, insertInto: context)
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
    }

    private static func insertPhotos(for memory: LoveMemory, into entity: NSEntityDescription) {
        for (index, imagePath) in memory.imagePaths.enumerated() {
            let object = NSManagedObject(entity: entity, insertInto: context)
            object.setValue(UUID(), forKey: "id")
            object.setValue(memory.id, forKey: "memoryID")
            object.setValue(imagePath, forKey: "relativePath")
            object.setValue(Int64(index), forKey: "sortIndex")
            object.setValue(ImageFileStore.data(for: imagePath), forKey: "imageData")
        }
    }

    private static func insert(_ letter: LoveLetter, into entity: NSEntityDescription) {
        let object = NSManagedObject(entity: entity, insertInto: context)
        object.setValue(letter.id, forKey: "id")
        object.setValue(letter.title, forKey: "title")
        object.setValue(letter.message, forKey: "message")
        object.setValue(letter.date, forKey: "date")
    }

    private static func insert(_ day: SpecialDay, into entity: NSEntityDescription) {
        let object = NSManagedObject(entity: entity, insertInto: context)
        object.setValue(day.id, forKey: "id")
        object.setValue(day.title, forKey: "title")
        object.setValue(day.date, forKey: "date")
        object.setValue(day.symbolName, forKey: "symbolName")
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

    private static func fetchMemoryPhotos() -> [UUID: [String]] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "StoredMemoryPhoto")
        request.sortDescriptors = [
            NSSortDescriptor(key: "memoryID", ascending: true),
            NSSortDescriptor(key: "sortIndex", ascending: true)
        ]

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

    private static func currentStartDate() -> Date {
        settingsObject()?.value(forKey: "startDate") as? Date ?? Date()
    }

    private static func existingOrNewSettings() -> NSManagedObject {
        settingsObject() ?? NSManagedObject(entity: entityDescription(named: "AppSettings"), insertInto: context)
    }

    private static func settingsObject() -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "AppSettings")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", settingsID)
        return try? context.fetch(request).first
    }

    private static func entityDescription(named name: String) -> NSEntityDescription {
        guard let entity = NSEntityDescription.entity(forEntityName: name, in: context) else {
            preconditionFailure("Missing Core Data entity named \(name)")
        }
        return entity
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
