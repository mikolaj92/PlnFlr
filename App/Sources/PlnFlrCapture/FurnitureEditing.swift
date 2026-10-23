import Foundation

public struct FurnitureChange: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let before: FurnitureItem?
    public let after: FurnitureItem

    public init(id: UUID, before: FurnitureItem?, after: FurnitureItem) {
        self.id = id
        self.before = before
        self.after = after
    }
}

extension FurnitureItem {
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              size.xMm > 0, size.yMm > 0, size.zMm > 0,
              rotationDegreesAroundPositiveZ.map({ (0..<360).contains($0) }) ?? true,
              provenance.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? true else {
            throw MaterialInputError.invalid
        }
    }
}

extension Workspace.Project.State {
    public var undoableFurnitureChange: FurnitureChange? {
        guard let change = furnitureChanges.last(where: { !undoneFurnitureChangeIDs.contains($0.id) }),
              furniture.first(where: { $0.id == change.after.id }) == change.after else { return nil }
        return change
    }

    public mutating func addFurniture(_ item: FurnitureItem, changeID: UUID) throws {
        guard !furniture.contains(where: { $0.id == item.id }),
              item.floorID != nil, item.provenance != nil,
              item.rotationDegreesAroundPositiveZ != nil else { throw MaterialInputError.invalid }
        try recordFurniture(item, before: nil, changeID: changeID)
    }

    public mutating func moveFurniture(_ id: UUID, to origin: ScenePoint, rotationDegreesAroundPositiveZ: Int, provenance: String, changeID: UUID) throws {
        guard let before = furniture.first(where: { $0.id == id }) else { throw MaterialInputError.invalid }
        var after = before
        after.origin = origin
        after.rotationDegreesAroundPositiveZ = rotationDegreesAroundPositiveZ
        after.provenance = provenance
        try recordFurniture(after, before: before, changeID: changeID)
    }

    public mutating func setFurnitureHidden(_ id: UUID, hidden: Bool, provenance: String, changeID: UUID) throws {
        guard let before = furniture.first(where: { $0.id == id }) else { throw MaterialInputError.invalid }
        var after = before
        after.hidden = hidden
        after.provenance = provenance
        try recordFurniture(after, before: before, changeID: changeID)
    }

    public mutating func undoLastFurnitureChange() {
        guard let change = undoableFurnitureChange,
              let index = furniture.firstIndex(where: { $0.id == change.after.id }) else { return }
        if let before = change.before {
            furniture[index] = before
        } else {
            furniture.remove(at: index)
        }
        undoneFurnitureChangeIDs.append(change.id)
    }

    private mutating func recordFurniture(_ after: FurnitureItem, before: FurnitureItem?, changeID: UUID) throws {
        guard after.provenance?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              !furnitureChanges.contains(where: { $0.id == changeID }) else { throw MaterialInputError.invalid }
        var candidate = self
        if let index = candidate.furniture.firstIndex(where: { $0.id == after.id }) {
            candidate.furniture[index] = after
        } else {
            candidate.furniture.append(after)
        }
        candidate.furnitureChanges.append(FurnitureChange(id: changeID, before: before, after: after))
        try candidate.validateFurniture()
        furniture = candidate.furniture
        furnitureChanges = candidate.furnitureChanges
    }

    func validateFurniture() throws {
        guard Set(furniture.map(\.id)).count == furniture.count,
              Set(furnitureChanges.map(\.id)).count == furnitureChanges.count,
              Set(undoneFurnitureChangeIDs).count == undoneFurnitureChangeIDs.count,
              Set(undoneFurnitureChangeIDs).isSubset(of: Set(furnitureChanges.map(\.id))) else {
            throw MaterialInputError.invalid
        }
        for item in furniture {
            try item.validate()
            if let floorID = item.floorID, !floors.contains(where: { $0.id == floorID }) {
                throw MaterialInputError.invalid
            }
        }
        var restored = furniture
        for change in furnitureChanges.reversed() {
            try change.after.validate()
            if let before = change.before {
                try before.validate()
                guard before.id == change.after.id else { throw MaterialInputError.invalid }
            }
            guard !undoneFurnitureChangeIDs.contains(change.id) else { continue }
            guard let index = restored.firstIndex(where: { $0.id == change.after.id }),
                  restored[index] == change.after else { throw MaterialInputError.invalid }
            if let before = change.before {
                restored[index] = before
            } else {
                restored.remove(at: index)
            }
        }
    }
}
