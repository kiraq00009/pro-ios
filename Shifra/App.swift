import SwiftUI
import UIKit

enum SF {
    static let bg = Color(red: 0.04, green: 0.04, blue: 0.07)
    static let s1 = Color(red: 0.08, green: 0.08, blue: 0.13)
    static let s2 = Color(red: 0.13, green: 0.13, blue: 0.20)
    static let s3 = Color(red: 0.19, green: 0.19, blue: 0.29)
    static let mint = Color(red: 0.3, green: 0.92, blue: 0.7)
    static let violet = Color(red: 0.64, green: 0.5, blue: 1)
    static let pink = Color(red: 1, green: 0.42, blue: 0.72)
    static let amber = Color(red: 1, green: 0.76, blue: 0.32)
    static let red = Color(red: 1, green: 0.44, blue: 0.44)
    static let tx2 = Color(white: 1, opacity: 0.74), tx3 = Color(white: 1, opacity: 0.46)
    static func strengthColor(_ s: Int) -> Color { [red, red, amber, mint, mint][max(0, min(4, s))] }
}

// تحويل UIImage ↔ بكسلات RGBA لإخفاء الرسائل
enum ImageStego {
    static func pixels(_ image: UIImage) -> (data: [UInt8], w: Int, h: Int)? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (buf, w, h)
    }
    static func image(_ data: [UInt8], w: Int, h: Int) -> UIImage? {
        var buf = data
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let cg = ctx.makeImage() else { return nil }
        return UIImage(cgImage: cg)
    }
    /// يخبّي نصًّا (مشفّر اختياريًّا) داخل صورة ويرجّع PNG
    static func hide(_ text: String, pass: String, in image: UIImage) -> UIImage? {
        guard var p = pixels(image) else { return nil }
        let data: Data = pass.isEmpty ? Data(text.utf8) : (Crypto.encryptRaw(text, pass: pass) ?? Data())
        guard !data.isEmpty, Stego.capacity(pixels: p.w * p.h) >= data.count else { return nil }
        guard Stego.embed(into: &p.data, data: data) else { return nil }
        return self.image(p.data, w: p.w, h: p.h)
    }
    static func reveal(_ image: UIImage, pass: String) -> String? {
        guard let p = pixels(image), let data = Stego.extract(from: p.data) else { return nil }
        if pass.isEmpty { return String(data: data, encoding: .utf8) }
        return Crypto.decryptRaw(data, pass: pass)
    }
}

@MainActor
final class Vault: ObservableObject {
    struct Note: Identifiable, Codable { let id: UUID; var title: String; var blob: String; var date: Date }
    @Published var notes: [Note] = []
    private let ud = UserDefaults.standard
    init() {
        if Shot.on {
            notes = [Note(id: UUID(), title: "اجتماع العمل", blob: "x", date: Date().addingTimeInterval(-3600)),
                     Note(id: UUID(), title: "رقم الحساب", blob: "x", date: Date().addingTimeInterval(-90000))]
            return
        }
        if let d = ud.data(forKey: "sf_notes"), let v = try? JSONDecoder().decode([Note].self, from: d) { notes = v }
    }
    func save(title: String, blob: String) {
        notes.insert(Note(id: UUID(), title: title.isEmpty ? "بلا عنوان" : title, blob: blob, date: Date()), at: 0)
        persist()
    }
    func remove(_ id: UUID) { notes.removeAll { $0.id == id }; persist() }
    private func persist() { if !Shot.on, let d = try? JSONEncoder().encode(notes) { ud.set(d, forKey: "sf_notes") } }
}

@main
struct ShifraApp: App {
    @StateObject private var vault = Vault()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(vault)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark).tint(SF.mint)
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            SF.bg
            RadialGradient(colors: [SF.violet.opacity(0.16), Color.clear], center: .topLeading, startRadius: 0, endRadius: 470)
            RadialGradient(colors: [SF.mint.opacity(0.12), Color.clear], center: .bottomTrailing, startRadius: 0, endRadius: 430)
        }.ignoresSafeArea()
    }
}

struct RootView: View {
    @State private var tab = 0
    var body: some View {
        ZStack(alignment: .bottom) {
            Backdrop()
            Group {
                switch tab {
                case 0: EncryptScreen()
                case 1: DecryptScreen()
                case 2: PhotoScreen()
                default: PassScreen()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            tabBar
        }
        .onAppear {
            switch Shot.name {
            case "decrypt": tab = 1
            case "photo", "hide", "reveal": tab = 2
            case "pass": tab = 3
            default: tab = 0
            }
        }
    }
    @State private var tab2 = 0
    private var tabBar: some View {
        let items: [(String, String)] = [("تشفير", "lock.fill"), ("فكّ", "lock.open.fill"), ("بصورة", "photo.fill"), ("كلمات سرّ", "key.fill")]
        return HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                Button { Haptic.tap(); tab = i } label: {
                    VStack(spacing: 4) {
                        Image(systemName: items[i].1).font(.system(size: 18, weight: .semibold))
                        Text(items[i].0).font(rnd(10, .bold))
                    }.foregroundStyle(tab == i ? SF.mint : SF.tx3).frame(maxWidth: .infinity).padding(.vertical, 9)
                }.buttonStyle(Press())
            }
        }
        .padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 2)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.08)))
        .padding(.horizontal, 14).padding(.bottom, 6)
    }
}

func header(_ t: String, _ s: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
        Text(t).font(rnd(30, .black)).foregroundStyle(Color.white)
        Text(s).font(rnd(12.5)).foregroundStyle(SF.tx3).fixedSize(horizontal: false, vertical: true)
    }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
}

struct PassField: View {
    let label: String
    @Binding var text: String
    @State private var show = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(rnd(12.5, .bold)).foregroundStyle(SF.tx3)
            HStack {
                Group {
                    if show { TextField("", text: $text) } else { SecureField("", text: $text) }
                }.font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(Color.white)
                    .autocorrectionDisabled().textInputAutocapitalization(.never).environment(\.layoutDirection, .leftToRight)
                Button { show.toggle() } label: { Image(systemName: show ? "eye.slash.fill" : "eye.fill").foregroundStyle(SF.tx3) }
            }.padding(13).background(SF.s2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08)))
        }
    }
}

func bigButton(_ t: String, _ icon: String, _ c: Color, _ dim: Bool = false, _ act: @escaping () -> Void) -> some View {
    Button(action: act) {
        HStack(spacing: 8) { Image(systemName: icon).font(.system(size: 15, weight: .black)); Text(t).font(rnd(16, .black)) }
            .foregroundStyle(dim ? SF.tx3 : Color.black.opacity(0.84)).frame(maxWidth: .infinity).frame(height: 54)
            .background(dim ? SF.s2 : c, in: Capsule())
    }.buttonStyle(Press()).disabled(dim)
}
