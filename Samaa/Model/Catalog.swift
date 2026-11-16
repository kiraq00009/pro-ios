import Foundation

/// تصنيف الصوت (للألوان والتجميع)
enum SoundCat: String, Codable, CaseIterable {
    case people, home, safety, animals, nature, music, transport, other

    var ar: String {
        switch self {
        case .people: return "ناس"
        case .home: return "البيت"
        case .safety: return "أمان"
        case .animals: return "حيوانات"
        case .nature: return "طبيعة"
        case .music: return "موسيقى"
        case .transport: return "طريق"
        case .other: return "أخرى"
        }
    }
}

struct SoundInfo: Equatable {
    let id: String
    let ar: String
    let emoji: String
    let cat: SoundCat
}

/// قاموس معرّفات مصنّف الأصوات (SoundAnalysis version1) ← اسم عربيّ + إيموجي
enum Catalog {
    /// id|عربي|إيموجي|تصنيف
    static let raw: [String] = [
        "speech|كلام|🗣️|people", "shout|صياح|📢|people", "yell|صراخ عالي|📢|people",
        "screaming|صرخة|😱|safety", "children_shouting|أطفال يصيحون|🧒|people", "whispering|همس|🤫|people",
        "laughter|ضحك|😂|people", "baby_laughter|ضحكة طفل|👶|people", "giggling|قهقهة خفيفة|😄|people",
        "crying_sobbing|بكاء|😢|people", "baby_crying|طفل يبكي|👶|safety", "sigh|تنهيدة|😮‍💨|people",
        "singing|غناء|🎤|music", "humming|دندنة|🎶|music", "whistling|صفير|😗|people",
        "breathing|تنفّس|🌬️|people", "snoring|شخير|😴|people", "gasp|شهقة|😮|people",
        "cough|كحّة|🤧|people", "sneeze|عطسة|🤧|people", "nose_blowing|تمخّط|🤧|people",
        "throat_clearing|تنحنح|😶|people", "person_walking|خطوات|🚶|people", "person_running|ركض|🏃|people",
        "chewing|مضغ|😋|people", "burp|تجشّؤ|😬|people", "hiccup|حازوقة|😯|people",
        "finger_snapping|طقطقة أصابع|🫰|people", "clapping|تصفيق|👏|people", "applause|تصفيق جمهور|👏|people",
        "cheering|هتاف|🙌|people", "crowd|زحمة ناس|👥|people", "chatter|ثرثرة|💬|people", "babble|لغط|💬|people",
        "dog|كلب|🐶|animals", "dog_bark|نباح كلب|🐕|animals", "dog_howl|عواء كلب|🐺|animals",
        "dog_growl|زمجرة كلب|🐕|animals", "dog_whimper|أنين كلب|🐕|animals", "dog_bow_wow|نباح|🐕|animals",
        "cat|قطّة|🐱|animals", "cat_meow|مواء قطّة|🐈|animals", "cat_purr|خرخرة قطّة|🐈|animals",
        "bird|طير|🐦|animals", "bird_chirp_tweet|زقزقة|🐤|animals", "bird_vocalization|تغريد طيور|🐦|animals",
        "rooster_crow|صياح ديك|🐓|animals", "chicken|دجاج|🐔|animals", "crow_caw|نعيق غراب|🐦‍⬛|animals",
        "pigeon_dove_coo|هديل حمام|🕊️|animals", "insect|حشرة|🐛|animals", "mosquito_buzz|طنين بعوض|🦟|animals",
        "fly_buzz|ذبابة|🪰|animals", "bee_buzz|نحلة|🐝|animals", "cricket_chirp|صرصور ليل|🦗|animals", "frog_croak|نقيق ضفدع|🐸|animals",
        "music|موسيقى|🎵|music", "guitar|جيتار|🎸|music", "piano|بيانو|🎹|music", "drum|طبل|🥁|music",
        "violin_fiddle|كمان|🎻|music", "drum_kit|درامز|🥁|music", "musical_instrument|آلة موسيقية|🎼|music",
        "water|ماء|💧|home", "water_tap_faucet|حنفيّة مفتوحة|🚰|home", "sink_filling_washing|مغسلة تمتلئ|🚰|home",
        "bathtub_filling_washing|حوض يمتلئ|🛁|home", "toilet_flush|سيفون|🚽|home", "liquid_dripping|تنقيط ماء|💧|home",
        "pour|سكب|🫗|home", "boiling|غليان|♨️|home", "kettle_whistle|صفّارة إبريق|🫖|home",
        "frying_food|قلي أكل|🍳|home", "chopping_food|تقطيع أكل|🔪|home", "dishes_pots_pans|صحون وقدور|🍽️|home",
        "cutlery_silverware|ملاعق وشوك|🍴|home", "microwave_oven|مايكرويف|📦|home", "blender|خلّاط|🥤|home",
        "vacuum_cleaner|مكنسة كهربائية|🧹|home", "hair_dryer|سشوار|💨|home", "washing_machine|غسّالة|🧺|home",
        "door|باب|🚪|home", "door_bell|جرس الباب|🔔|safety", "doorbell|جرس الباب|🔔|safety",
        "knock|طرق على الباب|✊|safety", "door_slam|صفقة باب|🚪|home", "door_sliding|باب منزلق|🚪|home",
        "keys_jangling|خشخشة مفاتيح|🔑|home", "zipper|سحّاب|🧥|home", "typing|كتابة كيبورد|⌨️|home",
        "typing_computer_keyboard|كيبورد|⌨️|home", "writing|كتابة بالقلم|✍️|home", "scissors|مقص|✂️|home",
        "clock|ساعة|🕰️|home", "tick_tock|تكتكة ساعة|⏱️|home", "alarm_clock|منبّه|⏰|safety",
        "telephone|هاتف|☎️|home", "telephone_bell_ringing|رنين هاتف|📞|safety", "ringtone|نغمة رنين|📱|safety",
        "smoke_detector|إنذار دخان|🚨|safety", "fire_alarm|إنذار حريق|🚨|safety", "alarm|إنذار|🚨|safety",
        "glass_breaking|كسر زجاج|💥|safety", "glass_clink|طقطقة كاسات|🥂|home", "shatter|تحطّم|💥|safety",
        "siren|صفّارة إنذار|🚨|safety", "police_siren|صفّارة شرطة|🚓|safety", "ambulance_siren|إسعاف|🚑|safety",
        "fire_engine_siren|إطفاء|🚒|safety", "civil_defense_siren|صفّارة دفاع مدني|📢|safety", "emergency_vehicle|سيارة طوارئ|🚨|safety",
        "car_horn|هورن سيارة|📯|transport", "vehicle_skidding|انزلاق سيارة|🚗|transport", "car_passing_by|سيارة تمرّ|🚗|transport",
        "engine|محرّك|⚙️|transport", "motorcycle|دراجة نارية|🏍️|transport", "bus|باص|🚌|transport",
        "truck|شاحنة|🚚|transport", "train|قطار|🚆|transport", "airplane|طيارة|✈️|transport",
        "helicopter|هليكوبتر|🚁|transport", "bicycle_bell|جرس دراجة|🚲|transport", "traffic_noise|زحمة شارع|🚦|transport",
        "rain|مطر|🌧️|nature", "raindrop|قطرات مطر|💧|nature", "thunder|رعد|⚡|nature", "thunderstorm|عاصفة رعدية|⛈️|nature",
        "wind|ريح|🌬️|nature", "wind_rustling_leaves|حفيف أوراق|🍃|nature", "fire|نار|🔥|safety", "fire_crackle|طقطقة نار|🔥|nature",
        "stream_burbling|خرير ماء|🏞️|nature", "ocean|بحر|🌊|nature", "sea_waves|أمواج|🌊|nature",
        "fireworks|ألعاب نارية|🎆|other", "firecracker|مفرقعات|🧨|other", "gunshot_gunfire|إطلاق نار|💥|safety",
        "explosion|انفجار|💥|safety", "silence|هدوء|🤍|other", "printer|طابعة|🖨️|home", "camera|كاميرا|📷|home",
    ]

    static let map: [String: SoundInfo] = {
        var m: [String: SoundInfo] = [:]
        for line in raw {
            let p = line.components(separatedBy: "|")
            guard p.count == 4 else { continue }
            m[p[0]] = SoundInfo(id: p[0], ar: p[1], emoji: p[2], cat: SoundCat(rawValue: p[3]) ?? .other)
        }
        return m
    }()

    /// كلمات داخل المعرّف لتخمين الإيموجي والتصنيف إذا المعرّف مو بالقاموس
    static let guesses: [(String, String, SoundCat)] = [
        ("dog", "🐶", .animals), ("cat", "🐱", .animals), ("bird", "🐦", .animals), ("horse", "🐴", .animals),
        ("cow", "🐮", .animals), ("sheep", "🐑", .animals), ("goat", "🐐", .animals), ("pig", "🐷", .animals),
        ("duck", "🦆", .animals), ("lion", "🦁", .animals), ("owl", "🦉", .animals), ("whale", "🐋", .animals),
        ("siren", "🚨", .safety), ("alarm", "🚨", .safety), ("baby", "👶", .people), ("laugh", "😂", .people),
        ("water", "💧", .home), ("door", "🚪", .home), ("car", "🚗", .transport), ("vehicle", "🚗", .transport),
        ("guitar", "🎸", .music), ("drum", "🥁", .music), ("music", "🎵", .music), ("organ", "🎹", .music),
        ("bell", "🔔", .home), ("rain", "🌧️", .nature), ("wind", "🌬️", .nature), ("engine", "⚙️", .transport),
    ]

    static func humanize(_ id: String) -> String {
        id.replacingOccurrences(of: "_", with: " ")
    }

    static func info(_ id: String) -> SoundInfo {
        if let i = map[id] { return i }
        for g in guesses where id.contains(g.0) { return SoundInfo(id: id, ar: humanize(id), emoji: g.1, cat: g.2) }
        return SoundInfo(id: id, ar: humanize(id), emoji: "🔊", cat: .other)
    }

    static func ar(_ id: String) -> String { info(id).ar }
    static func emoji(_ id: String) -> String { info(id).emoji }

    /// هاش ثابت (هاش سويفت يتغيّر كلّ تشغيل) — حتى يبقى كلّ صوت بنفس زاوية الرادار
    static func stableHash(_ s: String) -> UInt64 {
        var h: UInt64 = 14695981039346656037
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return h
    }

    /// زاوية ثابتة بالدرجات 0..<360 لكلّ صوت
    static func angle(_ id: String) -> Double {
        Double(stableHash(id) % 3600) / 10.0
    }
}

/// مجموعة أصوات تنحرس (كلّ مجموعة تجمع معرّفات متقاربة)
struct WatchGroup: Identifiable, Equatable {
    let id: String
    let ar: String
    let emoji: String
    let note: String
    let ids: [String]
}

enum Watch {
    static let groups: [WatchGroup] = [
        WatchGroup(id: "baby", ar: "طفل يبكي", emoji: "👶", note: "بكاء رضيع أو طفل", ids: ["baby_crying", "crying_sobbing"]),
        WatchGroup(id: "door", ar: "الباب", emoji: "🔔", note: "جرس أو طرق على الباب", ids: ["door_bell", "doorbell", "knock"]),
        WatchGroup(id: "smoke", ar: "إنذار دخان", emoji: "🚨", note: "كاشف دخان أو إنذار حريق", ids: ["smoke_detector", "fire_alarm", "alarm"]),
        WatchGroup(id: "glass", ar: "كسر زجاج", emoji: "💥", note: "زجاج ينكسر أو شي يتحطّم", ids: ["glass_breaking", "shatter"]),
        WatchGroup(id: "dog", ar: "نباح", emoji: "🐕", note: "كلب ينبح أو يعوي", ids: ["dog", "dog_bark", "dog_howl", "dog_growl", "dog_bow_wow"]),
        WatchGroup(id: "horn", ar: "هورن", emoji: "📯", note: "هورن سيارة قريب", ids: ["car_horn"]),
        WatchGroup(id: "siren", ar: "صفّارة طوارئ", emoji: "🚑", note: "إسعاف، شرطة، إطفاء", ids: ["siren", "police_siren", "ambulance_siren", "fire_engine_siren", "civil_defense_siren", "emergency_vehicle"]),
        WatchGroup(id: "water", ar: "ماء مفتوح", emoji: "🚰", note: "حنفيّة أو حوض نسيته", ids: ["water_tap_faucet", "sink_filling_washing", "bathtub_filling_washing"]),
        WatchGroup(id: "phone", ar: "رنين هاتف", emoji: "📞", note: "هاتف يرنّ بغرفة ثانية", ids: ["telephone_bell_ringing", "ringtone", "telephone"]),
        WatchGroup(id: "scream", ar: "صراخ", emoji: "😱", note: "صرخة أو صياح عالي", ids: ["screaming", "shout", "yell", "children_shouting"]),
        WatchGroup(id: "kettle", ar: "إبريق يصفّر", emoji: "🫖", note: "الماء غلى", ids: ["kettle_whistle", "boiling"]),
        WatchGroup(id: "cat", ar: "قطّة", emoji: "🐈", note: "مواء قطّتك", ids: ["cat", "cat_meow"]),
        WatchGroup(id: "clock", ar: "منبّه", emoji: "⏰", note: "منبّه يرنّ وما أحد يطفيه", ids: ["alarm_clock"]),
    ]

    static func group(id: String) -> WatchGroup? { groups.first { $0.id == id } }

    static func group(forSound s: String) -> WatchGroup? { groups.first { $0.ids.contains(s) } }

    /// أعلى ثقة لمجموعة من بين نتائج إطار واحد
    static func confidence(_ g: WatchGroup, in hits: [Hit]) -> Double {
        var best = 0.0
        for h in hits where g.ids.contains(h.id) { best = max(best, h.conf) }
        return best
    }
}
