import SwiftUI

enum DR {
    static let bg = Color(red: 0.02, green: 0.05, blue: 0.05)
    static let s1 = Color(red: 0.06, green: 0.10, blue: 0.10)
    static let s2 = Color(red: 0.10, green: 0.16, blue: 0.16)
    static let s3 = Color(red: 0.15, green: 0.22, blue: 0.22)
    static let green = Color(red: 0.22, green: 0.92, blue: 0.55)
    static let onGreen = Color(red: 0.01, green: 0.13, blue: 0.07)
    static let gold = Color(red: 1, green: 0.8, blue: 0.3)
    static let red = Color(red: 1, green: 0.34, blue: 0.36)
    static let tx2 = Color(white: 1, opacity: 0.72), tx3 = Color(white: 1, opacity: 0.45)
    static let palette: [Color] = [
        Color(red: 0.22, green: 0.92, blue: 0.55), Color(red: 0.30, green: 0.65, blue: 1), Color(red: 1, green: 0.55, blue: 0.2),
        Color(red: 0.95, green: 0.35, blue: 0.5), Color(red: 0.68, green: 0.48, blue: 1), Color(red: 1, green: 0.8, blue: 0.3),
        Color(red: 0.2, green: 0.85, blue: 0.9), Color(red: 0.95, green: 0.4, blue: 0.3), Color(red: 0.6, green: 0.85, blue: 0.3), Color(red: 0.85, green: 0.6, blue: 0.9)]
    static func color(_ i: Int) -> Color { palette[((i % palette.count) + palette.count) % palette.count] }
    static let clubs = ["ريال مدريد", "برشلونة", "مانشستر سيتي", "ليفربول", "أرسنال", "بايرن ميونخ", "باريس سان جيرمان", "إنتر ميلان", "ميلان", "يوفنتوس",
                        "أتلتيكو مدريد", "دورتموند", "تشيلسي", "مانشستر يونايتد", "توتنهام", "نابولي", "ليفركوزن", "نيوكاسل", "بنفيكا", "أياكس",
                        "فرنسا", "البرازيل", "الأرجنتين", "إنكلترا", "إسبانيا", "ألمانيا", "البرتغال", "هولندا", "إيطاليا", "المغرب"]
    static func formatName(_ f: Format) -> String { f == .league ? "دوري" : (f == .cup ? "كأس" : "مجموعات + إقصاء") }
    static let groupNames = ["أ", "ب", "ج", "د"]
}

final class Store: ObservableObject {
    @Published var members: [Member] = []
    @Published var tournaments: [Tournament] = []
    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("dawri.json")
    private struct Disk: Codable { var members: [Member]; var tournaments: [Tournament] }

    init() {
        if Shot.on { seedDemo(); return }
        if let d = try? Data(contentsOf: url), let v = try? JSONDecoder().decode(Disk.self, from: d) { members = v.members; tournaments = v.tournaments }
    }
    func save() {
        guard !Shot.on else { return }
        if let d = try? JSONEncoder().encode(Disk(members: members, tournaments: tournaments)) { try? d.write(to: url, options: .atomic) }
    }

    func member(_ id: UUID?) -> Member? { guard let id else { return nil }; return members.first { $0.id == id } }
    func name(_ id: UUID?) -> String { member(id)?.name ?? "—" }
    func tint(_ id: UUID?) -> Color { member(id).map { DR.color($0.color) } ?? DR.s3 }
    func tournament(_ id: UUID) -> Tournament? { tournaments.first { $0.id == id } }

    var active: [Tournament] { tournaments.filter { !$0.finished && !$0.friendly }.sorted { $0.created > $1.created } }
    var done: [Tournament] { tournaments.filter { $0.finished && !$0.friendly }.sorted { $0.created > $1.created } }
    var careers: [Engine.Career] { Engine.careers(members, tournaments) }

    @discardableResult func addMember(_ name: String) -> Member {
        let m = Member(name: name, color: members.count)
        members.append(m); save(); return m
    }
    func update(_ m: Member) { if let i = members.firstIndex(where: { $0.id == m.id }) { members[i] = m; save() } }
    func used(_ id: UUID) -> Bool { tournaments.contains { $0.members.contains(id) } }
    func remove(member id: UUID) { guard !used(id) else { return }; members.removeAll { $0.id == id }; save() }

    func add(_ t: Tournament) { tournaments.insert(t, at: 0); save() }
    func remove(tournament id: UUID) { tournaments.removeAll { $0.id == id }; save() }
    func rename(_ id: UUID, _ name: String) { if let i = tournaments.firstIndex(where: { $0.id == id }) { tournaments[i].name = name; save() } }
    func score(_ tid: UUID, _ gid: UUID, hg: Int?, ag: Int?, hp: Int? = nil, ap: Int? = nil) {
        guard let i = tournaments.firstIndex(where: { $0.id == tid }) else { return }
        Engine.setScore(&tournaments[i], game: gid, hg: hg, ag: ag, hp: hp, ap: ap)
        save()
    }

    // MARK: بيانات تجريبيّة (لصور الشاشات فقط)
    private func seedDemo() {
        let names = ["علي", "عمر", "يوسف", "حسن", "كريم", "زيد", "مازن", "رامي"]
        members = names.enumerated().map { Member(name: $1, color: $0) }
        var seed: UInt64 = 7
        func rnd(_ m: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(m)) }
        func play(_ t: inout Tournament, limit: Int) {
            var n = 0
            while n < limit, let g = t.games.first(where: { $0.ready && !$0.decided }) {
                let h = rnd(5), a = rnd(4)
                let when = Date().addingTimeInterval(Double(-86400 * 20 + n * 5400))
                if g.stage.kind == 2 && h == a { Engine.setScore(&t, game: g.id, hg: h, ag: a, hp: 5, ap: 4, at: when) }
                else { Engine.setScore(&t, game: g.id, hg: h, ag: a, at: when) }
                n += 1
            }
        }
        let ids = members.map { $0.id }
        var clubs: [String: String] = [:]
        for (i, m) in ids.enumerated() { clubs[m.uuidString] = DR.clubs[i] }
        var old = Engine.make(name: "دوري الشتاء", format: .league, legs: 1, members: Array(ids.prefix(6)), clubs: clubs, shuffle: false)
        old.created = Date().addingTimeInterval(-86400 * 40); play(&old, limit: 999)
        var cupOld = Engine.make(name: "كأس الخميس", format: .cup, legs: 1, members: ids, clubs: clubs, shuffle: false)
        cupOld.created = Date().addingTimeInterval(-86400 * 25); play(&cupOld, limit: 999)
        var league = Engine.make(name: "دوري الربع", format: .league, legs: 2, members: Array(ids.prefix(6)), clubs: clubs, shuffle: false)
        league.created = Date().addingTimeInterval(-86400 * 6); play(&league, limit: 17)
        var groups = Engine.make(name: "بطولة العيد", format: .groups, legs: 1, members: ids, clubs: clubs, shuffle: false)
        groups.created = Date().addingTimeInterval(-86400 * 2); play(&groups, limit: Shot.isAny("bracket") ? 14 : 9)
        tournaments = [groups, league, cupOld, old]
    }
}

/// صورة اللاعب: دائرة بلونه وأوّل حرف من اسمه
struct Avatar: View {
    let name: String; let color: Color; var size: CGFloat = 36
    var body: some View {
        Text(String(name.trimmingCharacters(in: .whitespaces).first ?? "؟"))
            .font(rnd(size * 0.46, .black)).foregroundStyle(Color.black.opacity(0.75))
            .frame(width: size, height: size).background(color.gradient, in: Circle())
    }
}

struct Pill: View {
    let text: String; var tint: Color = DR.green
    var body: some View {
        Text(text).font(rnd(11, .heavy)).foregroundStyle(tint).padding(.horizontal, 8).padding(.vertical, 3).background(tint.opacity(0.15), in: Capsule())
    }
}

struct BigButton: View {
    let title: String; var icon: String = ""; var tint: Color = DR.green; var on: Color = DR.onGreen; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) { if !icon.isEmpty { Image(systemName: icon).font(.system(size: 16, weight: .bold)) }; Text(title).font(rnd(17, .heavy)) }
                .foregroundStyle(on).frame(maxWidth: .infinity).frame(height: 54).background(tint, in: Capsule())
        }.buttonStyle(Press())
    }
}
