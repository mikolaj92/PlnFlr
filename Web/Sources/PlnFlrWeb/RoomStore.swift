import Foundation

public let openUserID = "local"

public struct SavedRoom: Sendable {
    public var id: String
    public var userID: String
    public var name: String
    public var form: [String: String]
    public var createdAt: String
    public var updatedAt: String
}

public final class RoomStore: @unchecked Sendable {
    private let path: URL
    private let lock = NSLock()

    public init(path: URL) {
        self.path = path
    }

    public static func live() -> RoomStore {
        let cwd = FileManager.default.currentDirectoryPath
        let candidates = [
            cwd + "/data/rooms.json",
            cwd + "/../data/rooms.json",
        ]
        let file = candidates.first { FileManager.default.fileExists(atPath: $0) }
            ?? (cwd + "/data/rooms.json")
        return RoomStore(path: URL(fileURLWithPath: file))
    }

    public func list(userID: String) -> [SavedRoom] {
        lock.lock()
        defer { lock.unlock() }
        seedLocked(userID: userID)
        return loadLocked().filter { $0.userID == userID }
    }

    public func get(_ id: String, userID: String) -> SavedRoom? {
        list(userID: userID).first { $0.id == id }
    }

    @discardableResult
    public func create(userID: String, name: String, form: [String: String] = [:]) -> SavedRoom {
        lock.lock()
        defer { lock.unlock() }
        var payload = defaultForm()
        payload.merge(form) { _, new in new }
        let stamp = now()
        let room = SavedRoom(
            id: String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)).lowercased(),
            userID: userID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nextNameLocked(userID: userID)
                : name.trimmingCharacters(in: .whitespacesAndNewlines),
            form: payload,
            createdAt: stamp,
            updatedAt: stamp
        )
        var rooms = loadLocked()
        rooms.append(room)
        saveLocked(rooms)
        return room
    }

    @discardableResult
    public func updateForm(_ id: String, userID: String, form: [String: String]) -> SavedRoom? {
        lock.lock()
        defer { lock.unlock() }
        var rooms = loadLocked()
        guard let index = rooms.firstIndex(where: { $0.id == id && $0.userID == userID }) else {
            return nil
        }
        var merged = defaultForm()
        merged.merge(rooms[index].form) { _, new in new }
        merged.merge(form) { _, new in new }
        rooms[index].form = merged
        rooms[index].updatedAt = now()
        saveLocked(rooms)
        return rooms[index]
    }

    public func ensureDefault(userID: String) -> SavedRoom {
        list(userID: userID)[0]
    }

    private func seedLocked(userID: String) {
        var rooms = loadLocked()
        if rooms.contains(where: { $0.userID == userID }) { return }
        let stamp = now()
        rooms.append(
            SavedRoom(
                id: String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)).lowercased(),
                userID: userID,
                name: "Pokój 1",
                form: defaultForm(),
                createdAt: stamp,
                updatedAt: stamp
            )
        )
        saveLocked(rooms)
    }

    private func nextNameLocked(userID: String) -> String {
        let existing = loadLocked().filter { $0.userID == userID }
        return "Pokój \(existing.count + 1)"
    }

    private func loadLocked() -> [SavedRoom] {
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }
        guard let data = try? Data(contentsOf: path),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = raw["rooms"] as? [[String: Any]]
        else { return [] }
        return items.compactMap(Self.parse)
    }

    private func saveLocked(_ rooms: [SavedRoom]) {
        try? FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let payload: [String: Any] = [
            "rooms": rooms.map {
                [
                    "id": $0.id,
                    "user_id": $0.userID,
                    "name": $0.name,
                    "form": $0.form,
                    "created_at": $0.createdAt,
                    "updated_at": $0.updatedAt,
                ] as [String: Any]
            },
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        else { return }
        try? data.write(to: path)
    }

    private static func parse(_ raw: [String: Any]) -> SavedRoom? {
        guard let id = raw["id"] as? String,
              let userID = raw["user_id"] as? String,
              let name = raw["name"] as? String
        else { return nil }
        var form = defaultForm()
        if let stored = raw["form"] as? [String: Any] {
            for (key, value) in stored {
                form[key] = String(describing: value)
            }
        }
        return SavedRoom(
            id: id,
            userID: userID,
            name: name,
            form: form,
            createdAt: raw["created_at"] as? String ?? now(),
            updatedAt: raw["updated_at"] as? String ?? now()
        )
    }
}

func defaultForm() -> [String: String] {
    [
        "shape": "rect",
        "kind": "plank",
        "width_m": "4.000",
        "height_m": "3.000",
        "l_span_x_m": "6.000",
        "l_span_y_m": "4.000",
        "l_cutout_x_m": "2.500",
        "l_cutout_y_m": "2.000",
        "vertices": "0,0\n4,0\n4,2\n1.5,2\n1.5,3\n0,3",
        "hole_rectangles": "",
        "hole_vertices": "",
        "door_rectangles": "",
        "door_vertices": "",
        "window_segments": "",
        "plank_length_m": "1.383",
        "plank_width_m": "0.156",
        "boards_per_pack": "8",
        "tile_length_m": "0.600",
        "tile_width_m": "0.600",
        "grout_mm": "3",
        "expansion_mm": "",
        "direction": "along_long",
        "stagger": "third",
        "angle_deg": "0",
        "split": "none",
        "split_at_m": "",
        "kind_b": "tile",
    ]
}

private func now() -> String {
    ISO8601DateFormatter().string(from: Date())
}
