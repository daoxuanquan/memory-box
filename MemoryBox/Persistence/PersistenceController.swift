import CoreData
import Foundation

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MemoryBox", managedObjectModel: Self.makeModel())
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Unable to load Core Data store: \(error.localizedDescription)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            makeMemoryEntity(),
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
                attribute("id", type: .UUIDAttributeType),
                attribute("title", type: .stringAttributeType),
                attribute("date", type: .dateAttributeType),
                attribute("place", type: .stringAttributeType),
                attribute("note", type: .stringAttributeType),
                attribute("kindRawValue", type: .stringAttributeType, isOptional: true),
                attribute("moodRawValue", type: .stringAttributeType),
                attribute("symbolName", type: .stringAttributeType),
                attribute("imagePath", type: .stringAttributeType, isOptional: true),
                attribute("imagePathsRaw", type: .stringAttributeType, isOptional: true),
                attribute("imageData", type: .binaryDataAttributeType, isOptional: true, allowsExternalBinaryDataStorage: true),
                attribute("isFavorite", type: .booleanAttributeType)
            ]
        )
    }

    private static func makeLetterEntity() -> NSEntityDescription {
        entity(
            name: "StoredLetter",
            properties: [
                attribute("id", type: .UUIDAttributeType),
                attribute("title", type: .stringAttributeType),
                attribute("message", type: .stringAttributeType),
                attribute("date", type: .dateAttributeType)
            ]
        )
    }

    private static func makeSpecialDayEntity() -> NSEntityDescription {
        entity(
            name: "StoredSpecialDay",
            properties: [
                attribute("id", type: .UUIDAttributeType),
                attribute("title", type: .stringAttributeType),
                attribute("date", type: .dateAttributeType),
                attribute("symbolName", type: .stringAttributeType)
            ]
        )
    }

    private static func makeSettingsEntity() -> NSEntityDescription {
        entity(
            name: "AppSettings",
            properties: [
                attribute("id", type: .stringAttributeType),
                attribute("startDate", type: .dateAttributeType),
                attribute("startDateIsSet", type: .booleanAttributeType, defaultValue: false),
                attribute("firstName", type: .stringAttributeType),
                attribute("firstAvatar", type: .stringAttributeType),
                attribute("firstColorRawValue", type: .stringAttributeType),
                attribute("firstImagePath", type: .stringAttributeType, isOptional: true),
                attribute("firstAvatarSize", type: .doubleAttributeType, defaultValue: CoupleProfile.defaultAvatarSize),
                attribute("firstImageData", type: .binaryDataAttributeType, isOptional: true, allowsExternalBinaryDataStorage: true),
                attribute("secondName", type: .stringAttributeType),
                attribute("secondAvatar", type: .stringAttributeType),
                attribute("secondColorRawValue", type: .stringAttributeType),
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
        return fetchObjects(entityName: "StoredMemory", sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]).compactMap(makeMemory)
    }

    static func save(memories: [LoveMemory]) {
        migrateUserDefaultsIfNeeded()
        replace(entityName: "StoredMemory") { entity in
            memories.forEach { insert($0, into: entity) }
        }
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
        return settingsObject().flatMap(makeProfile) ?? .empty
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

    private static func makeMemory(from object: NSManagedObject) -> LoveMemory? {
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
        let imagePaths = (decodedImagePaths(from: object.value(forKey: "imagePathsRaw") as? String) + (imagePath.map { [$0] } ?? [])).uniqued()
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
        guard
            let firstName = object.value(forKey: "firstName") as? String,
            let firstAvatar = object.value(forKey: "firstAvatar") as? String,
            let firstColorRawValue = object.value(forKey: "firstColorRawValue") as? String,
            let firstColor = AvatarColor(rawValue: firstColorRawValue),
            let secondName = object.value(forKey: "secondName") as? String,
            let secondAvatar = object.value(forKey: "secondAvatar") as? String,
            let secondColorRawValue = object.value(forKey: "secondColorRawValue") as? String,
            let secondColor = AvatarColor(rawValue: secondColorRawValue)
        else { return nil }

        return CoupleProfile(
            firstName: firstName,
            firstAvatar: firstAvatar,
            firstColor: firstColor,
            firstImagePath: object.value(forKey: "firstImagePath") as? String
                ?? ImageFileStore.save(data: object.value(forKey: "firstImageData") as? Data, category: "profiles", id: "first"),
            firstAvatarSize: object.value(forKey: "firstAvatarSize") as? Double ?? CoupleProfile.defaultAvatarSize,
            secondName: secondName,
            secondAvatar: secondAvatar,
            secondColor: secondColor,
            secondImagePath: object.value(forKey: "secondImagePath") as? String
                ?? ImageFileStore.save(data: object.value(forKey: "secondImageData") as? Data, category: "profiles", id: "second"),
            secondAvatarSize: object.value(forKey: "secondAvatarSize") as? Double ?? CoupleProfile.defaultAvatarSize
        )
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
        settings.setValue(nil, forKey: "firstImageData")
        settings.setValue(profile.secondName, forKey: "secondName")
        settings.setValue(profile.secondAvatar, forKey: "secondAvatar")
        settings.setValue(profile.secondColor.rawValue, forKey: "secondColorRawValue")
        settings.setValue(profile.secondImagePath, forKey: "secondImagePath")
        settings.setValue(profile.secondAvatarSize, forKey: "secondAvatarSize")
        settings.setValue(nil, forKey: "secondImageData")
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
