import Foundation

// MARK: - Deterministic RNG (pure, seedable)

/// Small linear-congruential generator so spins / quizzes are reproducible per seed.
public struct FilmRNG {
    private var state: UInt64
    public init(_ seed: Int) {
        // Mix the seed so tiny seeds (0,1,2) still scatter well.
        let s = UInt64(bitPattern: Int64(truncatingIfNeeded: seed))
        state = (s &* 2862933555777941757) &+ 3037000493
        _ = step(); _ = step()
    }
    private mutating func step() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    /// Uniform integer in 0..<n (n>0), else 0.
    public mutating func int(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        return Int(step() % UInt64(n))
    }
    /// Deterministic Fisher-Yates shuffle.
    public mutating func shuffled<T>(_ input: [T]) -> [T] {
        var a = input
        guard a.count > 1 else { return a }
        var i = a.count - 1
        while i > 0 {
            let j = int(i + 1)
            a.swapAt(i, j)
            i -= 1
        }
        return a
    }
}

// MARK: - 1. Wheel (mood / genre)

public struct Genre: Equatable {
    public let name: String
    public let vibe: String
    public let emoji: String
    public init(name: String, vibe: String, emoji: String) {
        self.name = name; self.vibe = vibe; self.emoji = emoji
    }
}

public enum Wheel {
    /// Full list of moods/genres shown on the wheel. Original, generic (no titles).
    public static func genres() -> [Genre] {
        return [
            Genre(name: "أكشن",        vibe: "ركض، انفجارات، وما تلحك تاخذ نفَس",            emoji: "💥"),
            Genre(name: "كوميدي",      vibe: "ضحك خفيف يذيب تعب اليوم",                      emoji: "😂"),
            Genre(name: "رعب",         vibe: "طفّوا الضوء وخلّوا القلب يدگ",                   emoji: "👻"),
            Genre(name: "رومنسي",      vibe: "قصّة حب تدفّي القلب",                           emoji: "❤️"),
            Genre(name: "إثارة",        vibe: "توتر وخيوط تنفكّ بالآخر",                        emoji: "🔪"),
            Genre(name: "خيال علميّ",   vibe: "مستقبل، فضاء، وأفكار تكبّر الراس",              emoji: "🚀"),
            Genre(name: "جريمة",        vibe: "تحقيق، لغز، ومجرم ينلزم",                       emoji: "🕵️"),
            Genre(name: "أنمي",         vibe: "رسم ياباني وقصص ما تنتسى",                      emoji: "🌸"),
            Genre(name: "وثائقيّ",      vibe: "معلومة حقيقيّة تخليك تفكّر",                      emoji: "🎞️"),
            Genre(name: "دراما",        vibe: "مشاعر صادقة وقصّة تلمسك",                        emoji: "🎭"),
            Genre(name: "عائليّ",       vibe: "تنشاف ويا الكل من الصغير للكبير",               emoji: "👨‍👩‍👧"),
            Genre(name: "مغامرة",       vibe: "رحلة، كنوز، وعوالم جديدة",                      emoji: "🗺️"),
            Genre(name: "فنتازيا",      vibe: "سحر، تنانين، وممالك خياليّة",                    emoji: "🐉"),
            Genre(name: "غموض",         vibe: "سؤال واحد يلفّك لآخر دقيقة",                     emoji: "🧩"),
            Genre(name: "موسيقيّ",      vibe: "أغاني ورقص ومزاج عالي",                         emoji: "🎵"),
            Genre(name: "تاريخيّ",      vibe: "زمن قديم وقصص صارت فعلاً",                       emoji: "🏛️")
        ]
    }

    /// Deterministic spin: same seed -> same genre.
    public static func spin(seed: Int) -> Genre {
        let g = genres()
        var rng = FilmRNG(seed)
        return g[rng.int(g.count)]
    }
}

// MARK: - 2. This-or-That knockout bracket

/// Single-elimination bracket. Handles 2..N options and odd rounds via byes.
public struct Bracket {
    public private(set) var current: [String]   // participants still alive this round
    private var winners: [String] = []          // winners accumulated in the current round
    private var index: Int = 0                   // cursor into `current`
    public private(set) var round: Int = 1
    public private(set) var matchesPlayed: Int = 0

    public init(options: [String]) {
        current = options
    }

    public var isDone: Bool { current.count <= 1 }

    public var champion: String? { isDone ? current.first : nil }

    /// Skip trailing byes and roll over finished rounds until a real pair is ready (or done).
    private mutating func settle() {
        while current.count > 1 {
            if index == current.count - 1 {
                // odd one out gets a free pass to next round
                winners.append(current[index])
                index += 1
            }
            if index >= current.count {
                current = winners
                winners = []
                index = 0
                round = isDone ? round : round + 1
                continue
            }
            return   // index .. index+1 is a valid match
        }
    }

    /// The next pair to decide, or nil when a champion exists.
    public mutating func next() -> (String, String)? {
        settle()
        guard !isDone else { return nil }
        return (current[index], current[index + 1])
    }

    /// Record the winner of the current match. Ignores a winner that isn't in the pair.
    public mutating func pick(_ winner: String) {
        settle()
        guard !isDone, index + 1 < current.count else { return }
        let a = current[index], b = current[index + 1]
        guard winner == a || winner == b else { return }
        winners.append(winner)
        index += 2
        matchesPlayed += 1
        settle()
    }
}

// MARK: - 3. Group vote tally

public enum Vote {
    /// Count votes per option. `votes` holds a chosen option index per voter.
    /// Returns per-option counts and all winner indices (ties -> several).
    public static func tally(votes: [Int], options: Int) -> (counts: [Int], winnerIndices: [Int]) {
        var counts = Array(repeating: 0, count: max(0, options))
        for v in votes where v >= 0 && v < options {
            counts[v] += 1
        }
        let top = counts.max() ?? 0
        var winners: [Int] = []
        if top > 0 {
            for (i, c) in counts.enumerated() where c == top {
                winners.append(i)
            }
        }
        return (counts, winners)
    }
}

// MARK: - 4. Trivia (generic film / TV knowledge, no copyrighted titles)

public struct Question: Equatable {
    public let text: String
    public let options: [String]
    public let answer: Int
    public let explain: String?
    public init(text: String, options: [String], answer: Int, explain: String? = nil) {
        self.text = text; self.options = options; self.answer = answer; self.explain = explain
    }
    public var correct: String { options[answer] }
}

public enum Trivia {
    public static func questions() -> [Question] {
        return [
            Question(text: "شنو شغلة «المخرج» بالفيلم؟",
                     options: ["يقود العمل الفنّي ويوجّه الممثلين", "يبيع التذاكر", "يكتب الموسيقى بس", "يصمّم الملابس"],
                     answer: 0, explain: "المخرج هو اللي يمسك دفّة الفيلم فنّيًّا."),
            Question(text: "منو اللي يكتب أحداث الفيلم وحواره؟",
                     options: ["كاتب السيناريو", "مدير التصوير", "المونتير", "المنتج"],
                     answer: 0),
            Question(text: "شنو يسوّي «المونتير»؟",
                     options: ["يركّب اللقطات ويرتّب الإيقاع", "يوزّع الأجور", "يختار المطعم", "يبيع الحقوق"],
                     answer: 0),
            Question(text: "نوع يعتمد على الضحك هو…",
                     options: ["كوميدي", "رعب", "وثائقيّ", "حربيّ"],
                     answer: 0),
            Question(text: "😱👻 هاي الإيموجي تدلّ على أيّ نوع؟",
                     options: ["رعب", "رومنسي", "عائليّ", "موسيقيّ"],
                     answer: 0),
            Question(text: "❤️💑 هاي الإيموجي تدلّ على أيّ نوع؟",
                     options: ["رومنسي", "أكشن", "رعب", "جريمة"],
                     answer: 0),
            Question(text: "🚀🪐 هاي الإيموجي تدلّ على أيّ نوع؟",
                     options: ["خيال علميّ", "تاريخيّ", "كوميدي", "عائليّ"],
                     answer: 0),
            Question(text: "فيلم بيه تحقيق ومجرم ولغز يسمّونه…",
                     options: ["جريمة", "موسيقيّ", "عائليّ", "رياضيّ"],
                     answer: 0),
            Question(text: "النوع اللي يعتمد على الحقيقة والمعلومة هو…",
                     options: ["وثائقيّ", "فنتازيا", "رعب", "أكشن"],
                     answer: 0),
            Question(text: "«أنمي» أصلها من أيّ بلد؟",
                     options: ["اليابان", "البرازيل", "مصر", "كندا"],
                     answer: 0),
            Question(text: "شنو «التريلر» (الإعلان)؟",
                     options: ["مقطع قصير يعرّفك بالفيلم", "نهاية الفيلم", "اسم الممثل", "قاعة السينما"],
                     answer: 0),
            Question(text: "«البطل» بالفيلم يعني…",
                     options: ["الشخصيّة الرئيسيّة", "صاحب القاعة", "بائع الفشار", "كاتب النقد"],
                     answer: 0),
            Question(text: "«الشرّير» بالقصّة هو…",
                     options: ["الخصم اللي يوگف بوجه البطل", "المصوّر", "الموزّع", "المنتج"],
                     answer: 0),
            Question(text: "شنو «المَشهد» (Scene)؟",
                     options: ["جزء من الفيلم بمكان وزمن واحد", "كل الفيلم", "عنوان الفيلم", "اسم الشركة"],
                     answer: 0),
            Question(text: "شنو تسوّي «المؤثّرات البصريّة» VFX؟",
                     options: ["تضيف أشياء ما ممكن تتصوّر على الحقيقة", "تبيع البطاقات", "تطبع البوسترات", "تكتب الأغاني"],
                     answer: 0),
            Question(text: "«الدوبلاج» يعني…",
                     options: ["تبديل الصوت بلغة ثانية", "قصّ المشاهد", "كتابة القصّة", "تصميم الديكور"],
                     answer: 0),
            Question(text: "«الترجمة» (Subtitles) تنكتب وين عادةً؟",
                     options: ["أسفل الشاشة", "فوق الشاشة بس", "على الملصق", "بالتذكرة"],
                     answer: 0),
            Question(text: "فيلم يصير بزمن قديم وأحداث صارت فعلاً نوعه…",
                     options: ["تاريخيّ", "خيال علميّ", "رعب", "كوميدي"],
                     answer: 0),
            Question(text: "النوع اللي بيه سحر وتنانين وممالك خياليّة…",
                     options: ["فنتازيا", "وثائقيّ", "جريمة", "رياضيّ"],
                     answer: 0),
            Question(text: "شنو «المشهد الافتتاحيّ»؟",
                     options: ["أوّل مشهد بالفيلم", "آخر مشهد", "أطول مشهد", "أغلى مشهد"],
                     answer: 0),
            Question(text: "«الكاميرا» وظيفتها الأساسيّة…",
                     options: ["تصوّر الصورة المتحرّكة", "تطبع التذاكر", "تشغّل الصوت", "تضيء القاعة"],
                     answer: 0),
            Question(text: "شنو «الموسيقى التصويريّة»؟",
                     options: ["الموسيقى اللي ترافق مشاهد الفيلم", "أغنية المقدّمة بس", "صوت الجمهور", "إعلان قبل الفيلم"],
                     answer: 0),
            Question(text: "«الكاستينغ» يعني…",
                     options: ["اختيار الممثلين للأدوار", "بيع الحقوق", "طبع البوستر", "توزيع الفشار"],
                     answer: 0),
            Question(text: "فيلم ينعرض بالسينما قبل التلفزيون غالبًا، شيسمّون هاي؟",
                     options: ["عرض أوّل (Premiere)", "إعادة", "تحميل", "اشتراك"],
                     answer: 0),
            Question(text: "شنو «الحلقة» بالمسلسل؟",
                     options: ["جزء واحد من المواسم", "كل المسلسل", "اسم البطل", "شركة الإنتاج"],
                     answer: 0),
            Question(text: "«الموسم» بالمسلسل يعني…",
                     options: ["مجموعة حلقات مترابطة", "دقيقة وحدة", "اسم المخرج", "نوع الكاميرا"],
                     answer: 0),
            Question(text: "شنو «السبين-أوف» (Spin-off)؟",
                     options: ["عمل جديد يتفرّع من عمل موجود", "نهاية القصّة", "إعلان تجاريّ", "جائزة"],
                     answer: 0),
            Question(text: "«الكاميو» (Cameo) هو…",
                     options: ["ظهور قصير لشخص معروف", "دور البطولة", "اسم القاعة", "نوع الشاشة"],
                     answer: 0),
            Question(text: "شنو «البوستر»؟",
                     options: ["ملصق دعائيّ للفيلم", "كرسي القاعة", "جهاز العرض", "بطاقة الدخول"],
                     answer: 0),
            Question(text: "فيلم رسوم متحرّكة نسمّيه…",
                     options: ["أنيميشن", "وثائقيّ", "رعب", "رياضيّ"],
                     answer: 0),
            Question(text: "«النهاية المفتوحة» تعني…",
                     options: ["القصّة ما تنتهي بوضوح وتخلّي سؤال", "كل شي ينحلّ", "ما بيها أحداث", "تتكرّر مرّتين"],
                     answer: 0),
            Question(text: "شنو «السيناريو»؟",
                     options: ["النص المكتوب للأحداث والحوار", "اسم القاعة", "جهاز الصوت", "سعر التذكرة"],
                     answer: 0),
            Question(text: "«مدير التصوير» مسؤول عن…",
                     options: ["الصورة والإضاءة", "بيع التذاكر", "كتابة الأغاني", "توزيع الأجور"],
                     answer: 0),
            Question(text: "النوع اللي يركّز على التوتر والمطاردة والخطر…",
                     options: ["إثارة", "عائليّ", "وثائقيّ", "موسيقيّ"],
                     answer: 0),
            Question(text: "🎵💃 هاي الإيموجي تدلّ على أيّ نوع؟",
                     options: ["موسيقيّ", "رعب", "جريمة", "حربيّ"],
                     answer: 0),
            Question(text: "شنو «المقطورة الدعائيّة الأولى» (Teaser)؟",
                     options: ["إعلان قصير جدًّا يلمّح للفيلم", "الفيلم كامل", "نقد الفيلم", "قائمة الممثلين"],
                     answer: 0)
        ]
    }

    /// Deterministic quiz subset: same seed -> same questions in same order.
    public static func quiz(seed: Int, count: Int) -> [Question] {
        let bank = questions()
        guard count > 0 else { return [] }
        var rng = FilmRNG(seed)
        let shuffled = rng.shuffled(bank)
        return Array(shuffled.prefix(min(count, shuffled.count)))
    }

    /// Scoring helper: base points + streak bonus + a slice of remaining time.
    public static func points(correct: Bool, streak: Int, timeLeft: Int) -> Int {
        guard correct else { return 0 }
        let base = 10
        let streakBonus = max(0, streak) * 2
        let timeBonus = max(0, timeLeft)
        return base + streakBonus + timeBonus
    }
}
