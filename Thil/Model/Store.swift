import Foundation

/// مخزن المشاريع بملفّات JSON داخل مجلّد (Documents/Thil بالتطبيق، ومجلّد مؤقّت بالفحص)
struct ProjectStore {
    let root: URL

    init(root: URL) {
        self.root = root
        for d in [projectsDir, imagesDir, thumbsDir] {
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
    }

    var projectsDir: URL { root.appendingPathComponent("projects", isDirectory: true) }
    var imagesDir: URL { root.appendingPathComponent("images", isDirectory: true) }
    var thumbsDir: URL { root.appendingPathComponent("thumbs", isDirectory: true) }

    func projectURL(_ id: String) -> URL { projectsDir.appendingPathComponent(id + ".json") }
    func imageURL(_ id: String) -> URL { imagesDir.appendingPathComponent(id + ".img") }
    func thumbURL(_ id: String) -> URL { thumbsDir.appendingPathComponent(id + ".jpg") }

    static func encode(_ p: Project) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return try e.encode(p)
    }
    static func decode(_ d: Data) -> Project? { try? JSONDecoder().decode(Project.self, from: d) }

    func save(_ p: Project) throws { try ProjectStore.encode(p).write(to: projectURL(p.id), options: .atomic) }

    func load(_ id: String) -> Project? {
        guard let d = try? Data(contentsOf: projectURL(id)) else { return nil }
        return ProjectStore.decode(d)
    }

    /// كلّ المشاريع، الأحدث تعديلًا أوّلًا
    func all() -> [Project] {
        let files = (try? FileManager.default.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil)) ?? []
        let ps: [Project] = files.filter { $0.pathExtension == "json" }.compactMap { u -> Project? in
            guard let d = try? Data(contentsOf: u) else { return nil }
            return ProjectStore.decode(d)
        }
        return ps.sorted { a, b in a.modified == b.modified ? a.id < b.id : a.modified > b.modified }
    }

    func delete(_ id: String) {
        try? FileManager.default.removeItem(at: projectURL(id))
        try? FileManager.default.removeItem(at: thumbURL(id))
    }

    func saveImage(_ data: Data, id: String) throws { try data.write(to: imageURL(id), options: .atomic) }
    func imageData(_ id: String) -> Data? { try? Data(contentsOf: imageURL(id)) }

    func storedImageIDs() -> Set<String> {
        let files = (try? FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)) ?? []
        return Set(files.filter { $0.pathExtension == "img" }.map { $0.deletingPathExtension().lastPathComponent })
    }

    /// يمسح الصور اللي ما يستعملها أيّ مشروع ⇒ عددها
    @discardableResult func cleanOrphans(keep extra: Set<String> = []) -> Int {
        var used = extra
        for p in all() { used.formUnion(p.imageIDs) }
        var n = 0
        for id in storedImageIDs() where !used.contains(id) {
            try? FileManager.default.removeItem(at: imageURL(id))
            n += 1
        }
        return n
    }

    func duplicate(_ p: Project, newID: String, now: Double) throws -> Project {
        var c = p
        c.id = newID
        c.name = p.name + " · نسخة"
        c.created = now
        c.modified = now
        try save(c)
        return c
    }

    func rename(_ id: String, to name: String, now: Double) throws {
        guard var p = load(id) else { return }
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        p.name = String(t.prefix(40))
        p.modified = now
        try save(p)
    }

    func deleteAll() {
        for d in [projectsDir, imagesDir, thumbsDir] {
            try? FileManager.default.removeItem(at: d)
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
    }

    /// اسم افتراضيّ غير مكرّر: «تصميم ٣»
    static func nextName(_ existing: [String]) -> String {
        var n = existing.count + 1
        while existing.contains("تصميم \(n)") { n += 1 }
        return "تصميم \(n)"
    }
}

/// إحصاءات بسيطة
struct Stats: Codable, Equatable {
    var cuts = 0
    var exports = 0
    var stickers = 0
    var bestLayers = 0

    mutating func noteExport(layers: Int, stickers s: Int) {
        exports += 1
        stickers += s
        bestLayers = max(bestLayers, layers)
    }
}
