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

    /// A private-queue context for reading off the main thread. Each read gets its own
    /// context so concurrent loads never touch the same context from different threads.
    func newReadContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
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
                    Task { @MainActor in
                        MemoryStore.reconcileAfterCloudSync()
                        NotificationCenter.default.post(name: .memoryStoreDidChange, object: nil)
                        if event.type.shouldNotifyRemoteUpdate {
                            await MemoryStore.notifyAfterRemoteImportIfNeeded()
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
                attribute("date", type: .dateAttributeType, isOptional: true),
                attribute("senderRoleRawValue", type: .stringAttributeType, isOptional: true),
                attribute("imageData", type: .binaryDataAttributeType, isOptional: true, allowsExternalBinaryDataStorage: true),
                attribute("moodRawValue", type: .stringAttributeType, isOptional: true),
                attribute("reactionRawValue", type: .stringAttributeType, isOptional: true),
                attribute("replyToID", type: .UUIDAttributeType, isOptional: true),
                attribute("isRead", type: .booleanAttributeType, defaultValue: false),
                attribute("readAt", type: .dateAttributeType, isOptional: true),
                attribute("isFavorite", type: .booleanAttributeType, defaultValue: false),
                attribute("schemaVersion", type: .integer64AttributeType, defaultValue: 0)
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
                attribute("symbolName", type: .stringAttributeType, isOptional: true),
                attribute("recurrenceRawValue", type: .stringAttributeType, isOptional: true),
                attribute("reminderOffsetsRaw", type: .stringAttributeType, isOptional: true)
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
                attribute("secondImageData", type: .binaryDataAttributeType, isOptional: true, allowsExternalBinaryDataStorage: true),
                attribute("appIconRawValue", type: .stringAttributeType, isOptional: true),
                attribute("customAppIconData", type: .binaryDataAttributeType, isOptional: true, allowsExternalBinaryDataStorage: true),
                attribute("myRoleRawValue", type: .stringAttributeType, isOptional: true),
                attribute("activeDataSourceRawValue", type: .stringAttributeType, isOptional: true),
                attribute("spaceMembershipRawValue", type: .stringAttributeType, isOptional: true),
                attribute("onboardingCompleted", type: .booleanAttributeType, defaultValue: false)
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

enum MemoryStore {
    private static let memoriesKey = "memoryLove.memories"
    private static let lettersKey = "memoryLove.letters"
    private static let specialDaysKey = "memoryLove.specialDays"
    private static let profileKey = "memoryLove.profile"
    private static let startDateKey = "memoryLove.startDate"
    private static let didMigrateKey = "memoryLove.didMigrateToCoreData"
    private static let settingsID = "main"
    private static let coupleSpaceID = "main"

    /// Main-thread context used for writes. Reads pass an explicit background context instead.
    private static var context: NSManagedObjectContext {
        PersistenceController.shared.container.viewContext
    }
    private static var cloudKitContainer: NSPersistentCloudKitContainer {
        guard let container = PersistenceController.shared.container as? NSPersistentCloudKitContainer else {
            preconditionFailure("MemoryBox requires NSPersistentCloudKitContainer for sharing")
        }
        return container
    }

    static func loadMemories() async -> [LoveMemory] {
        await ensureMigrated()
        let ctx = PersistenceController.shared.newReadContext()
        return await ctx.perform {
            let store = activeCoupleStore(ctx)
            let photosByMemoryID = fetchMemoryPhotos(in: store, ctx)
            return fetchObjects(
                entityName: "StoredMemory",
                sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
                in: store,
                ctx
            )
                .compactMap { makeMemory(from: $0, photosByMemoryID: photosByMemoryID) }
        }
    }

    static func save(memories: [LoveMemory]) {
        migrateUserDefaultsIfNeeded()
        let space = existingOrNewCoupleSpace()
        let targetStore = persistentStore(for: space) ?? PersistenceController.shared.privatePersistentStore
        upsert(memories: memories, space: space, store: targetStore)
        upsertPhotos(for: memories, space: space, store: targetStore)
        saveContext()
    }

    static func loadLoveMessages() async -> [LoveMessage] {
        await ensureMigrated()
        await MainActor.run {
            migrateMisplacedMessagesToActiveStore()
            saveContext()
        }
        let ctx = PersistenceController.shared.newReadContext()
        let objects = await ctx.perform {
            purgeLegacyLetters(in: ctx)
            return fetchObjects(
                entityName: "StoredLetter",
                sortDescriptors: [NSSortDescriptor(key: "date", ascending: true)],
                in: activeCoupleStore(ctx),
                ctx
            )
        }
        return objects.compactMap(makeLoveMessage)
    }

    static func currentSenderRole() -> MessageSenderRole {
        loadMyRole() ?? (isUsingSharedCoupleSpace() ? .second : .first)
    }

    static func loadMyRole() -> MessageSenderRole? {
        migrateUserDefaultsIfNeeded()
        return (activeSettingsObject()?.value(forKey: "myRoleRawValue") as? String)
            .flatMap(MessageSenderRole.init(rawValue:))
    }

    static func save(myRole: MessageSenderRole) {
        migrateUserDefaultsIfNeeded()
        let settings = existingOrNewSettings()
        settings.setValue(existingOrNewCoupleSpace(), forKey: "space")
        settings.setValue(myRole.rawValue, forKey: "myRoleRawValue")
        saveContext()
    }

    static func loadSpaceMembership() -> SpaceMembership {
        migrateUserDefaultsIfNeeded()
        let rawValue = activeSettingsObject()?.value(forKey: "spaceMembershipRawValue") as? String
        if let membership = rawValue.flatMap(SpaceMembership.init(rawValue:)) {
            return membership
        }

        return isUsingSharedCoupleSpace() ? .participant : .ownLocal
    }

    static func save(spaceMembership: SpaceMembership) {
        migrateUserDefaultsIfNeeded()
        let settings = existingOrNewSettings()
        settings.setValue(existingOrNewCoupleSpace(), forKey: "space")
        settings.setValue(spaceMembership.rawValue, forKey: "spaceMembershipRawValue")
        saveContext()
    }

    static func save(activeDataSource: ActiveDataSource) {
        migrateUserDefaultsIfNeeded()
        let settings = existingOrNewSettings()
        settings.setValue(existingOrNewCoupleSpace(), forKey: "space")
        settings.setValue(activeDataSource.rawValue, forKey: "activeDataSourceRawValue")
        saveContext()
    }

    static func hasLocalCoupleData() -> Bool {
        migrateUserDefaultsIfNeeded()
        let privateStore = PersistenceController.shared.privatePersistentStore
        guard privateStore != nil else { return false }

        if !fetchObjects(entityName: "StoredMemory", in: privateStore).isEmpty { return true }
        if !fetchObjects(entityName: "StoredLetter", in: privateStore).isEmpty { return true }
        if !fetchObjects(entityName: "StoredSpecialDay", in: privateStore).isEmpty { return true }
        let settings = fetchFirstObject(
            entityName: "AppSettings",
            predicate: NSPredicate(format: "id == %@", settingsID),
            in: privateStore
        )
        if settings?.value(forKey: "startDateIsSet") as? Bool == true { return true }
        let profile = settings.flatMap(makeProfile) ?? .empty
        return !profile.firstName.trimmed.isEmpty || !profile.secondName.trimmed.isEmpty
    }

    static func hasPrivateCoupleDataOnly() -> Bool {
        hasLocalCoupleData()
    }

    static func hasPrivateCoupleSpaceOnly() -> Bool {
        guard let privateStore = PersistenceController.shared.privatePersistentStore else { return false }
        return coupleSpaceObject(in: privateStore) != nil
    }

    static func ensurePrivateCoupleSpace() {
        migrateUserDefaultsIfNeeded()
        let space = existingOrNewCoupleSpace()
        backfillSpaceRelationships(space, in: PersistenceController.shared.privatePersistentStore)
        saveContext()
    }

    static func loadOnboardingCompleted() -> Bool {
        migrateUserDefaultsIfNeeded()
        let local = UserDefaults.standard.bool(forKey: OnboardingStore.completedKey)
        let synced = activeSettingsObject()?.value(forKey: "onboardingCompleted") as? Bool ?? false
        return local || synced
    }

    static func save(onboardingCompleted: Bool) {
        migrateUserDefaultsIfNeeded()
        UserDefaults.standard.set(onboardingCompleted, forKey: OnboardingStore.completedKey)
        let settings = existingOrNewSettings()
        settings.setValue(existingOrNewCoupleSpace(), forKey: "space")
        settings.setValue(onboardingCompleted, forKey: "onboardingCompleted")
        saveContext()
    }

    static func unreadIncomingMessages(from messages: [LoveMessage]) -> [LoveMessage] {
        let myRole = currentSenderRole()
        return messages
            .filter { $0.senderRole != myRole && !$0.isRead }
            .sorted { $0.sentAt < $1.sentAt }
    }

    @discardableResult
    static func sendLoveMessage(_ draft: LoveMessageDraft) -> LoveMessage? {
        migrateUserDefaultsIfNeeded()
        purgeLegacyLetters()
        migrateMisplacedMessagesToActiveStore()

        let trimmedMessage = draft.message.trimmed
        guard !trimmedMessage.isEmpty || draft.imageData != nil else { return nil }

        guard let space = activeCoupleSpaceObject() else {
            MemoryLog.share("sendLoveMessage: chưa có CoupleSpace trong store đang dùng")
            return nil
        }

        guard let targetStore = activeCoupleStore() ?? persistentStore(for: space) else {
            MemoryLog.share("sendLoveMessage: không xác định được persistent store")
            return nil
        }

        let entity = entityDescription(named: "StoredLetter")
        let object = NSManagedObject(entity: entity, insertInto: context)
        assign(object, to: targetStore)

        let message = LoveMessage(
            message: trimmedMessage,
            senderRole: currentSenderRole(),
            imageData: draft.imageData,
            mood: draft.mood,
            replyToID: draft.replyToID
        )
        object.setValue(message.id, forKey: "id")
        apply(message, to: object, space: space)
        saveContext()
        NotificationCenter.default.post(name: .memoryStoreDidChange, object: nil)
        return message
    }

    static func markLoveMessageRead(id: UUID) {
        guard let object = letterObject(id: id) else { return }
        object.setValue(true, forKey: "isRead")
        object.setValue(Date(), forKey: "readAt")
        saveContext()
    }

    static func setLoveMessageReaction(id: UUID, reaction: MessageReaction?) {
        guard let object = letterObject(id: id) else { return }
        object.setValue(reaction?.rawValue, forKey: "reactionRawValue")
        saveContext()
    }

    static func toggleLoveMessageFavorite(id: UUID) {
        guard let object = letterObject(id: id) else { return }
        let current = object.value(forKey: "isFavorite") as? Bool ?? false
        object.setValue(!current, forKey: "isFavorite")
        saveContext()
    }

    static func updateLoveMessage(id: UUID, message: String, mood: MessageMood, imageData: Data?) {
        guard let object = letterObject(id: id),
              let existing = makeLoveMessage(from: object),
              existing.senderRole == currentSenderRole()
        else { return }

        let trimmedMessage = message.trimmed
        guard !trimmedMessage.isEmpty || imageData != nil else { return }

        var updated = existing
        updated.message = trimmedMessage
        updated.mood = mood
        updated.imageData = imageData
        apply(updated, to: object, space: object.value(forKey: "space") as? NSManagedObject ?? existingOrNewCoupleSpace())
        saveContext()
    }

    static func deleteLoveMessage(id: UUID) {
        guard let object = letterObject(id: id),
              let existing = makeLoveMessage(from: object),
              existing.senderRole == currentSenderRole()
        else { return }

        context.delete(object)
        saveContext()
    }

    static func notifyAfterRemoteImportIfNeeded() async {
        await notifyUnreadIncomingIfNeeded(alsoNotifyGenericUpdate: true)
    }

    /// Gọi 1 lần khi mở app — chỉ báo nếu có tin nhắn đến chưa đọc.
    static func notifyUnreadOnLaunchIfNeeded() async {
        await notifyUnreadIncomingIfNeeded(alsoNotifyGenericUpdate: false)
    }

    private static var sessionNotifiedUnreadMessageIDs: Set<UUID> = []

    private static func notifyUnreadIncomingIfNeeded(alsoNotifyGenericUpdate: Bool) async {
        let unread = unreadIncomingMessages(from: await loadLoveMessages())
        let fresh = unread.filter { !sessionNotifiedUnreadMessageIDs.contains($0.id) }

        if !fresh.isEmpty {
            fresh.forEach { sessionNotifiedUnreadMessageIDs.insert($0.id) }
            await LoveNotificationScheduler.notifyNewLoveMessage()
        } else if alsoNotifyGenericUpdate {
            await LoveNotificationScheduler.notifyRemoteCoupleUpdate()
        }
    }

    static func loadSpecialDays() async -> [SpecialDay] {
        await ensureMigrated()
        let ctx = PersistenceController.shared.newReadContext()
        let objects = await ctx.perform {
            fetchObjects(
                entityName: "StoredSpecialDay",
                sortDescriptors: [NSSortDescriptor(key: "date", ascending: true)],
                in: activeCoupleStore(ctx),
                ctx
            )
        }
        return objects.compactMap(makeSpecialDay)
    }

    static func save(specialDays: [SpecialDay]) {
        migrateUserDefaultsIfNeeded()
        let space = existingOrNewCoupleSpace()
        let targetStore = persistentStore(for: space) ?? PersistenceController.shared.privatePersistentStore
        upsert(specialDays: specialDays, space: space, store: targetStore)
        saveContext()
    }

    static func loadProfile() async -> CoupleProfile {
        await ensureMigrated()
        let ctx = PersistenceController.shared.newReadContext()
        return await ctx.perform {
            guard let settings = activeSettingsObject(ctx),
                  let profile = makeProfile(from: settings)
            else { return .empty }

            backfillProfileImageDataIfNeeded(in: settings, profile: profile, ctx: ctx)
            return profile
        }
    }

    static func save(profile: CoupleProfile) {
        migrateUserDefaultsIfNeeded()
        let settings = existingOrNewSettings()
        settings.setValue(existingOrNewCoupleSpace(), forKey: "space")
        update(settings: settings, profile: profile, startDate: currentStartDate(), startDateIsSet: loadHasStartDate())
        saveContext()
    }

    static func loadAppIconChoice() -> AppIconChoice {
        migrateUserDefaultsIfNeeded()
        let raw = activeSettingsObject()?.value(forKey: "appIconRawValue") as? String
        return raw.flatMap(AppIconChoice.init(rawValue:)) ?? .dragonBulliesPig
    }

    static func save(appIcon choice: AppIconChoice) {
        migrateUserDefaultsIfNeeded()
        let settings = existingOrNewSettings()
        settings.setValue(existingOrNewCoupleSpace(), forKey: "space")
        settings.setValue(choice.rawValue, forKey: "appIconRawValue")
        saveContext()
    }

    static func loadStartDate() -> Date {
        migrateUserDefaultsIfNeeded()
        return activeSettingsObject()?.value(forKey: "startDate") as? Date ?? Date()
    }

    static func loadHasStartDate() -> Bool {
        migrateUserDefaultsIfNeeded()
        return activeSettingsObject()?.value(forKey: "startDateIsSet") as? Bool ?? false
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

    private static var isPreparingCoupleShare = false

    static func prepareCoupleShare(completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        let finish: (CKShare?, CKContainer?, Error?) -> Void = { share, container, error in
            isPreparingCoupleShare = false
            MemoryLog.share("prepareCoupleShare finish: share=\(share?.url?.absoluteString ?? "nil"), publicPermission=\(share?.publicPermission.rawValue ?? -1), container=\(container?.containerIdentifier ?? "nil"), error=\(error?.localizedDescription ?? "nil")")
            DispatchQueue.main.async { completion(share, container, error) }
        }

        guard !isPreparingCoupleShare else {
            MemoryLog.share("prepareCoupleShare: đang chạy -> bỏ qua")
            return
        }
        isPreparingCoupleShare = true

        MemoryLog.share("prepareCoupleShare: bắt đầu")
        migrateUserDefaultsIfNeeded()
        guard !isUsingSharedCoupleSpace() else {
            MemoryLog.share("prepareCoupleShare: thiết bị đang dùng shared space -> chặn")
            finish(
                nil,
                nil,
                NSError(
                    domain: "MemoryBox.CloudSharing",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Thiết bị này đã tham gia không gian MemoryBox được chia sẻ."]
                )
            )
            return
        }

        let space = existingOrNewCoupleSpace()
        backfillSpaceRelationships(
            space,
            in: persistentStore(for: space) ?? PersistenceController.shared.privatePersistentStore
        )
        saveContext()
        MemoryLog.share("prepareCoupleShare: space objectID=\(space.objectID), isTemporary=\(space.objectID.isTemporaryID)")

        do {
            try context.obtainPermanentIDs(for: [space])
            MemoryLog.share("prepareCoupleShare: obtainPermanentIDs OK, objectID=\(space.objectID)")
        } catch {
            MemoryLog.share("prepareCoupleShare: obtainPermanentIDs lỗi: \(error.localizedDescription)")
            finish(nil, nil, error)
            return
        }

        let persistentContainer = cloudKitContainer
        let ckContainer = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)
        let spaceObjectID = space.objectID

        let configureAndPersist: (CKShare) -> Void = { share in
            share[CKShare.SystemFieldKey.title] = "MemoryBox của hai người" as CKRecordValue

            if share.publicPermission == .readWrite, share.url != nil {
                MemoryLog.share("prepareCoupleShare: share đã có link công khai -> trả về ngay")
                finish(share, ckContainer, nil)
                return
            }

            share.publicPermission = .readWrite

            guard let store = PersistenceController.shared.privatePersistentStore else {
                MemoryLog.share("prepareCoupleShare: thiếu privatePersistentStore")
                finish(share, ckContainer, nil)
                return
            }

            MemoryLog.share("prepareCoupleShare: persistUpdatedShare publicPermission=\(share.publicPermission.rawValue)")
            DispatchQueue.main.async {
                persistentContainer.persistUpdatedShare(share, in: store) { persistedShare, persistError in
                    if let persistError {
                        MemoryLog.share("prepareCoupleShare: persistUpdatedShare error=\(persistError.localizedDescription)")
                        finish(share, ckContainer, persistError)
                        return
                    }

                    do {
                        let latestShare = try persistentContainer.fetchShares(matching: [spaceObjectID])[spaceObjectID]
                            ?? persistedShare
                            ?? share
                        MemoryLog.share("prepareCoupleShare: share sau persist url=\(latestShare.url?.absoluteString ?? "nil")")
                        finish(latestShare, ckContainer, nil)
                    } catch {
                        MemoryLog.share("prepareCoupleShare: refetch share lỗi: \(error.localizedDescription)")
                        finish(persistedShare ?? share, ckContainer, error)
                    }
                }
            }
        }

        do {
            let existingShares = try persistentContainer.fetchShares(matching: [spaceObjectID])
            if let existingShare = existingShares[spaceObjectID] {
                MemoryLog.share("prepareCoupleShare: đã có share sẵn -> cập nhật quyền link công khai")
                configureAndPersist(existingShare)
                return
            }
            MemoryLog.share("prepareCoupleShare: chưa có share -> tạo mới")
        } catch {
            MemoryLog.share("prepareCoupleShare: fetchShares lỗi: \(error.localizedDescription)")
            finish(nil, nil, error)
            return
        }

        MemoryLog.share("prepareCoupleShare: gọi container.share(...)")
        persistentContainer.share([space], to: nil) { _, share, _, error in
            MemoryLog.share("prepareCoupleShare: share() callback share=\(share != nil), error=\(error?.localizedDescription ?? "nil")")
            guard let share else {
                finish(nil, nil, error)
                return
            }
            configureAndPersist(share)
        }
    }

    static func fetchCoupleShareURL(share: CKShare, container: CKContainer) async -> URL? {
        if let url = share.url {
            return url
        }

        do {
            let record = try await container.privateCloudDatabase.record(for: share.recordID)
            if let refreshedShare = record as? CKShare, let url = refreshedShare.url {
                MemoryLog.share("fetchCoupleShareURL: lấy được url=\(url.absoluteString)")
                return url
            }
        } catch {
            MemoryLog.share("fetchCoupleShareURL lỗi: \(error.localizedDescription)")
        }

        return nil
    }

    static func acceptShareInvitation(_ metadata: CKShare.Metadata) {
        MemoryLog.share("acceptShareInvitation: nhận metadata (owner=\(metadata.ownerIdentity.userRecordID?.recordName ?? "nil"))")
        guard let sharedStore = PersistenceController.shared.sharedPersistentStore else {
            MemoryLog.share("acceptShareInvitation: thiếu sharedPersistentStore -> bỏ qua")
            NotificationCenter.default.post(
                name: .coupleShareDidAccept,
                object: nil,
                userInfo: ["success": false, "error": "Không tìm thấy shared store trên thiết bị này."]
            )
            return
        }
        cloudKitContainer.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
            DispatchQueue.main.async {
                if let error {
                    MemoryLog.share("acceptShareInvitation: THẤT BẠI: \(error.localizedDescription)")
                    NotificationCenter.default.post(
                        name: .coupleShareDidAccept,
                        object: nil,
                        userInfo: ["success": false, "error": error.localizedDescription]
                    )
                } else {
                    MemoryLog.share("acceptShareInvitation: THÀNH CÔNG")
                    MemoryStore.reconcileAfterCloudSync()
                    NotificationCenter.default.post(
                        name: .coupleShareDidAccept,
                        object: nil,
                        userInfo: ["success": true]
                    )
                    NotificationCenter.default.post(name: .memoryStoreDidChange, object: nil)
                }
            }
        }
    }

    static func isUsingSharedCoupleSpace() -> Bool {
        guard let sharedStore = PersistenceController.shared.sharedPersistentStore else { return false }
        return activeCoupleStore() == sharedStore
    }

    static func isUsingSharedCoupleSpaceHeuristic() -> Bool {
        guard let sharedStore = PersistenceController.shared.sharedPersistentStore else { return false }
        return coupleSpaceObject(in: sharedStore) != nil
    }

    static func hasSharedCoupleSpace() -> Bool {
        guard let sharedStore = PersistenceController.shared.sharedPersistentStore else { return false }
        return coupleSpaceObject(in: sharedStore) != nil
    }

    static func hasSharedCoupleSpaceOnly() -> Bool {
        hasSharedCoupleSpace()
    }

    /// Call after CloudKit setup/import so reinstall restores names, start date, and content
    /// instead of keeping empty local placeholders that raced ahead of the sync.
    static func reconcileAfterCloudSync() {
        purgeLegacyLetters()
        deduplicateCoupleSpaces()
        deduplicateSettings()
        migrateMisplacedMessagesToActiveStore()
        saveContext()
    }

    /// Migration writes on the main-thread viewContext, so hop to the main actor before reads.
    private static func ensureMigrated() async {
        if UserDefaults.standard.bool(forKey: didMigrateKey) { return }
        await MainActor.run { migrateUserDefaultsIfNeeded() }
    }

    private static func migrateUserDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: didMigrateKey) else { return }

        let hasCoreDataContent = !fetchObjects(entityName: "StoredMemory").isEmpty
            || !fetchObjects(entityName: "StoredLetter").isEmpty
            || !fetchObjects(entityName: "StoredSpecialDay").isEmpty
            || anySettingsObject() != nil

        guard !hasCoreDataContent else {
            UserDefaults.standard.set(true, forKey: didMigrateKey)
            return
        }

        let memories = loadFromUserDefaults([LoveMemory].self, key: memoriesKey) ?? []
        let specialDays = loadFromUserDefaults([SpecialDay].self, key: specialDaysKey) ?? []
        let profile = loadFromUserDefaults(CoupleProfile.self, key: profileKey)
        let storedStartDateValue = UserDefaults.standard.object(forKey: startDateKey) as? Double

        // On reinstall UserDefaults is empty. Do NOT create empty Core Data records here —
        // that would export blank profile/startDate to CloudKit and wipe or conflict with
        // the real iCloud data that is still importing.
        let hasUserDefaultsContent = !memories.isEmpty
            || !specialDays.isEmpty
            || profile != nil
            || storedStartDateValue != nil

        guard hasUserDefaultsContent else {
            UserDefaults.standard.set(true, forKey: didMigrateKey)
            return
        }

        let startDate = storedStartDateValue.map(Date.init(timeIntervalSince1970:)) ?? Date()
        let space = existingOrNewCoupleSpace()
        let targetStore = persistentStore(for: space) ?? PersistenceController.shared.privatePersistentStore

        upsert(memories: memories, space: space, store: targetStore)
        upsertPhotos(for: memories, space: space, store: targetStore)
        upsert(specialDays: specialDays, space: space, store: targetStore)
        let settings = existingOrNewSettings()
        settings.setValue(space, forKey: "space")
        update(
            settings: settings,
            profile: profile ?? .empty,
            startDate: startDate,
            startDateIsSet: storedStartDateValue != nil
        )
        saveContext()

        UserDefaults.standard.set(true, forKey: didMigrateKey)
    }

    private static func deduplicateCoupleSpaces() {
        let spaces = fetchObjects(
            entityName: "CoupleSpace",
            predicate: NSPredicate(format: "id == %@", coupleSpaceID)
        )
        guard spaces.count > 1 else { return }

        let keeper: NSManagedObject
        if let sharedStore = PersistenceController.shared.sharedPersistentStore,
           let sharedSpace = spaces.first(where: { $0.objectID.persistentStore == sharedStore }) {
            keeper = sharedSpace
        } else {
            keeper = spaces.max(by: { spaceContentScore($0) < spaceContentScore($1) }) ?? spaces[0]
        }

        for space in spaces where space.objectID != keeper.objectID {
            if samePersistentStore(space, keeper) {
                reassignChildren(from: space, to: keeper)
                context.delete(space)
            } else if spaceContentScore(space) == 0 {
                context.delete(space)
            }
        }
    }

    private static func migrateMisplacedMessagesToActiveStore() {
        guard let activeStore = activeCoupleStore(),
              let activeSpace = activeCoupleSpaceObject() else { return }

        let misplacedStores = [PersistenceController.shared.privatePersistentStore, PersistenceController.shared.sharedPersistentStore]
            .compactMap { $0 }
            .filter { $0 != activeStore }

        guard !misplacedStores.isEmpty else { return }

        let existingIDs = Set(
            fetchObjects(entityName: "StoredLetter", in: activeStore)
                .compactMap { $0.value(forKey: "id") as? UUID }
        )

        var didMigrate = false
        for store in misplacedStores {
            for object in fetchObjects(entityName: "StoredLetter", in: store) {
                guard let message = makeLoveMessage(from: object) else {
                    context.delete(object)
                    didMigrate = true
                    continue
                }

                if !existingIDs.contains(message.id) {
                    let entity = entityDescription(named: "StoredLetter")
                    let copy = NSManagedObject(entity: entity, insertInto: context)
                    assign(copy, to: activeStore)
                    copy.setValue(message.id, forKey: "id")
                    apply(message, to: copy, space: activeSpace)
                }

                context.delete(object)
                didMigrate = true
            }
        }

        if didMigrate {
            MemoryLog.share("migrateMisplacedMessagesToActiveStore: đã chuyển tin nhắn sang store đang dùng")
        }
    }

    private static func samePersistentStore(_ lhs: NSManagedObject, _ rhs: NSManagedObject) -> Bool {
        let left = lhs.objectID.persistentStore
        let right = rhs.objectID.persistentStore
        return left == nil || right == nil || left == right
    }

    private static func deduplicateSettings() {
        let allSettings = fetchObjects(
            entityName: "AppSettings",
            predicate: NSPredicate(format: "id == %@", settingsID)
        )
        guard allSettings.count > 1 else { return }

        let keeper = allSettings.max(by: { settingsContentScore($0) < settingsContentScore($1) }) ?? allSettings[0]
        for settings in allSettings where settings.objectID != keeper.objectID {
            context.delete(settings)
        }

        if keeper.value(forKey: "space") == nil {
            keeper.setValue(activeCoupleSpaceObject() ?? coupleSpaceObject(in: activeCoupleStore()), forKey: "space")
        }
    }

    private static func spaceContentScore(_ space: NSManagedObject) -> Int {
        let relatedCounts = ["memories", "memoryPhotos", "letters", "specialDays", "settings"]
            .compactMap { space.value(forKey: $0) as? NSSet }
            .map(\.count)
        let relatedScore = relatedCounts.reduce(0, +) * 10
        let ageBonus: Int = {
            guard let createdAt = space.value(forKey: "createdAt") as? Date else { return 0 }
            return max(0, Int(-createdAt.timeIntervalSinceNow / 60))
        }()
        return relatedScore + ageBonus
    }

    private static func settingsContentScore(_ settings: NSManagedObject) -> Int {
        var score = 0
        if settings.value(forKey: "startDateIsSet") as? Bool == true { score += 100 }
        if let name = settings.value(forKey: "firstName") as? String, !name.trimmed.isEmpty { score += 40 }
        if let name = settings.value(forKey: "secondName") as? String, !name.trimmed.isEmpty { score += 40 }
        if settings.value(forKey: "firstImageData") != nil { score += 20 }
        if settings.value(forKey: "secondImageData") != nil { score += 20 }
        if settings.value(forKey: "startDate") != nil { score += 10 }
        return score
    }

    private static func reassignChildren(from oldSpace: NSManagedObject, to newSpace: NSManagedObject) {
        ["memories", "memoryPhotos", "letters", "specialDays", "settings"].forEach { key in
            guard let children = (oldSpace.value(forKey: key) as? NSSet)?.allObjects as? [NSManagedObject] else { return }
            children.forEach { $0.setValue(newSpace, forKey: "space") }
        }
    }

    private static func fetchObjects(
        entityName: String,
        predicate: NSPredicate,
        sortDescriptors: [NSSortDescriptor] = [],
        in store: NSPersistentStore? = nil,
        _ ctx: NSManagedObjectContext = context
    ) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        if let store {
            request.affectedStores = [store]
        }
        return (try? ctx.fetch(request)) ?? []
    }

    private static func fetchObjects(
        entityName: String,
        sortDescriptors: [NSSortDescriptor] = [],
        in store: NSPersistentStore? = nil,
        _ ctx: NSManagedObjectContext = context
    ) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.sortDescriptors = sortDescriptors
        if let store {
            request.affectedStores = [store]
        }
        return (try? ctx.fetch(request)) ?? []
    }

    private static func upsert(memories: [LoveMemory], space: NSManagedObject, store: NSPersistentStore?) {
        var existingByID = objectsByUUID(entityName: "StoredMemory", in: store)
        let entity = entityDescription(named: "StoredMemory")

        for memory in memories {
            let object = existingByID.removeValue(forKey: memory.id) ?? {
                let created = NSManagedObject(entity: entity, insertInto: context)
                assign(created, to: store)
                created.setValue(memory.id, forKey: "id")
                return created
            }()
            apply(memory, to: object, space: space)
        }

        existingByID.values.forEach(context.delete)
    }

    private static func upsertPhotos(for memories: [LoveMemory], space: NSManagedObject, store: NSPersistentStore?) {
        let existingPhotos = fetchObjects(entityName: "StoredMemoryPhoto", in: store)
        var photosByKey: [PhotoKey: NSManagedObject] = [:]
        for photo in existingPhotos {
            guard
                let memoryID = photo.value(forKey: "memoryID") as? UUID,
                let relativePath = photo.value(forKey: "relativePath") as? String
            else {
                context.delete(photo)
                continue
            }
            let key = PhotoKey(memoryID: memoryID, relativePath: relativePath)
            if let duplicate = photosByKey[key] {
                if duplicate.value(forKey: "imageData") == nil, photo.value(forKey: "imageData") != nil {
                    context.delete(duplicate)
                    photosByKey[key] = photo
                } else {
                    context.delete(photo)
                }
            } else {
                photosByKey[key] = photo
            }
        }

        let entity = entityDescription(named: "StoredMemoryPhoto")

        for memory in memories {
            for (index, imagePath) in memory.imagePaths.enumerated() {
                let key = PhotoKey(memoryID: memory.id, relativePath: imagePath)

                if let existing = photosByKey.removeValue(forKey: key) {
                    existing.setValue(Int64(index), forKey: "sortIndex")
                    existing.setValue(space, forKey: "space")
                    if existing.value(forKey: "imageData") == nil {
                        existing.setValue(ImageFileStore.data(for: imagePath), forKey: "imageData")
                    }
                } else {
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
        }

        photosByKey.values.forEach(context.delete)
    }

    private static func purgeLegacyLetters(in ctx: NSManagedObjectContext = context) {
        let objects = fetchObjects(entityName: "StoredLetter", in: nil, ctx)
        var didDelete = false
        for object in objects {
            let version = object.value(forKey: "schemaVersion") as? Int64 ?? 0
            if version < Int64(LoveMessage.currentSchemaVersion) {
                ctx.delete(object)
                didDelete = true
            }
        }
        if didDelete, ctx.hasChanges {
            try? ctx.save()
        }
    }

    private static func letterObject(id: UUID) -> NSManagedObject? {
        fetchObjects(
            entityName: "StoredLetter",
            predicate: NSPredicate(format: "id == %@", id as CVarArg),
            in: activeCoupleStore()
        ).first
    }

    private static func upsert(specialDays: [SpecialDay], space: NSManagedObject, store: NSPersistentStore?) {
        var existingByID = objectsByUUID(entityName: "StoredSpecialDay", in: store)
        let entity = entityDescription(named: "StoredSpecialDay")

        for day in specialDays {
            let object = existingByID.removeValue(forKey: day.id) ?? {
                let created = NSManagedObject(entity: entity, insertInto: context)
                assign(created, to: store)
                created.setValue(day.id, forKey: "id")
                return created
            }()
            apply(day, to: object, space: space)
        }

        existingByID.values.forEach(context.delete)
    }

    private static func objectsByUUID(entityName: String, in store: NSPersistentStore?) -> [UUID: NSManagedObject] {
        var result: [UUID: NSManagedObject] = [:]
        for object in fetchObjects(entityName: entityName, in: store) {
            guard let id = object.value(forKey: "id") as? UUID else {
                context.delete(object)
                continue
            }
            if let duplicate = result[id] {
                context.delete(duplicate)
            }
            result[id] = object
        }
        return result
    }

    private static func apply(_ memory: LoveMemory, to object: NSManagedObject, space: NSManagedObject) {
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

    private static func apply(_ message: LoveMessage, to object: NSManagedObject, space: NSManagedObject) {
        object.setValue(nil, forKey: "title")
        object.setValue(message.message, forKey: "message")
        object.setValue(message.sentAt, forKey: "date")
        object.setValue(message.senderRole.rawValue, forKey: "senderRoleRawValue")
        object.setValue(message.imageData, forKey: "imageData")
        object.setValue(message.mood.rawValue, forKey: "moodRawValue")
        object.setValue(message.reaction?.rawValue, forKey: "reactionRawValue")
        object.setValue(message.replyToID, forKey: "replyToID")
        object.setValue(message.isRead, forKey: "isRead")
        object.setValue(message.readAt, forKey: "readAt")
        object.setValue(message.isFavorite, forKey: "isFavorite")
        object.setValue(Int64(message.schemaVersion), forKey: "schemaVersion")
        object.setValue(space, forKey: "space")
    }

    private static func apply(_ day: SpecialDay, to object: NSManagedObject, space: NSManagedObject) {
        object.setValue(day.title, forKey: "title")
        object.setValue(day.date, forKey: "date")
        object.setValue(day.symbolName, forKey: "symbolName")
        object.setValue(day.recurrence.rawValue, forKey: "recurrenceRawValue")
        object.setValue(encodedReminderOffsets(day.reminderOffsets), forKey: "reminderOffsetsRaw")
        object.setValue(space, forKey: "space")
    }

    private struct PhotoKey: Hashable {
        let memoryID: UUID
        let relativePath: String
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

    private static func fetchMemoryPhotos(in store: NSPersistentStore?, _ ctx: NSManagedObjectContext = context) -> [UUID: [String]] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "StoredMemoryPhoto")
        request.sortDescriptors = [
            NSSortDescriptor(key: "memoryID", ascending: true),
            NSSortDescriptor(key: "sortIndex", ascending: true)
        ]
        if let store {
            request.affectedStores = [store]
        }

        let objects = (try? ctx.fetch(request)) ?? []
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

    private static func makeLoveMessage(from object: NSManagedObject) -> LoveMessage? {
        let schemaVersion = Int(object.value(forKey: "schemaVersion") as? Int64 ?? 0)
        guard schemaVersion >= LoveMessage.currentSchemaVersion else { return nil }

        guard
            let id = object.value(forKey: "id") as? UUID,
            let message = object.value(forKey: "message") as? String,
            let sentAt = object.value(forKey: "date") as? Date,
            let senderRoleRawValue = object.value(forKey: "senderRoleRawValue") as? String,
            let senderRole = MessageSenderRole(rawValue: senderRoleRawValue),
            let moodRawValue = object.value(forKey: "moodRawValue") as? String,
            let mood = MessageMood(rawValue: moodRawValue)
        else { return nil }

        let reaction = (object.value(forKey: "reactionRawValue") as? String).flatMap(MessageReaction.init(rawValue:))
        let isRead = object.value(forKey: "isRead") as? Bool ?? false
        let isFavorite = object.value(forKey: "isFavorite") as? Bool ?? false

        return LoveMessage(
            id: id,
            message: message,
            sentAt: sentAt,
            senderRole: senderRole,
            imageData: object.value(forKey: "imageData") as? Data,
            mood: mood,
            reaction: reaction,
            replyToID: object.value(forKey: "replyToID") as? UUID,
            isRead: isRead,
            readAt: object.value(forKey: "readAt") as? Date,
            isFavorite: isFavorite,
            schemaVersion: schemaVersion
        )
    }

    private static func makeSpecialDay(from object: NSManagedObject) -> SpecialDay? {
        guard
            let id = object.value(forKey: "id") as? UUID,
            let title = object.value(forKey: "title") as? String,
            let date = object.value(forKey: "date") as? Date,
            let symbolName = object.value(forKey: "symbolName") as? String
        else { return nil }

        let recurrence = (object.value(forKey: "recurrenceRawValue") as? String)
            .flatMap(SpecialDayRecurrence.init(rawValue:)) ?? .yearly
        let reminderOffsets = decodedReminderOffsets(from: object.value(forKey: "reminderOffsetsRaw") as? String)

        return SpecialDay(
            id: id,
            title: title,
            date: date,
            symbolName: symbolName,
            recurrence: recurrence,
            reminderOffsets: reminderOffsets
        )
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

    private static func backfillProfileImageDataIfNeeded(in settings: NSManagedObject, profile: CoupleProfile, ctx: NSManagedObjectContext = context) {
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

        if didUpdate, ctx.hasChanges {
            try? ctx.save()
        }
    }

    private static func update(settings: NSManagedObject, profile: CoupleProfile, startDate: Date, startDateIsSet: Bool) {
        settings.setValue(settingsID, forKey: "id")
        settings.setValue(startDate, forKey: "startDate")
        settings.setValue(startDateIsSet, forKey: "startDateIsSet")
        settings.setValue(profile.firstName, forKey: "firstName")
        settings.setValue(profile.firstAvatar, forKey: "firstAvatar")
        settings.setValue(profile.firstColor.rawValue, forKey: "firstColorRawValue")
        settings.setValue(profile.firstAvatarSize, forKey: "firstAvatarSize")
        syncProfileImage(
            settings: settings,
            pathKey: "firstImagePath",
            dataKey: "firstImageData",
            newPath: profile.firstImagePath
        )
        settings.setValue(profile.secondName, forKey: "secondName")
        settings.setValue(profile.secondAvatar, forKey: "secondAvatar")
        settings.setValue(profile.secondColor.rawValue, forKey: "secondColorRawValue")
        settings.setValue(profile.secondAvatarSize, forKey: "secondAvatarSize")
        syncProfileImage(
            settings: settings,
            pathKey: "secondImagePath",
            dataKey: "secondImageData",
            newPath: profile.secondImagePath
        )
    }

    private static func syncProfileImage(
        settings: NSManagedObject,
        pathKey: String,
        dataKey: String,
        newPath: String?
    ) {
        let oldPath = settings.value(forKey: pathKey) as? String
        settings.setValue(newPath, forKey: pathKey)

        if oldPath != newPath {
            ImageFileStore.delete(oldPath)
            settings.setValue(ImageFileStore.data(for: newPath), forKey: dataKey)
        } else if newPath != nil, settings.value(forKey: dataKey) == nil {
            settings.setValue(ImageFileStore.data(for: newPath), forKey: dataKey)
        } else if newPath == nil {
            settings.setValue(nil, forKey: dataKey)
        }
    }

    private static func activeCoupleSpaceObject(_ ctx: NSManagedObjectContext = context) -> NSManagedObject? {
        coupleSpaceObject(in: activeCoupleStore(ctx), ctx)
    }

    private static func existingOrNewCoupleSpace() -> NSManagedObject {
        if let space = activeCoupleSpaceObject() {
            return space
        }

        let targetStore = activeCoupleStore() ?? PersistenceController.shared.privatePersistentStore
        let space = NSManagedObject(entity: entityDescription(named: "CoupleSpace"), insertInto: context)
        assign(space, to: targetStore)
        space.setValue(coupleSpaceID, forKey: "id")
        space.setValue(Date(), forKey: "createdAt")
        return space
    }

    private static func coupleSpaceObject(
        in store: NSPersistentStore? = nil,
        _ ctx: NSManagedObjectContext = context
    ) -> NSManagedObject? {
        let spaces = fetchObjects(
            entityName: "CoupleSpace",
            predicate: NSPredicate(format: "id == %@", coupleSpaceID),
            in: store,
            ctx
        )
        guard !spaces.isEmpty else { return nil }
        if spaces.count == 1 { return spaces[0] }
        return spaces.max(by: { spaceContentScore($0) < spaceContentScore($1) })
    }

    private static func backfillSpaceRelationships(_ space: NSManagedObject, in store: NSPersistentStore?) {
        ["StoredMemory", "StoredMemoryPhoto", "StoredLetter", "StoredSpecialDay", "AppSettings"]
            .flatMap { fetchObjects(entityName: $0, in: store) }
            .filter { $0.value(forKey: "space") == nil }
            .forEach { $0.setValue(space, forKey: "space") }
    }

    private static func currentStartDate() -> Date {
        activeSettingsObject()?.value(forKey: "startDate") as? Date ?? Date()
    }

    private static func existingOrNewSettings() -> NSManagedObject {
        let targetStore = activeCoupleStore() ?? PersistenceController.shared.privatePersistentStore
        if let settings = fetchFirstObject(
            entityName: "AppSettings",
            predicate: NSPredicate(format: "id == %@", settingsID),
            in: targetStore
        ) {
            return settings
        }

        let space = existingOrNewCoupleSpace()
        let settings = NSManagedObject(entity: entityDescription(named: "AppSettings"), insertInto: context)
        assign(settings, to: targetStore)
        settings.setValue(settingsID, forKey: "id")
        settings.setValue(space, forKey: "space")
        return settings
    }

    private static func activeSettingsObject(_ ctx: NSManagedObjectContext = context) -> NSManagedObject? {
        let inActiveStore = fetchObjects(
            entityName: "AppSettings",
            predicate: NSPredicate(format: "id == %@", settingsID),
            in: activeCoupleStore(ctx),
            ctx
        )
        if let best = inActiveStore.max(by: { settingsContentScore($0) < settingsContentScore($1) }) {
            return best
        }

        if OnboardingStore.importSessionActive || OnboardingStore.activeDataSource == .sharedInvite {
            return nil
        }

        let all = fetchObjects(
            entityName: "AppSettings",
            predicate: NSPredicate(format: "id == %@", settingsID),
            ctx
        )
        return all.max(by: { settingsContentScore($0) < settingsContentScore($1) })
    }

    private static func anySettingsObject() -> NSManagedObject? {
        let all = fetchObjects(
            entityName: "AppSettings",
            predicate: NSPredicate(format: "id == %@", settingsID)
        )
        return all.max(by: { settingsContentScore($0) < settingsContentScore($1) })
    }

    private static func fetchFirstObject(
        entityName: String,
        predicate: NSPredicate,
        in store: NSPersistentStore?,
        _ ctx: NSManagedObjectContext = context
    ) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.fetchLimit = 1
        request.predicate = predicate
        if let store {
            request.affectedStores = [store]
        }
        return try? ctx.fetch(request).first
    }

    private static func activeCoupleStore(_ ctx: NSManagedObjectContext = context) -> NSPersistentStore? {
        let routedStore = CoupleDataRoutingService.activeStore()
        if OnboardingStore.importSessionActive || OnboardingStore.activeDataSource == .sharedInvite {
            return routedStore
        }
        if OnboardingStore.activeDataSource == .ownPrivate {
            return routedStore
        }

        if let sharedStore = PersistenceController.shared.sharedPersistentStore,
           fetchFirstObject(
                entityName: "CoupleSpace",
                predicate: NSPredicate(format: "id == %@", coupleSpaceID),
                in: sharedStore,
                ctx
           ) != nil {
            return sharedStore
        }

        if let privateStore = PersistenceController.shared.privatePersistentStore,
           fetchFirstObject(
                entityName: "CoupleSpace",
                predicate: NSPredicate(format: "id == %@", coupleSpaceID),
                in: privateStore,
                ctx
           ) != nil {
            return privateStore
        }

        return PersistenceController.shared.privatePersistentStore
    }

    private static func entityDescription(named name: String) -> NSEntityDescription {
        guard let entity = NSEntityDescription.entity(forEntityName: name, in: context) else {
            preconditionFailure("Missing Core Data entity named \(name)")
        }
        return entity
    }

    private static func persistentStore(for object: NSManagedObject) -> NSPersistentStore? {
        object.objectID.persistentStore
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
            let nsError = error as NSError
            print("Unable to save Core Data changes: \(nsError), userInfo: \(nsError.userInfo)")
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

    private static func encodedReminderOffsets(_ offsets: [Int]) -> String? {
        guard let data = try? JSONEncoder().encode(offsets) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decodedReminderOffsets(from rawValue: String?) -> [Int] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let offsets = try? JSONDecoder().decode([Int].self, from: data)
        else { return SpecialDay.defaultReminderOffsets }

        return offsets
    }

    private static func loadFromUserDefaults<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
