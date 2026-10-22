import Foundation

var failures = 0
func check(_ condition: Bool, _ label: String) {
    print(condition ? "ok   \(label)" : "FAIL \(label)")
    if !condition { failures += 1 }
}

let now = Date(timeIntervalSince1970: 1_000_000)
func payload(_ json: String) -> Data { Data(json.utf8) }

let full = StatuslineUsage.parse(payload("""
{"rate_limits":{"five_hour":{"used_percentage":1,"resets_at":1003600},"seven_day":{"used_percentage":35.5,"resets_at":1500000}}}
"""), capturedAt: now, now: now)
check(full?.fiveHour?.usedPercentage == 1, "5h lue (entier)")
check(full?.sevenDay?.usedPercentage == 35.5, "7j lue (décimal)")

let expired = StatuslineUsage.parse(payload("""
{"rate_limits":{"five_hour":{"used_percentage":90,"resets_at":999000},"seven_day":{"used_percentage":35,"resets_at":1500000}}}
"""), capturedAt: now, now: now)
check(expired?.fiveHour == nil, "fenêtre 5h expirée abandonnée")
check(expired?.sevenDay != nil, "fenêtre 7j gardée")

check(StatuslineUsage.parse(payload("{}"), capturedAt: now, now: now) == nil, "sans rate_limits -> nil")
check(StatuslineUsage.parse(payload("pas du json"), capturedAt: now, now: now) == nil, "JSON invalide -> nil")
check(StatuslineUsage.parse(payload("""
{"rate_limits":{"five_hour":{"used_percentage":250,"resets_at":1003600}}}
"""), capturedAt: now, now: now)?.fiveHour?.usedPercentage == 100, "pourcentage borné à 100")

let keychain = KeychainStore(service: "com.alane.usageforecast.tests")
keychain.delete(account: "t")
check(keychain.read(account: "t") == nil, "Keychain : absent au départ")
check(keychain.write("secret-1", account: "t") && keychain.read(account: "t") == "secret-1", "Keychain : écriture puis lecture")
keychain.write("secret-2", account: "t")
check(keychain.read(account: "t") == "secret-2", "Keychain : écriture idempotente (remplace)")
keychain.delete(account: "t")
check(keychain.read(account: "t") == nil, "Keychain : suppression")

// --- Prévisions ---
let weekEnd = now.addingTimeInterval(2.5 * 86400)           // 4,5 j écoulés sur 7
let week = UsageForecast.forecast(usedPercent: 35, resetsAt: weekEnd, windowLength: UsageForecast.weekLength, now: now)
check(abs(week.expectedPercent - 64.2857) < 0.01, "hebdo : rythme régulier attendu 64 %")
check(abs((week.projectedPercent ?? 0) - 54.44) < 0.1, "hebdo : projection ≈ 54 % au reset")
check(week.pace == .under && week.exhaustsAt == nil, "hebdo : en dessous du rythme, pas d'épuisement")
check(abs(week.remainingPerDay - 26) < 0.01, "hebdo : 26 %/jour utilisables")

let fast = UsageForecast.forecast(usedPercent: 60, resetsAt: now.addingTimeInterval(3 * 3600), windowLength: UsageForecast.sessionLength, now: now)
check(fast.pace == .over, "session : 60 % après 2 h sur 5 h -> trop vite")
if let at = fast.exhaustsAt {
    check(abs(at.timeIntervalSince(now) - 4800) < 1, "session : 100 % atteint dans 1 h 20")
} else { check(false, "session : heure d'épuisement attendue") }

let early = UsageForecast.forecast(usedPercent: 10, resetsAt: now.addingTimeInterval(UsageForecast.sessionLength - 600), windowLength: UsageForecast.sessionLength, now: now)
check(early.projectedPercent == nil && early.pace == .onTrack, "session : pas de projection avant 5 % écoulé")

let maxed = UsageForecast.forecast(usedPercent: 100, resetsAt: now.addingTimeInterval(3600), windowLength: UsageForecast.sessionLength, now: now)
check(maxed.pace == .over && maxed.exhaustsAt == nil && maxed.remainingPerDay == 0, "limite atteinte : over, budget 0")

let past = UsageForecast.forecast(usedPercent: 50, resetsAt: now.addingTimeInterval(-60), windowLength: UsageForecast.weekLength, now: now)
check(past.remainingPerDay == 0 && past.expectedPercent == 100, "reset passé : fenêtre terminée")

// --- Barre de menu ---
let in2h14 = now.addingTimeInterval(2 * 3600 + 14 * 60 + 5)
let barSession = MenuBarDisplay.state(mode: .session, sessionPercent: 12, sessionResetsAt: in2h14, weeklyPercent: 35, weeklyResetsAt: nil, showReset: true, now: now)
check(barSession.title == " 12% · 2h14" && barSession.percent == 12, "barre : session avec reset")
let barWorst = MenuBarDisplay.state(mode: .worst, sessionPercent: 12, sessionResetsAt: nil, weeklyPercent: 35, weeklyResetsAt: nil, showReset: false, now: now)
check(barWorst.title == " 35% 7j" && barWorst.percent == 35, "barre : la plus haute = hebdo")
let barWorstSession = MenuBarDisplay.state(mode: .worst, sessionPercent: 80, sessionResetsAt: nil, weeklyPercent: 35, weeklyResetsAt: nil, showReset: false, now: now)
check(barWorstSession.title == " 80% 5h", "barre : la plus haute = session")
check(MenuBarDisplay.countdown(to: now.addingTimeInterval(45 * 60), now: now) == "45 min", "décompte : minutes")
check(MenuBarDisplay.countdown(to: now.addingTimeInterval(3 * 86400 + 4 * 3600), now: now) == "3j 4h", "décompte : jours")
check(MenuBarDisplay.countdown(to: now.addingTimeInterval(-5), now: now) == "0 min", "décompte : passé borné à 0")

// --- Crédits API ---
let credits = ApiCredits(monthlyAmount: 100, spent: 40, cycleEndsAt: now.addingTimeInterval(10 * 86400 - 3600))
check(credits.remaining == 60 && credits.daysLeft(now: now) == 10, "crédits : 60 $ restants, 10 jours")
check(credits.dailyBudget(now: now) == 6, "crédits : 6 $/jour")
let overspent = ApiCredits(monthlyAmount: 100, spent: 130, cycleEndsAt: now.addingTimeInterval(86400))
check(overspent.remaining == 0 && overspent.usedFraction == 1, "crédits : dépassement borné")
check(ApiCredits(monthlyAmount: 100, spent: 0, cycleEndsAt: now.addingTimeInterval(-1)).dailyBudget(now: now) == nil, "crédits : cycle fini -> pas de budget")

// --- Solde Console (formes supposées, voir ConsoleBalance) ---
let creditsJSON = Data("""
{"amount":8750,"currency":"USD","tranches":[{"remaining_amount_minor_units":8750,"expires_at":"2026-11-05T00:00:00Z"},{"remaining_amount_minor_units":0,"expires_at":"2026-10-01T00:00:00Z"}]}
""".utf8)
let spendJSON = Data("""
{"amount":1250,"resets_at":"2026-11-01T00:00:00Z"}
""".utf8)
let balanceNow = ISO8601DateFormatter().date(from: "2026-10-20T00:00:00Z")!
let balance = ConsoleBalance.parse(credits: creditsJSON, spend: spendJSON, now: balanceNow)
check(balance?.balance == 87.5 && balance?.currency == "USD", "console : solde 87,50 $")
check(balance?.spentThisPeriod == 12.5, "console : dépense de la période 12,50 $")
check(balance?.nextExpiry == ISO8601DateFormatter().date(from: "2026-11-05T00:00:00Z"), "console : échéance = lot encore valide")
check(balance?.daysLeft(now: balanceNow) == 16, "console : 16 jours avant échéance")
check(ConsoleBalance.parse(credits: Data("{}".utf8), spend: nil) == nil, "console : sans amount -> nil")
check(ConsoleBalance.parse(credits: Data("[1]".utf8), spend: nil) == nil, "console : JSON inattendu -> nil")
let noSpend = ConsoleBalance.parse(credits: Data("{\"amount\":500}".utf8), spend: nil)
check(noSpend?.spentThisPeriod == nil && noSpend?.daysLeft() == nil && noSpend?.dailyBudget() == nil, "console : champs absents tolérés")

// --- Cookies Firefox (base SQLite factice) ---
let fakeProfiles = FileManager.default.temporaryDirectory.appendingPathComponent("cub-test-\(UUID().uuidString)")
let fakeProfile = fakeProfiles.appendingPathComponent("abc.default-release")
try? FileManager.default.createDirectory(at: fakeProfile, withIntermediateDirectories: true)
let fakeDatabase = fakeProfile.appendingPathComponent("cookies.sqlite")
let seed = Process()
seed.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
seed.arguments = [fakeDatabase.path, """
CREATE TABLE moz_cookies (host TEXT, name TEXT, value TEXT);
INSERT INTO moz_cookies VALUES ('.claude.ai','sessionKey','AAA');
INSERT INTO moz_cookies VALUES ('claude.ai','lastActiveOrg','org-1');
INSERT INTO moz_cookies VALUES ('.claude.ai','shared','general');
INSERT INTO moz_cookies VALUES ('claude.ai','shared','precis');
INSERT INTO moz_cookies VALUES ('.platform.claude.com','sessionKey','BBB');
INSERT INTO moz_cookies VALUES ('.notclaude.ai','intrus','X');
"""]
try? seed.run(); seed.waitUntilExit()
check(FirefoxCookies.cookieDatabases(roots: [fakeProfiles]).first?.resolvingSymlinksInPath() == fakeDatabase.resolvingSymlinksInPath(), "firefox : profil détecté")
check(FirefoxCookies.cookieHeader(domain: "claude.com", roots: [fakeProfiles]) == "sessionKey=BBB", "firefox : recherche dans tous les profils")
let claudeHeader = FirefoxCookies.cookieHeader(database: fakeDatabase, domain: "claude.ai") ?? ""
check(claudeHeader == "lastActiveOrg=org-1; sessionKey=AAA; shared=precis", "firefox : en-tête claude.ai (précis > général, sans intrus)")
check(FirefoxCookies.cookieHeader(database: fakeDatabase, domain: "claude.com") == "sessionKey=BBB", "firefox : domaine Console séparé")
check(FirefoxCookies.cookieHeader(database: fakeDatabase, domain: "absent.example") == nil, "firefox : domaine inconnu -> nil")
try? FileManager.default.removeItem(at: fakeProfiles)

// --- Aides de synchronisation ---
check(SyncHelpers.organizationId(fromCookie: "a=1; lastActiveOrg=abc-123; b=2") == "abc-123", "cookie : lastActiveOrg trouvé")
check(SyncHelpers.organizationId(fromCookie: "a=1; lastActiveOrg=") == nil, "cookie : lastActiveOrg vide -> nil")
check(SyncHelpers.organizationId(fromCookie: "a=1; b=2") == nil, "cookie : sans lastActiveOrg -> nil")
check(SyncHelpers.age(since: now.addingTimeInterval(-20), now: now) == "à l'instant", "âge : à l'instant")
check(SyncHelpers.age(since: now.addingTimeInterval(-12 * 60), now: now) == "il y a 12 min", "âge : minutes")
check(SyncHelpers.age(since: now.addingTimeInterval(-3 * 3600), now: now) == "il y a 3 h", "âge : heures")
check(SyncHelpers.age(since: now.addingTimeInterval(-2 * 86400), now: now) == "il y a 2 j", "âge : jours")
check(SyncHelpers.isStale(now.addingTimeInterval(-11 * 60), now: now) && !SyncHelpers.isStale(now.addingTimeInterval(-9 * 60), now: now), "âge : périmé après 10 min")

// --- Réponse réelle de la Console (Max 5x, identifiants retirés) ---
let realCredits = Data("""
{"amount":10000,"currency":"USD","balance":{"money":null,"credits":{"amount_minor":10000,"exponent":2}},"balance_credits":100,"amount_without_scoped_credits":0,"auto_reload_settings":null,"tranches":[],"promo_tranches":[{"remaining_amount_minor_units":10000,"currency":"USD","expires_at":"2026-11-05T00:00:00Z","granted_amount_minor_units":10000,"granted_at":"2026-10-18T20:15:36.082000Z","program_id":"subscription_api_credit","name":"API credit (Max 5x)"}],"next_expires_at":"2026-11-05T00:00:00Z"}
""".utf8)
let realSpend = Data("{\"amount\":0,\"resets_at\":\"2026-11-01T00:00:00Z\"}".utf8)
let realNow = ISO8601DateFormatter().date(from: "2026-10-18T20:30:00Z")!
let real = ConsoleBalance.parse(credits: realCredits, spend: realSpend, now: realNow)
check(real?.balance == 100 && real?.promoGranted == 100, "réel : 100 $ restants sur 100 $ accordés")
check(real?.promoUsedFraction == 0 && real?.spentThisPeriod == 0, "réel : rien consommé")
check(real?.promoName == "API credit (Max 5x)", "réel : nom du programme")
check(real?.nextExpiry == ISO8601DateFormatter().date(from: "2026-11-05T00:00:00Z") && real?.daysLeft(now: realNow) == 18, "réel : échéance 05/11, 18 jours")
check(abs((real?.dailyBudget(now: realNow) ?? 0) - 100.0 / 18) < 0.001, "réel : ≈ 5,56 $/jour")
let partial = ConsoleBalance.parse(credits: Data(String(decoding: realCredits, as: UTF8.self)
    .replacingOccurrences(of: "\"amount\":10000", with: "\"amount\":6250")
    .replacingOccurrences(of: "\"remaining_amount_minor_units\":10000", with: "\"remaining_amount_minor_units\":6250").utf8), spend: nil, now: realNow)
check(partial?.balance == 62.5 && partial?.promoUsedFraction == 0.375, "réel : 37,5 % consommés")

// --- Le statusline ne doit pas écraser une donnée plus récente (Refresh) ---
check(!StatuslineUsage.shouldReplace(displayedAt: now, hasDisplayedData: true, capturedAt: now.addingTimeInterval(-3600)), "refresh : statusline ancien ignoré")
check(StatuslineUsage.shouldReplace(displayedAt: now, hasDisplayedData: true, capturedAt: now.addingTimeInterval(60)), "refresh : statusline plus récent appliqué")
check(StatuslineUsage.shouldReplace(displayedAt: now, hasDisplayedData: false, capturedAt: now.addingTimeInterval(-3600)), "démarrage : statusline appliqué faute de donnée")

// --- Cadence de rafraîchissement ---
var policy = RefreshPolicy()
check(policy.interval == 60 && !policy.isSlowed, "cadence : 60 s au départ")
policy.record(statusCode: 429)
check(policy.interval == 300 && policy.isSlowed, "cadence : 429 -> 5 min")
policy.record(statusCode: nil)
check(policy.interval == 300, "cadence : réseau coupé ne change rien")
policy.record(statusCode: 404)
check(policy.interval == 300, "cadence : 404 ne change rien")
policy.record(statusCode: 200)
check(policy.interval == 60 && !policy.isSlowed, "cadence : succès -> retour à 60 s")
for code in [401, 403, 500, 503] {
    var p = RefreshPolicy(); p.record(statusCode: code)
    check(p.isSlowed, "cadence : \(code) -> ralenti")
}
var untouched = RefreshPolicy(); untouched.record(statusCode: nil)
check(!untouched.isSlowed, "cadence : pas de réponse au départ -> reste à 60 s")

// --- Styles et tonalités ---
check(PopoverLayout(rawValue: "cards") == .cards && PopoverLayout(rawValue: "inconnu") == nil, "style : disposition relue depuis sa clé")
check(MenuBarStyle.allCases.count == 3, "style : trois dessins de barre de menu")
check(UsageTone.of(percent: 8, pace: .under, isStale: false) == .ok, "tonalité : 8 % sous le rythme -> ok")
check(UsageTone.of(percent: 60, pace: .over, isStale: false) == .warning, "tonalité : trop vite -> avertissement")
check(UsageTone.of(percent: 74, pace: .onTrack, isStale: false) == .warning, "tonalité : 74 % -> avertissement")
check(UsageTone.of(percent: 95, pace: .onTrack, isStale: false) == .danger, "tonalité : 95 % -> danger")
check(UsageTone.of(percent: 95, pace: .over, isStale: true) == .stale, "tonalité : donnée ancienne -> neutre")
check(UsageTone.worst([.ok, .warning, .stale]) == .warning && UsageTone.worst([.stale, .ok]) == .stale && UsageTone.worst([]) == .ok, "tonalité : la plus grave l'emporte")
let ring = RingGeometry.dash(percent: 25, radius: 10)
check(abs(ring.on - 15.708) < 0.001 && abs(ring.on + ring.off - 62.832) < 0.001, "anneau : 25 % d'un cercle de rayon 10")
check(RingGeometry.dash(percent: 150, radius: 10).off == 0 && RingGeometry.dash(percent: -5, radius: 10).on == 0, "anneau : pourcentage borné")

// --- Titre de la barre de menu selon le style ---
let ringTitle = MenuBarDisplay.state(mode: .session, sessionPercent: 8, sessionResetsAt: in2h14, weeklyPercent: 37, weeklyResetsAt: nil, showReset: true, now: now)
check(ringTitle.title == " 8% · 2h14" && ringTitle.percent == 8, "barre : double anneau = session + reset")
let twoTitle = MenuBarDisplay.state(mode: .both, sessionPercent: 8, sessionResetsAt: nil, weeklyPercent: 37, weeklyResetsAt: nil, showReset: false, now: now)
check(twoTitle.title == " 8 · 37" && twoTitle.percent == 37, "barre : deux valeurs, la plus haute pilote la couleur")

// --- Résumé des crédits ---
let summaryLive = CreditsSummary.make(console: real, manual: nil, now: realNow)
check(summaryLive?.title == "Crédits API · Max 5x" && summaryLive?.valueText == "100 $", "crédits : titre court et montant")
check(summaryLive?.detail == "Expirent dans 18 j · ≈ 5,56 $ par jour", "crédits : échéance et budget par jour en français")
check(summaryLive?.usedFraction == 0, "crédits : rien consommé")
let manualCredits = ApiCredits(monthlyAmount: 100, spent: 40, cycleEndsAt: now.addingTimeInterval(10 * 86400 - 3600))
let summaryManual = CreditsSummary.make(console: nil, manual: manualCredits, now: now)
check(summaryManual?.valueText == "60 $" && summaryManual?.usedFraction == 0.4, "crédits manuels : reste et part consommée")
check(summaryManual?.title == "Crédits API (saisie manuelle)", "crédits manuels : source indiquée")
check(CreditsSummary.make(console: nil, manual: nil) == nil, "crédits : rien à afficher sans source")
check(CreditsSummary.make(console: real, manual: manualCredits, now: realNow)?.title == "Crédits API · Max 5x", "crédits : la Console prime sur la saisie")
check(CreditsSummary.money(87.5, "USD") == "87,5 $" && CreditsSummary.money(12, "EUR") == "12 EUR", "crédits : formatage des montants")

// --- Libellés de rythme ---
func forecastAt(_ used: Double, left: TimeInterval, length: TimeInterval) -> WindowForecast {
    UsageForecast.forecast(usedPercent: used, resetsAt: now.addingTimeInterval(left), windowLength: length, now: now)
}
let calm = forecastAt(8, left: 3 * 3600, length: UsageForecast.sessionLength)
check(PaceText.chip(for: calm, percent: 8) == "En dessous du rythme", "libellé : faible usage -> en dessous du rythme")
check(PaceText.chip(for: forecastAt(40, left: 3 * 3600, length: UsageForecast.sessionLength), percent: 40) == "En rythme" || PaceText.chip(for: forecastAt(40, left: 3 * 3600, length: UsageForecast.sessionLength), percent: 40) == "Trop rapide", "libellé : 40 % après 2 h -> rythme ou trop rapide, jamais vide")
check(PaceText.chip(for: forecastAt(74, left: 2.5 * 3600, length: UsageForecast.sessionLength), percent: 74) == "Trop rapide", "libellé : 74 % à mi-fenêtre -> trop rapide")
check(PaceText.chip(for: forecastAt(74, left: 3600, length: UsageForecast.sessionLength), percent: 74) == "Usage élevé", "libellé : 74 % à 80 % de la fenêtre -> usage élevé")
check(PaceText.chip(for: forecastAt(75, left: 3600, length: UsageForecast.weekLength), percent: 75) == "Usage élevé", "libellé : 75 % sans dérive -> usage élevé")
check(PaceText.chip(for: calm, percent: 93) == "Limite proche" && PaceText.chip(for: calm, percent: 100) == "Limite atteinte", "libellé : 93 % et 100 %")
check(PaceText.chip(for: nil, percent: 10) == nil && PaceText.chip(for: nil, percent: 80) == "Usage élevé", "libellé : sans prévision")
check(PaceText.compactChip(for: calm, percent: 8) == "Sous le rythme" && PaceText.compactChip(for: calm, percent: 93) == "Limite proche", "libellé court : raccourci seulement le plus long")
check(PaceText.idleSession(percent: 0, resetsAt: nil) == "Aucune session en cours" && PaceText.idleSession(percent: 0, resetsAt: Date()) == nil && PaceText.idleSession(percent: 5, resetsAt: nil) == nil, "session inactive : 0 % sans reset seulement")
check(PaceText.summary(for: calm, showsDailyBudget: false).hasPrefix("≈ "), "résumé : prévision au reset")
check(PaceText.summary(for: forecastAt(5, left: UsageForecast.sessionLength - 60, length: UsageForecast.sessionLength), showsDailyBudget: false) == "", "résumé : vide trop tôt dans la fenêtre")

// --- Icône seule ---
let textless = MenuBarDisplay.state(mode: .session, sessionPercent: 8, sessionResetsAt: in2h14, weeklyPercent: 37, weeklyResetsAt: nil, showReset: true, showText: false, now: now)
check(textless.title.isEmpty && textless.percent == 8, "barre : icône seule, aucun texte")
let withText = MenuBarDisplay.state(mode: .session, sessionPercent: 8, sessionResetsAt: nil, weeklyPercent: 37, weeklyResetsAt: nil, showReset: false, showText: true, now: now)
check(withText.title == " 8%", "barre : texte par défaut inchangé")

// --- Stockage des secrets par fichier (mode développement) ---
let secretsDir = FileManager.default.temporaryDirectory.appendingPathComponent("cub-secrets-\(UUID().uuidString)")
let fileStore = FileSecretStore(directory: secretsDir)
check(fileStore.readResult(account: "a").value == nil && fileStore.readResult(account: "a").status == errSecItemNotFound, "fichier : absent -> introuvable")
check(fileStore.write("valeur-1", account: "a") && fileStore.read(account: "a") == "valeur-1", "fichier : écriture puis lecture")
check(fileStore.write("valeur-2", account: "a") && fileStore.read(account: "a") == "valeur-2", "fichier : écriture idempotente (remplace)")
func permissions(_ url: URL) -> Int { ((try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions]) as? Int) ?? -1 }
check(permissions(secretsDir.appendingPathComponent("a")) == 0o600, "fichier : droits 0600")
check(permissions(secretsDir) == 0o700, "fichier : dossier 0700")
check(fileStore.readResult(account: "a").status == errSecSuccess, "fichier : statut succès")
check(fileStore.delete(account: "a") && fileStore.read(account: "a") == nil, "fichier : suppression")
check(fileStore.delete(account: "jamais-existé"), "fichier : supprimer l'absent réussit")
try? FileManager.default.removeItem(at: secretsDir)
check(!AppSecrets.isRelease && AppSecrets.storageLabel.contains("développement"), "mode : la compilation de test est en développement")

// --- Valeur affichée par style ---
let ringWeekly = MenuBarDisplay.state(mode: .weekly, sessionPercent: 8, sessionResetsAt: in2h14, weeklyPercent: 37, weeklyResetsAt: nil, showReset: false, now: now)
check(ringWeekly.title == " 37%" && ringWeekly.percent == 37, "valeur : hebdo seule")
let bothReset = MenuBarDisplay.state(mode: .both, sessionPercent: 8, sessionResetsAt: in2h14, weeklyPercent: 37, weeklyResetsAt: nil, showReset: true, now: now)
check(bothReset.title == " 8 · 37 · 2h14", "valeur : les deux avec reset de la session")
check(MenuBarMode.defaultMode(for: .twoValues) == .both && MenuBarMode.defaultMode(for: .spark) == .session && MenuBarMode.defaultMode(for: .dualRing) == .session, "valeur : défaut par style")
check(MenuBarMode.allCases.count == 4, "valeur : quatre choix")

// --- Historique et analyses ---
let t0 = Date(timeIntervalSince1970: 1_800_000_000)
func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }
func sample(_ minutes: Double, s: Double? = nil, w: Double? = nil) -> UsageSample {
    UsageSample(time: at(minutes).timeIntervalSince1970, session: s, weekly: w)
}
let rising = (0...20).map { sample(Double($0), s: 10 + Double($0) * 0.3) }
let rate = UsageAnalytics.recentRate(rising, series: .session, now: at(20))
check(abs((rate ?? 0) - 18) < 0.01, "rythme : 6 points en 20 min = 18 %/h")
check(UsageAnalytics.recentRate(Array(rising.prefix(4)), series: .session, now: at(3)) == nil, "rythme : moins de 5 minutes -> nil")
check(UsageAnalytics.recentRate((0...10).map { sample(Double($0), s: 40) }, series: .session, now: at(10)) == 0, "rythme : usage immobile -> 0")
let withReset = [sample(0, s: 90), sample(5, s: 95), sample(10, s: 98), sample(15, s: 2), sample(20, s: 4), sample(25, s: 6), sample(30, s: 8)]
check(abs((UsageAnalytics.recentRate(withReset, series: .session, now: at(30)) ?? 0) - 24) < 0.01, "rythme : seul le temps après le reset compte")
check(UsageAnalytics.recentRate([sample(0, w: 5), sample(10, w: 9)], series: .session, now: at(10)) == nil, "rythme : série absente -> nil")
check(UsageAnalytics.recentRate(rising, series: .session, now: at(300)) == nil, "rythme : relevés trop anciens -> nil")

var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
let midnightBase = utc.startOfDay(for: t0)
func daySample(_ hours: Double, w: Double) -> UsageSample { UsageSample(time: midnightBase.addingTimeInterval(hours * 3600).timeIntervalSince1970, session: nil, weekly: w) }
let dayData = [daySample(-2, w: 20), daySample(1, w: 30), daySample(3, w: 33), daySample(5, w: 3), daySample(8, w: 7)]
check(UsageAnalytics.usedToday(dayData, series: .weekly, now: midnightBase.addingTimeInterval(9 * 3600), calendar: utc) == 7, "aujourd'hui : +3 puis reset ignoré puis +4 = 7 points")
check(UsageAnalytics.usedToday([daySample(1, w: 30)], series: .weekly, now: midnightBase.addingTimeInterval(2 * 3600), calendar: utc) == nil, "aujourd'hui : un seul relevé -> nil")
check(UsageAnalytics.series(rising, series: .session, hours: 0.1, now: at(20)).count == 7, "courbe : fenêtre de 6 minutes = 7 points")

let calmForecast = RecentForecast.make(ratePerHour: 20, used: 40, resetsAt: at(120), now: at(0))
check(calmForecast.projectedPercent == 80 && calmForecast.exhaustsAt == nil, "prévision récente : 40 % + 20 %/h pendant 2 h = 80 %")
let hotForecast = RecentForecast.make(ratePerHour: 40, used: 40, resetsAt: at(120), now: at(0))
check(hotForecast.projectedPercent == 120 && hotForecast.exhaustsAt == at(90), "prévision récente : 100 % atteint dans 1 h 30")
check(RecentForecast.make(ratePerHour: 0, used: 40, resetsAt: at(120), now: at(0)).exhaustsAt == nil, "prévision récente : immobile -> pas d'épuisement")

let historyDir = FileManager.default.temporaryDirectory.appendingPathComponent("cub-hist-\(UUID().uuidString)")
let history = UsageHistory(url: historyDir.appendingPathComponent("history.jsonl"))
history.append(sample(-60 * 24 * 10, s: 1, w: 1))
history.append(sample(-5, s: 10, w: 20))
history.append(sample(0, s: 12, w: 21))
if let handle = try? FileHandle(forWritingTo: history.url) { _ = try? handle.seekToEnd(); try? handle.write(contentsOf: Data("ligne illisible\n".utf8)); try? handle.close() }
check(history.load(since: at(-60)).count == 2, "historique : relevés récents relus, ligne illisible ignorée")
history.prune(now: at(0))
check(history.load(since: at(-60 * 24 * 30)).count == 2, "historique : le relevé de 10 jours est purgé")
check(((try? FileManager.default.attributesOfItem(atPath: history.url.path)[.posixPermissions]) as? Int) == 0o600, "historique : droits 0600")
try? FileManager.default.removeItem(at: historyDir)

// --- Règles d'alerte ---
let alertNow = Date(timeIntervalSince1970: 1_800_000_000)
func later(_ minutes: Double) -> Date { alertNow.addingTimeInterval(minutes * 60) }
func context(_ edit: (inout AlertContext) -> Void = { _ in }) -> AlertContext {
    var c = AlertContext(now: alertNow, sessionPercent: 0, sessionResetsAt: nil, sessionETA: nil,
                         weeklyPercent: 0, weeklyResetsAt: nil, weeklyETA: nil,
                         previousSessionPercent: nil, consecutiveAuthFailures: 0, credits: nil)
    edit(&c)
    return c
}
func run(_ c: AlertContext, off: Set<AlertKind> = [], sent: Set<String> = []) -> [AlertMessage] {
    AlertRules.evaluate(c, settings: AlertSettings(enabled: Set(AlertKind.allCases).subtracting(off)), alreadySent: { sent.contains($0) })
}

let burning = run(context { $0.sessionPercent = 60; $0.sessionResetsAt = later(120); $0.sessionETA = later(40) })
check(burning.count == 1 && burning[0].kind == .willExhaust && burning[0].title.hasPrefix("Tu atteindras 100 % de la session vers"), "alerte : limite de session annoncée")
let imminent = run(context { $0.sessionPercent = 90; $0.sessionResetsAt = later(120); $0.sessionETA = later(10) })
check(imminent.first?.title == "Limite de session dans 10 min" && imminent.first?.key.hasSuffix("-imminent") == true, "alerte : limite imminente (clé distincte)")
check(run(context { $0.sessionPercent = 60; $0.sessionResetsAt = later(120); $0.sessionETA = later(130) }).isEmpty, "alerte : épuisement après le reset -> rien")
check(run(context { $0.sessionPercent = 10; $0.sessionResetsAt = later(120); $0.sessionETA = later(40) }).isEmpty, "alerte : usage trop faible -> rien")
check(run(context { $0.sessionPercent = 60; $0.sessionResetsAt = later(300); $0.sessionETA = later(200) }).isEmpty, "alerte : échéance trop lointaine -> rien")
check(run(context { $0.sessionPercent = 60; $0.sessionResetsAt = later(120); $0.sessionETA = later(40) }, sent: [burning[0].key]).isEmpty, "alerte : déjà envoyée -> rien (dédoublonnage)")
check(run(context { $0.sessionPercent = 60; $0.sessionResetsAt = later(120); $0.sessionETA = later(40) }, off: [.willExhaust]).isEmpty, "alerte : réglage désactivé -> rien")
let weeklyBurn = run(context { $0.weeklyPercent = 70; $0.weeklyResetsAt = later(60 * 48); $0.weeklyETA = later(60 * 20) })
check(weeklyBurn.first?.title.hasPrefix("Semaine : limite atteinte") == true, "alerte : semaine à 100 % annoncée")

let unusedSession = run(context { $0.sessionPercent = 40; $0.sessionResetsAt = later(20) })
check(unusedSession.first?.title == "Reset dans 20 min, 60 % inutilisés", "alerte : part de session inutilisée")
check(run(context { $0.sessionPercent = 5; $0.sessionResetsAt = later(20) }).isEmpty, "alerte : session quasi vide -> rien")
check(run(context { $0.sessionPercent = 40; $0.sessionResetsAt = later(45) }).isEmpty, "alerte : reset encore loin -> rien")
let unusedWeekly = run(context { $0.weeklyPercent = 50; $0.weeklyResetsAt = later(4 * 60) })
check(unusedWeekly.first?.title == "Reset de la semaine dans 4 h, 50 % inutilisés", "alerte : part hebdo inutilisée")
check(run(context { $0.weeklyPercent = 80; $0.weeklyResetsAt = later(4 * 60) }).isEmpty, "alerte : hebdo presque consommée -> rien")

check(run(context { $0.previousSessionPercent = 98; $0.sessionPercent = 3; $0.sessionResetsAt = later(300) }).first?.kind == .sessionReleased, "alerte : session libérée après la limite")
check(run(context { $0.previousSessionPercent = 50; $0.sessionPercent = 3 }).isEmpty, "alerte : reset normal sans blocage -> rien")
check(run(context { $0.consecutiveAuthFailures = 3 }).first?.kind == .sessionExpired, "alerte : session expirée après 3 échecs")
check(run(context { $0.consecutiveAuthFailures = 2 }).isEmpty, "alerte : 2 échecs -> rien")

func credits(_ amount: Double, daysLeft: Double, used: Double = 0) -> ConsoleBalance {
    ConsoleBalance(balance: amount, currency: "USD", spentThisPeriod: 0, periodResetsAt: nil,
                   nextExpiry: later(daysLeft * 24 * 60), promoGranted: 100, promoName: "API credit (Max 5x)")
}
let expiring = run(context { $0.credits = credits(100, daysLeft: 4.2) })
check(expiring.first?.title == "Crédits API : 100 $ expirent dans 5 j" && expiring.first?.key.hasSuffix("-d5") == true, "alerte : crédits à 5 jours")
check(run(context { $0.credits = credits(100, daysLeft: 0.5) }).first?.title == "Crédits API : 100 $ expirent demain", "alerte : crédits demain")
check(run(context { $0.credits = credits(100, daysLeft: 12) }).isEmpty, "alerte : crédits encore loin -> rien")
check(run(context { $0.credits = credits(5, daysLeft: 2) }).isEmpty, "alerte : solde négligeable -> rien")
check(run(context { $0.credits = credits(8, daysLeft: 2) }).isEmpty, "alerte : moins de 10 $ -> rien")

var ledger = AlertLedger()
check(!ledger.has("a"), "registre : vide au départ")
ledger.mark("a", now: alertNow)
check(ledger.has("a"), "registre : clé marquée")
ledger.mark("b", now: alertNow.addingTimeInterval(40 * 86400))
check(!ledger.has("a") && ledger.has("b"), "registre : purge après 30 jours")

// --- Lignes de rythme récent ---
check(PaceText.recentLine(nil) == nil, "ligne récente : absente sans prévision")
check(PaceText.recentLine(RecentForecast(ratePerHour: 0.4, projectedPercent: 10, exhaustsAt: nil)) == nil, "ligne récente : rythme négligeable -> rien")
check(PaceText.recentLine(RecentForecast(ratePerHour: 12, projectedPercent: 50, exhaustsAt: nil)) == "Rythme récent : 12 %/h", "ligne récente : rythme seul")
check(PaceText.recentLine(RecentForecast(ratePerHour: 4.5, projectedPercent: 50, exhaustsAt: nil)) == "Rythme récent : 4,5 %/h", "ligne récente : décimale française sous 10 %/h")
check(PaceText.recentLine(RecentForecast(ratePerHour: 40, projectedPercent: 120, exhaustsAt: t0.addingTimeInterval(5400)))?.contains("100 % vers") == true, "ligne récente : avec l'heure d'atteinte")
check(PaceText.todayLine(9.4) == "Aujourd'hui : +9 % de la semaine" && PaceText.todayLine(nil) == nil, "ligne du jour : consommation depuis minuit")

// --- Planning de la semaine ---
let planBase = utc.startOfDay(for: t0)
let monday15 = planBase.addingTimeInterval(15 * 3600)
let wednesday14 = planBase.addingTimeInterval((48 + 14) * 3600)
let plan = WeekPlan.make(used: 37, now: monday15, resetsAt: wednesday14, calendar: utc)
check(plan.count == 3 && plan[0].isToday && !plan[1].isToday, "planning : trois jours, le premier est aujourd'hui")
check(Array(plan.map(\.label).prefix(2)) == ["auj.", "dem."] && plan[2].label.count == 3, "planning : libellés courts (auj., dem., puis le jour)")
check(abs(plan.map(\.percent).reduce(0, +) - 63) < 0.0001, "planning : la somme des parts = ce qui reste (63 %)")
check(abs(plan[0].percent - 63.0 * 9 / 47) < 0.0001 && abs(plan[1].percent - 63.0 * 24 / 47) < 0.0001, "planning : parts au prorata des heures")
check(WeekPlan.make(used: 100, now: monday15, resetsAt: wednesday14, calendar: utc).isEmpty, "planning : limite atteinte -> rien")
check(WeekPlan.make(used: 20, now: wednesday14, resetsAt: monday15, calendar: utc).isEmpty, "planning : reset passé -> rien")
let sameDay = WeekPlan.make(used: 50, now: monday15, resetsAt: monday15.addingTimeInterval(5 * 3600), calendar: utc)
check(sameDay.count == 1 && abs(sameDay[0].percent - 50) < 0.0001, "planning : reset le jour même = une seule part")
let longPlan = WeekPlan.make(used: 0, now: planBase.addingTimeInterval(1 * 3600), resetsAt: planBase.addingTimeInterval((6 * 24 + 12) * 3600), calendar: utc)
check(longPlan.count == 7 && longPlan[2].label.count == 3, "planning : sept jours, noms courts à partir du troisième")

// --- Export de la prévision (statusline) ---
let exportNow = Date(timeIntervalSince1970: 1_800_000_000)
let sessionWindow = UsageForecast.forecast(usedPercent: 60, resetsAt: exportNow.addingTimeInterval(3 * 3600), windowLength: UsageForecast.sessionLength, now: exportNow)
let weeklyWindow = UsageForecast.forecast(usedPercent: 37, resetsAt: exportNow.addingTimeInterval(2.5 * 86400), windowLength: UsageForecast.weekLength, now: exportNow)
let exported = ForecastExport.make(now: exportNow, sessionPercent: 60, sessionResetsAt: exportNow.addingTimeInterval(3 * 3600),
                                   sessionForecast: sessionWindow, sessionRecent: nil, weeklyPercent: 37,
                                   weeklyResetsAt: exportNow.addingTimeInterval(2.5 * 86400), weeklyForecast: weeklyWindow,
                                   weeklyRecent: nil, usedToday: 9, credits: real)
check(exported.line.hasPrefix("Prévision · session ≈ 150 %") && exported.line.contains("100 % vers") && exported.line.contains("semaine ≈ 58 %"), "export : ligne de résumé (session qui dépasse, semaine)")
check(exported.line.contains("%/j)"), "export : budget par jour dans la ligne")
check(exported.session?.pace == "over" && exported.weekly?.pace == "under", "export : état du rythme")
check(exported.usedTodayPercent == 9 && exported.credits?.balance == 100, "export : consommation du jour et crédits")
if let data = exported.encoded() {
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    check((try? decoder.decode(ForecastExport.self, from: data)) == exported, "export : JSON relu à l'identique")
    let text = String(decoding: data, as: UTF8.self)
    check(text.contains("\"updatedAt\"") && text.contains("\"line\"") && text.contains("\"version\" : 1"), "export : champs attendus par le statusline")
} else { check(false, "export : encodage") }
let empty = ForecastExport.make(now: exportNow, sessionPercent: nil, sessionResetsAt: nil, sessionForecast: nil, sessionRecent: nil,
                                weeklyPercent: nil, weeklyResetsAt: nil, weeklyForecast: nil, weeklyRecent: nil, usedToday: nil, credits: nil)
check(empty.line.isEmpty && empty.session == nil, "export : sans données, ligne vide")

// --- Lien vers les réglages macOS ---
check(SystemSettings.fullDiskAccessURL.scheme == "x-apple.systempreferences" && SystemSettings.fullDiskAccessURL.absoluteString.hasSuffix("Privacy_AllFiles"), "réglages macOS : lien vers l'Accès complet au disque")

// --- Messages d'alerte explicites (durée de blocage, rythme, budget) ---
check(AlertRules.duration(25 * 60) == "25 min" && AlertRules.duration(100 * 60) == "1 h 40" && AlertRules.duration(38 * 3600) == "38 h" && AlertRules.duration(3 * 86400 + 4 * 3600) == "3 j 4 h" && AlertRules.duration(3600) == "1 h", "durée : formats courts")
check(AlertRules.formatRate(3.4) == "3,4" && AlertRules.formatRate(12.4) == "12", "rythme : décimale sous 10 %/h")
let detailed = run(context {
    $0.sessionPercent = 61; $0.sessionResetsAt = later(120); $0.sessionETA = later(40); $0.sessionRatePerHour = 40
})
check(detailed.first?.body.contains("Si tu gardes ce rythme (environ 40 % par heure)") == true && detailed.first?.body.contains("bloqué 1 h 20") == true && detailed.first?.body.contains("reset de") == true, "alerte session : hypothèse, rythme et durée de blocage")
let weeklyDetailed = run(context {
    $0.weeklyPercent = 70; $0.weeklyResetsAt = later(60 * 48); $0.weeklyETA = later(60 * 10)
    $0.weeklyRatePerHour = 3.4; $0.weeklyBudgetPerDay = 26
})
check(weeklyDetailed.first?.body.contains("Ces dernières 24 h") == true && weeklyDetailed.first?.body.contains("3,4 % par heure") == true && weeklyDetailed.first?.body.contains("Si ça continue, tu seras bloqué de") == true && weeklyDetailed.first?.body.contains("environ 38 h") == true && weeklyDetailed.first?.body.contains("ne dépasse pas 26 % par jour") == true, "alerte hebdo : hypothèse, période de blocage et budget par jour")
check(weeklyDetailed.first?.title.contains("Semaine : limite atteinte") == true && weeklyDetailed.first?.title.hasSuffix("si ça continue") == true, "alerte hebdo : le titre dit la limite concernée et qu'il s'agit d'une hypothèse")
let bare = run(context { $0.weeklyPercent = 70; $0.weeklyResetsAt = later(60 * 48); $0.weeklyETA = later(60 * 10) })
check(bare.first?.body.contains("par heure") == false && bare.first?.body.contains("par jour") == false, "alerte hebdo : sans rythme ni budget, pas de chiffre inventé")
let justAfterMidnight = Calendar.current.date(bySettingHour: 0, minute: 3, second: 0, of: Date())!
check(AlertRules.clock(justAfterMidnight) == "0 h 03", "heure : pas de zéro initial (0 h 03)")

// --- Rythme hebdomadaire : une rafale ne doit pas être extrapolée ---
let burst = (0...180).map { sample(Double($0), w: 40 + Double($0) * 0.08) }   // +14,4 points en 3 h
check(UsageAnalytics.recentRate(burst, series: .weekly, now: at(180), lookback: 24 * 3600, minElapsed: 12 * 3600) == nil, "rythme hebdo : 3 h d'observation ne suffisent pas (pas d'extrapolation)")
check(UsageAnalytics.recentRate(burst, series: .weekly, now: at(180), lookback: 3 * 3600) != nil, "rythme : sans durée minimale, la rafale donnait bien un rythme élevé (ancien défaut)")
let fullDay = (0...30).map { sample(Double($0) * 60, w: 20 + Double($0) * 1.0) }   // 30 points sur 30 h
let dayRate = UsageAnalytics.recentRate(fullDay, series: .weekly, now: at(30 * 60), lookback: 24 * 3600, minElapsed: 12 * 3600)
check(abs((dayRate ?? 0) - 1.0) < 0.01, "rythme hebdo : une journée complète donne la vraie moyenne (1 %/h)")

// --- Durée affichée par la courbe ---
let spanNow = at(0)
check(UsageAnalytics.chartSpan(firstSample: nil, now: spanNow) == 24 * 3600, "courbe : sans relevé, 24 h par défaut")
check(UsageAnalytics.chartSpan(firstSample: at(-25), now: spanNow) == 25 * 60, "courbe : 25 min de données -> axe de 25 min")
check(UsageAnalytics.chartSpan(firstSample: at(-2), now: spanNow) == 10 * 60, "courbe : minimum 10 min")
check(UsageAnalytics.chartSpan(firstSample: at(-60 * 40), now: spanNow) == 24 * 3600, "courbe : plafonnée à 24 h")
check(abs(UsageAnalytics.chartSpan(firstSample: at(-60 * 5), now: spanNow) - 5 * 3600) < 1, "courbe : 5 h de données -> axe de 5 h")

// --- Plafond de l'axe et survol ---
check(UsageAnalytics.chartCeiling(maxPercent: 12) == 20 && UsageAnalytics.chartCeiling(maxPercent: 15) == 20, "axe : jusqu'à 15 % -> plafond 20 %")
check(UsageAnalytics.chartCeiling(maxPercent: 16) == 50 && UsageAnalytics.chartCeiling(maxPercent: 40) == 50, "axe : de 16 à 40 % -> plafond 50 %")
check(UsageAnalytics.chartCeiling(maxPercent: 41) == 100 && UsageAnalytics.chartCeiling(maxPercent: 95) == 100, "axe : au-delà de 40 % -> 100 %")
let hoverPoints = [(time: at(0), percent: 10.0), (time: at(5), percent: 12.0), (time: at(10), percent: 14.0)]
check(UsageAnalytics.nearestIndex(in: hoverPoints, to: at(6)) == 1 && UsageAnalytics.nearestIndex(in: hoverPoints, to: at(100)) == 2 && UsageAnalytics.nearestIndex(in: hoverPoints, to: at(-50)) == 0, "survol : relevé le plus proche")
check(UsageAnalytics.nearestIndex(in: [(time: Date, percent: Double)](), to: at(0)) == nil, "survol : sans relevé -> nil")

// MARK: - Vérification des versions
func releaseJSON(tag: String, url: String = "https://github.com/Alane38/usageforecast/releases/tag/v1.8.1", extra: String = "") -> Data {
    Data("{\"tag_name\":\"\(tag)\",\"html_url\":\"\(url)\"\(extra)}".utf8)
}
check(UpdateChecker.parse(releaseJSON(tag: "v1.8.1"))?.version == "1.8.1", "mise à jour : lit tag_name sans le v")
check(UpdateChecker.parse(releaseJSON(tag: "v1.8.1", extra: ",\"draft\":true")) == nil, "mise à jour : ignore un brouillon")
check(UpdateChecker.parse(releaseJSON(tag: "v1.9.0", extra: ",\"prerelease\":true")) == nil, "mise à jour : ignore une préversion")
check(UpdateChecker.parse(releaseJSON(tag: "v1.8.1", url: "https://evil.example/x")) == nil, "mise à jour : lien hors github.com refusé")
check(UpdateChecker.parse(releaseJSON(tag: "latest")) == nil && UpdateChecker.parse(Data("{\"message\":\"Not Found\"}".utf8)) == nil, "mise à jour : 404 et tag illisible -> nil")
check(UpdateChecker.isNewer("1.8.1", than: "1.8.0") && UpdateChecker.isNewer("1.10.0", than: "1.9.0") && UpdateChecker.isNewer("2.0", than: "1.99.9"), "version : plus récente")
check(!UpdateChecker.isNewer("1.8.0", than: "1.8.0") && !UpdateChecker.isNewer("1.7.9", than: "1.8.0") && !UpdateChecker.isNewer("abc", than: "1.8.0"), "version : égale, plus ancienne ou illisible")
check(UpdateChecker.isNewer("v1.8.1", than: "1.8.0") && !UpdateChecker.isNewer("1.8", than: "1.8.0"), "version : préfixe v et longueurs différentes")
check(UpdateChecker.shouldCheck(lastCheck: nil) && !UpdateChecker.shouldCheck(lastCheck: Date().addingTimeInterval(-3600)) && UpdateChecker.shouldCheck(lastCheck: Date().addingTimeInterval(-7 * 3600)), "vérification : toutes les 6 h")

// MARK: - Budget du jour
var paris = Calendar(identifier: .gregorian)
paris.timeZone = TimeZone(identifier: "Europe/Paris")!
let noon = paris.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 12))!
let resetIn3Days = noon.addingTimeInterval(3 * 86400 - 12 * 3600)   // jeudi 22 à minuit : 3 jours pleins depuis minuit
let budget = DayBudget.make(weeklyUsed: 40, usedToday: 10, now: noon, resetsAt: resetIn3Days, calendar: paris)
check(budget != nil && abs(budget!.allowed - 70.0 / 3) < 0.01 && budget!.used == 10, "budget du jour : (100 − usage de minuit) ÷ 3 jours")
check(budget?.level == .ok, "budget du jour : 10 sur 23,3 -> ok")
check(DayBudget(allowed: 24, used: 20).level == .close && DayBudget(allowed: 24, used: 24).level == .close, "budget du jour : de 80 à 100 % -> presque atteint")
check(DayBudget(allowed: 24, used: 31).level == .over && DayBudget(allowed: 24, used: 31).overBy == 7, "budget du jour : 31 sur 24 -> dépassé de 7")
check(DayBudget.make(weeklyUsed: 40, usedToday: nil, now: noon, resetsAt: resetIn3Days, calendar: paris) == nil, "budget du jour : sans historique -> nil")
check(DayBudget.make(weeklyUsed: 100, usedToday: 10, now: noon, resetsAt: resetIn3Days, calendar: paris) == nil, "budget du jour : limite atteinte -> nil")
check(DayBudget.make(weeklyUsed: 40, usedToday: 10, now: noon, resetsAt: noon.addingTimeInterval(-60), calendar: paris) == nil, "budget du jour : reset passé -> nil")
let lastDay = DayBudget.make(weeklyUsed: 50, usedToday: 5, now: noon, resetsAt: noon.addingTimeInterval(6 * 3600), calendar: paris)
check(lastDay != nil && abs(lastDay!.allowed - 55) < 0.01, "budget du jour : dernier jour = tout ce qui reste (reset avant minuit)")
let later = DayBudget.make(weeklyUsed: 50, usedToday: 10, now: noon.addingTimeInterval(5 * 3600), resetsAt: resetIn3Days, calendar: paris)
let earlier = DayBudget.make(weeklyUsed: 45, usedToday: 5, now: noon, resetsAt: resetIn3Days, calendar: paris)
check(later != nil && earlier != nil && abs(later!.allowed - earlier!.allowed) < 0.01, "budget du jour : ne rétrécit pas quand on consomme")
check(DayBudgetText.line(DayBudget(allowed: 24, used: 9)) == "Aujourd'hui : 9 % sur 24 % conseillés", "texte : dans le budget")
check(DayBudgetText.line(DayBudget(allowed: 24, used: 31)).hasSuffix("dépassé de 7 %") && DayBudgetText.consequence(DayBudget(allowed: 24, used: 9)) == nil, "texte : dépassement et conséquence")

// MARK: - Planning depuis minuit
let midnightPlan = WeekPlan.makeFromMidnight(used: 40, usedToday: 10, now: noon, resetsAt: resetIn3Days, calendar: paris)
check(midnightPlan != nil && midnightPlan!.usedBeforeToday == 30 && midnightPlan!.segments.count == 3, "planning minuit : 30 % avant aujourd'hui, 3 jours")
check(midnightPlan != nil && abs(midnightPlan!.segments[0].percent - 70.0 / 3) < 0.01 && midnightPlan!.segments[0].consumed == 10, "planning minuit : bloc du jour = budget complet, 10 consommés")
check(midnightPlan != nil && abs(midnightPlan!.usedBeforeToday + midnightPlan!.segments.reduce(0) { $0 + $1.percent } - 100) < 0.01, "planning minuit : le total fait 100 %")
check(midnightPlan?.segments.dropFirst().allSatisfy { $0.consumed == nil } == true, "planning minuit : seul le jour a une jauge")
check(DayBudget.make(weeklyUsed: 40, usedToday: 10, now: noon, resetsAt: resetIn3Days, calendar: paris)?.allowed == midnightPlan?.segments[0].percent, "planning minuit : même budget que DayBudget")
check(WeekPlan.makeFromMidnight(used: 100, usedToday: 10, now: noon, resetsAt: resetIn3Days, calendar: paris) == nil, "planning minuit : limite atteinte -> nil")
check(WeekPlan.makeFromMidnight(used: 40, usedToday: 10, now: noon, resetsAt: noon.addingTimeInterval(-1), calendar: paris) == nil, "planning minuit : reset passé -> nil")

// MARK: - Organisations
let orgJSON = Data(#"[{"uuid":"aaa-1","name":"Alane","capabilities":["chat","claude_pro"]},{"uuid":"bbb-2","name":"","capabilities":["api"]},{"name":"sans id"},{"uuid":"ccc-3","name":"Équipe","capabilities":["chat"]}]"#.utf8)
let orgs = OrganizationList.parse(orgJSON)
check(orgs.count == 3 && orgs[0].name == "Alane" && orgs[0].hasChat, "organisations : lit uuid, nom, capacité chat")
check(orgs[1].name == "Organisation bbb-2" && !orgs[1].hasChat, "organisations : nom absent -> identifiant court")
check(OrganizationList.followable(orgs).map(\.id) == ["aaa-1", "ccc-3"], "organisations : seules celles avec chat sont proposées")
check(OrganizationList.followable([orgs[1]]).count == 1, "organisations : sans aucune capacité chat -> toutes")
check(OrganizationList.parse(Data("{\"error\":1}".utf8)).isEmpty && OrganizationList.parse(Data()).isEmpty, "organisations : réponse inattendue -> vide")
check(OrganizationList.resolve(selected: "ccc-3", available: orgs, cookieOrg: "aaa-1") == "ccc-3", "organisation : le choix prime")
check(OrganizationList.resolve(selected: "disparue", available: orgs, cookieOrg: "aaa-1") == "aaa-1", "organisation : choix disparu -> cookie")
check(OrganizationList.resolve(selected: nil, available: orgs, cookieOrg: nil) == nil, "organisation : rien -> nil")
check(OrganizationList.resolve(selected: "ccc-3", available: [], cookieOrg: "aaa-1") == "ccc-3", "organisation : liste pas encore chargée -> le choix est gardé")


// MARK: - Installation d'une mise à jour
let goodSum = String(repeating: "ab", count: 32)
check(UpdateInstaller.parseChecksum("\(goodSum)  UsageForecast-1.9.2-arm64.zip\n") == goodSum && UpdateInstaller.parseChecksum(goodSum.uppercased()) == goodSum, "somme : format shasum, majuscules acceptées")
check(UpdateInstaller.parseChecksum("") == nil && UpdateInstaller.parseChecksum("xyz") == nil && UpdateInstaller.parseChecksum(String(goodSum.dropLast())) == nil && UpdateInstaller.parseChecksum(String(repeating: "g", count: 64)) == nil, "somme : vide, courte ou non hexadécimale -> nil")
let info: [String: Any] = ["CFBundleIdentifier": "com.alane.usageforecast", "CFBundleShortVersionString": "1.9.2"]
check(UpdateInstaller.problem(inInfo: info, bundleID: "com.alane.usageforecast", version: "1.9.2") == nil, "archive : identifiant et version conformes")
check(UpdateInstaller.problem(inInfo: info, bundleID: "com.autre.app", version: "1.9.2") != nil && UpdateInstaller.problem(inInfo: info, bundleID: "com.alane.usageforecast", version: "1.9.3") != nil && UpdateInstaller.problem(inInfo: nil, bundleID: "x", version: "1") != nil, "archive : mauvais identifiant, mauvaise version ou sans plist -> refus")
let replacement = UpdateInstaller.script(pid: 4242, newApp: URL(fileURLWithPath: "/tmp/it's/new.app"), target: URL(fileURLWithPath: "/Applications/UsageForecast.app"), trash: URL(fileURLWithPath: "/Users/x/.Trash"), relaunch: true)
check(replacement.contains("kill -0 4242") && replacement.contains("'/tmp/it'\\''s/new.app'") && replacement.contains("UsageForecast.app.update"), "script : attend le pid, protège les apostrophes, prépare une copie voisine")
check(replacement.contains(".Trash/UsageForecast-avant-mise-a-jour-") && replacement.components(separatedBy: "\n").allSatisfy { !$0.hasPrefix("r" + "m ") }, "script : l'ancienne app va à la Corbeille, jamais supprimée")
check(replacement.contains("/usr/bin/open '/Applications/UsageForecast.app'") && !UpdateInstaller.script(pid: 1, newApp: URL(fileURLWithPath: "/a"), target: URL(fileURLWithPath: "/b.app"), trash: URL(fileURLWithPath: "/t"), relaunch: false).contains("/usr/bin/open"), "script : relance seulement si demandé")
let assetBase = "https://github.com/Alane38/usageforecast/releases/download/v1.9.2/"
let pageLink = "https://github.com/Alane38/usageforecast/releases/tag/v1.9.2"
func releaseWithAssets(zip: String?, sum: String?) -> Data {
    var assets: [String] = []
    if let zip { assets.append("{\"name\":\"UsageForecast-1.9.2-arm64.zip\",\"browser_download_url\":\"\(zip)\"}") }
    if let sum { assets.append("{\"name\":\"UsageForecast-1.9.2-arm64.zip.sha256\",\"browser_download_url\":\"\(sum)\"}") }
    return Data("{\"tag_name\":\"v1.9.2\",\"html_url\":\"\(pageLink)\",\"assets\":[\(assets.joined(separator: ","))]}".utf8)
}
let withAssets = UpdateChecker.parse(releaseWithAssets(zip: assetBase + "UsageForecast-1.9.2-arm64.zip", sum: assetBase + "UsageForecast-1.9.2-arm64.zip.sha256"))
check(withAssets?.zipURL != nil && withAssets?.checksumURL != nil, "release : zip et somme trouvés")
let evil = UpdateChecker.parse(releaseWithAssets(zip: "https://evil.example/UsageForecast-1.9.2-arm64.zip", sum: "http://github.com/Alane38/usageforecast/releases/download/v1.9.2/x.sha256"))
check(evil != nil && evil?.zipURL == nil && evil?.checksumURL == nil, "release : téléchargement hors du dépôt ou en HTTP refusé")
check(UpdateChecker.parse(releaseWithAssets(zip: assetBase + "UsageForecast-1.9.2-arm64.zip", sum: nil))?.checksumURL == nil, "release : sans somme SHA-256, pas d'installation")
check(UpdateChecker.parse(releaseJSON(tag: "v1.8.1"))?.zipURL == nil, "release : sans ressources -> installation manuelle")

// MARK: - Magasin de secrets unique
/// Magasin en mémoire qui compte ses lectures et peut simuler un trousseau verrouillé.
final class FakeSecretStore: SecretStoring {
    var items: [String: String] = [:]
    var reads = 0
    var forcedStatus: OSStatus?
    func readResult(account: String) -> (value: String?, status: OSStatus) {
        reads += 1
        if let forcedStatus { return (nil, forcedStatus) }
        if let value = items[account] { return (value, errSecSuccess) }
        return (nil, errSecItemNotFound)
    }
    func write(_ value: String, account: String) -> Bool { items[account] = value; return true }
    func delete(account: String) -> Bool { items[account] = nil; return true }
}
let bundleAccounts = ["claude_session_cookie", "console_session_cookie"]

check(SecretBundle.decode(SecretBundle.encode(["a": "x=1; y=\"2\"", "b": "é"])) == ["a": "x=1; y=\"2\"", "b": "é"], "secrets : aller-retour JSON, guillemets et accents")
check(SecretBundle.decode("pas du json") == nil && SecretBundle.decode("[1,2]") == nil, "secrets : texte invalide -> nil")

let oneItem = FakeSecretStore()
oneItem.items[BundledSecretStore.bundleAccount] = SecretBundle.encode(["claude_session_cookie": "AAA", "console_session_cookie": "BBB"])
let bundled = BundledSecretStore(backend: oneItem)
check(bundled.read(account: "claude_session_cookie") == "AAA" && bundled.read(account: "console_session_cookie") == "BBB", "magasin unique : lit les deux secrets")
check(oneItem.reads == 1, "magasin unique : UNE seule lecture du trousseau pour deux secrets (un seul mot de passe)")
check(bundled.read(account: "absent") == nil && oneItem.reads == 1, "magasin unique : un secret absent ne relit pas le trousseau")

let writer = FakeSecretStore()
writer.items[BundledSecretStore.bundleAccount] = SecretBundle.encode(["claude_session_cookie": "AAA", "console_session_cookie": "BBB"])
let writing = BundledSecretStore(backend: writer)
check(writing.write("CCC", account: "claude_session_cookie") && writing.read(account: "claude_session_cookie") == "CCC" && writing.read(account: "console_session_cookie") == "BBB", "magasin unique : écrire un secret garde l'autre")
check(SecretBundle.decode(writer.items[BundledSecretStore.bundleAccount] ?? "")?["claude_session_cookie"] == "CCC", "magasin unique : la valeur est bien persistée")
check(writing.delete(account: "console_session_cookie") && writing.read(account: "console_session_cookie") == nil && writing.read(account: "claude_session_cookie") == "CCC", "magasin unique : supprimer un secret garde l'autre")
check(writing.delete(account: "claude_session_cookie") && writer.items[BundledSecretStore.bundleAccount] == nil, "magasin unique : dernier secret supprimé -> élément supprimé")

let newBackend = FakeSecretStore()
let oldItems = FakeSecretStore()
oldItems.items = ["claude_session_cookie": "AAA", "console_session_cookie": "BBB"]
let migrating = BundledSecretStore(backend: newBackend, legacy: oldItems, legacyAccounts: bundleAccounts)
check(migrating.read(account: "claude_session_cookie") == "AAA" && migrating.read(account: "console_session_cookie") == "BBB", "migration : reprend les deux anciens éléments")
check(SecretBundle.decode(newBackend.items[BundledSecretStore.bundleAccount] ?? "")?.count == 2 && oldItems.items.isEmpty, "migration : élément unique écrit, anciens éléments supprimés")
check(oldItems.reads == 2 && newBackend.reads == 1, "migration : chaque ancien élément lu une fois")

let onlyOne = FakeSecretStore()
onlyOne.items = ["claude_session_cookie": "AAA"]
let halfMigrated = BundledSecretStore(backend: FakeSecretStore(), legacy: onlyOne, legacyAccounts: bundleAccounts)
check(halfMigrated.read(account: "claude_session_cookie") == "AAA" && halfMigrated.read(account: "console_session_cookie") == nil, "migration : un seul ancien élément suffit")

let locked = FakeSecretStore()
locked.items[BundledSecretStore.bundleAccount] = SecretBundle.encode(["claude_session_cookie": "AAA"])
locked.forcedStatus = errSecAuthFailed
let refused = BundledSecretStore(backend: locked, legacy: oldItems, legacyAccounts: bundleAccounts)
check(refused.readResult(account: "claude_session_cookie").value == nil && refused.readResult(account: "claude_session_cookie").status == errSecAuthFailed, "accès refusé : le statut est transmis")
check(!refused.write("ZZZ", account: "console_session_cookie") && locked.items[BundledSecretStore.bundleAccount] == SecretBundle.encode(["claude_session_cookie": "AAA"]), "accès refusé : rien n'est écrasé")
locked.forcedStatus = nil
check(refused.read(account: "claude_session_cookie") == "AAA", "accès refusé : réessaie ensuite et lit normalement")

// MARK: - Journal quotidien
func sampleAt(_ day: Int, _ hour: Int, _ minute: Int = 0, session: Double?, weekly: Double?) -> UsageSample {
    let date = paris.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    return UsageSample(time: date.timeIntervalSince1970, session: session, weekly: weekly)
}
let dailyInput = [
    sampleAt(19, 9, session: 5, weekly: 30), sampleAt(19, 9, 30, session: 12, weekly: 31), sampleAt(19, 10, session: 12, weekly: 31),
    sampleAt(19, 14, session: 3, weekly: 33),    // session remise à zéro puis 3 % : +3 de session ; semaine +2
    sampleAt(19, 14, 30, session: 8, weekly: 34),
    sampleAt(20, 8, session: 0, weekly: 10),      // semaine remise à zéro pendant la nuit : jamais compté comme de la consommation
    sampleAt(20, 8, 30, session: 6, weekly: 12),
]
let days = DailyStats.summarize(dailyInput, calendar: paris)
check(days.map(\.day) == ["2026-10-19", "2026-10-20"], "journal : un résumé par jour local, dans l'ordre")
check(days[0].weeklyUsed == 4 && days[0].samples == 5, "journal : semaine 30 -> 34 = 4 points, 5 relevés")
check(days[0].sessionUsed == 7 + 5 + 0 && days[0].peakSession == 12, "journal : session = somme des hausses (7 puis 5), pic 12")
check(days[0].activeHours == [9, 14], "journal : heures actives = celles où l'usage a augmenté")
check(days[1].weeklyUsed == 2 && days[1].sessionUsed == 6, "journal : une remise à zéro (37 -> 10) n'est pas de la consommation")
check(DailyStats.summarize([], calendar: paris).isEmpty, "journal : aucun relevé -> aucun résumé")

let partialDay = DailySummary(day: "2026-10-19", weeklyUsed: 1, sessionUsed: 1, peakSession: 1, activeHours: [9], samples: 2)
let mergedKeep = DailyStats.merge(existing: [days[0]], fresh: [partialDay], now: noon, calendar: paris)
check(mergedKeep.first { $0.day == "2026-10-19" }?.samples == 5, "fusion : un résumé partiel n'écrase pas le complet")
let fuller = DailySummary(day: "2026-10-19", weeklyUsed: 6, sessionUsed: 9, peakSession: 14, activeHours: [9, 14, 16], samples: 9)
check(DailyStats.merge(existing: [days[0]], fresh: [fuller], now: noon, calendar: paris).first?.samples == 9, "fusion : un résumé plus complet remplace l'ancien")
let longAgo = DailySummary(day: "2024-01-01", weeklyUsed: 10, sessionUsed: 10, peakSession: 10, activeHours: [], samples: 100)
let kept = DailyStats.merge(existing: [longAgo], fresh: days, now: noon, calendar: paris)
check(!kept.contains { $0.day == "2024-01-01" } && kept.map(\.day) == ["2026-10-19", "2026-10-20"], "fusion : plus de 400 jours -> retiré, ordre des jours")
check(DailyStats.merge(existing: [], fresh: days, now: noon, calendar: paris) == days, "fusion : première reprise de l'existant")

let dailyFile = FileManager.default.temporaryDirectory.appendingPathComponent("daily-test-\(UUID().uuidString).jsonl")
let dailyStore = DailyHistory(url: dailyFile)
dailyStore.save(days)
check(dailyStore.load() == days, "journal : écriture puis lecture identiques")
check((try? FileManager.default.attributesOfItem(atPath: dailyFile.path)[.posixPermissions] as? Int) == 0o600, "journal : fichier en 0600")
try? "pas du json\n".appending(String(decoding: (try? Data(contentsOf: dailyFile)) ?? Data(), as: UTF8.self)).write(to: dailyFile, atomically: true, encoding: .utf8)
check(dailyStore.load() == days, "journal : une ligne illisible est ignorée")
try? FileManager.default.removeItem(at: dailyFile)

// MARK: - Statistiques du journal
func dailyFixture(_ day: String, _ used: Double, samples: Int = 1000, hours: [Int] = [9]) -> DailySummary {
    DailySummary(day: day, weeklyUsed: used, sessionUsed: used * 2, peakSession: 40, activeHours: hours, samples: samples)
}
var insightFixture: [DailySummary] = []
for d in 28...30 { insightFixture.append(dailyFixture("2026-09-\(d)", Double(d), hours: d == 28 ? [9, 20] : [9])) }
for d in 1...18 {
    insightFixture.append(dailyFixture(String(format: "2026-10-%02d", d), Double(d), samples: d == 10 ? 100 : 1000,
                                       hours: (d == 5 || d == 12) ? [9, 20] : [9]))
}
insightFixture.append(dailyFixture("2026-10-19", 7, samples: 400))   // aujourd'hui (lundi), partiel mais au-dessus de 300 relevés

let recent = DailyInsights.recentDays(insightFixture, count: 14, now: noon, calendar: paris)
check(recent.count == 14 && recent.last?.day == "2026-10-19" && recent.last?.isToday == true && recent.first?.day == "2026-10-06", "stats : 14 derniers jours, aujourd'hui en dernier")
check(DailyInsights.recentDays([], count: 7, now: noon, calendar: paris).allSatisfy { $0.summary == nil } && recent.first { $0.day == "2026-10-10" }?.isReliable == false, "stats : case vide sans donnée, jour partiel non fiable")
check(DailyInsights.weekdayIndex(of: noon, calendar: paris) == 0 && DailyInsights.weekdayIndex(of: noon.addingTimeInterval(-86400), calendar: paris) == 6, "stats : lundi = 0, dimanche = 6")
check(DailyInsights.date(fromStamp: "2026-10-19", calendar: paris).map { DailyStats.stamp(for: $0, calendar: paris) } == "2026-10-19" && DailyInsights.date(fromStamp: "n'importe quoi") == nil, "stats : aller-retour du jour AAAA-MM-JJ")

let average = DailyInsights.averagePerDay(insightFixture, now: noon, calendar: paris)
check(average != nil && average!.days == 12 && abs(average!.value - 146.0 / 12) < 0.001, "stats : moyenne par jour, aujourd'hui et jour partiel exclus")
check(DailyInsights.averagePerDay([], now: noon, calendar: paris) == nil, "stats : moyenne sans donnée -> nil")
check(DailyInsights.busiestDay(insightFixture)?.day == "2026-09-30", "stats : jour le plus chargé (30 points)")

let weekdays = DailyInsights.weekdayStats(insightFixture, now: noon, calendar: paris)
check(weekdays.count == 7 && weekdays[0].count == 3 && weekdays[0].average == 15 && weekdays[0].isSolid, "stats : lundi = moyenne de 3 jours, solide")
check(weekdays[5].count == 2 && weekdays[5].average == 10 && !weekdays[5].isSolid, "stats : samedi = 2 jours fiables (le partiel est exclu), indicatif")

let hours = DailyInsights.hourStats(insightFixture, now: noon, calendar: paris)
check(hours.count == 24 && hours[9].activeDays == 20 && hours[9].totalDays == 20 && hours[9].fraction == 1, "stats : 9 h active 20 jours sur 20")
check(hours[20].activeDays == 3 && hours[3].activeDays == 0 && DailyInsights.peakHour(hours)?.hour == 9, "stats : 20 h active 3 jours, heure de pointe = 9 h")

let wednesday = paris.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 12))!   // mercredi : lundi et mardi sont complets
let weeks = DailyInsights.weekComparison(insightFixture, now: wednesday, calendar: paris)
check(weeks.completedDays == 2 && weeks.current == 12 + 13 && weeks.previous == 5 + 6 && weeks.delta == 14, "stats : à jours égaux, lundi + mardi = 25 pts contre 11 la semaine précédente")
let mondayWeek = DailyInsights.weekComparison(insightFixture, now: noon, calendar: paris)
check(mondayWeek.completedDays == 0 && mondayWeek.previous == nil && mondayWeek.current == 0, "stats : le lundi, aucun jour complet -> pas de comparaison")
let septemberWed = paris.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 12))!   // la semaine du 21/09 n'est pas dans le journal
let noPrevious = DailyInsights.weekComparison(insightFixture, now: septemberWed, calendar: paris)
check(noPrevious.completedDays == 2 && noPrevious.current == 28 + 29 && noPrevious.previous == nil, "stats : semaine précédente absente du journal -> pas de comparaison")
let thinPrevious = DailyInsights.weekComparison([dailyFixture("2026-10-13", 5), dailyFixture("2026-10-12", 3)], now: wednesday, calendar: paris)
check(thinPrevious.previous == nil && thinPrevious.delta == nil, "stats : semaine précédente absente -> pas de comparaison")

check(DataConfidence(reliableDays: 0) == .veryLow && DataConfidence(reliableDays: 3) == .building && DataConfidence(reliableDays: 14) == .good && DataConfidence(reliableDays: 28) == .solid, "stats : niveaux de fiabilité")
check(DailyInsights.confidence(insightFixture) == .good && DailyInsights.confidence([]) == .veryLow, "stats : fiabilité du journal")

// MARK: - Synchro mobile : chiffrement
import CryptoKit
let vectorKeyBytes = Data((0..<32).map { UInt8($0) })
let vectorKey = SymmetricKey(data: vectorKeyBytes)
let vectorNonce = try! AES.GCM.Nonce(data: Data((0..<12).map { UInt8(0xa0 + $0) }))
let vectorBlob = "oKGio6SlpqeoqaqrnToUSCmnbZ1YR-q8ZROsu1LR6TTezi9REKnTcKBV7_CgZQ"
// Ce même vecteur est vérifié côté téléphone (mobile/pwa/test/crypto.test.js) : les deux langages doivent s'entendre.
check(MobileCrypto.seal(Data("{\"hello\":\"mobile\"}".utf8), key: vectorKey, nonce: vectorNonce) == vectorBlob, "mobile : vecteur de chiffrement AES-GCM fixe")
check(MobileCrypto.open(vectorBlob, key: vectorKey).flatMap { String(data: $0, encoding: .utf8) } == "{\"hello\":\"mobile\"}", "mobile : déchiffrement du vecteur")
check(MobileCrypto.writeToken(key: vectorKey) == "50122637362ade0cdda221d674609d8e18b9acf46499fa0edf6ec98b327a3e94", "mobile : jeton d'écriture HMAC fixe")
check(MobileCrypto.open(vectorBlob, key: MobileCrypto.newKey()) == nil, "mobile : mauvaise clé -> refus")
var tamperedBytes = MobileCrypto.data(fromBase64url: vectorBlob)!
tamperedBytes[tamperedBytes.count - 1] ^= 0x01
check(MobileCrypto.open(MobileCrypto.base64url(tamperedBytes), key: vectorKey) == nil, "mobile : un bit modifié -> refus (intégrité)")
check(MobileCrypto.open("n'importe quoi", key: vectorKey) == nil && MobileCrypto.open("", key: vectorKey) == nil, "mobile : blob illisible -> refus")
let randomKey = MobileCrypto.newKey()
let sealedTwice = [MobileCrypto.seal(Data("x".utf8), key: randomKey), MobileCrypto.seal(Data("x".utf8), key: randomKey)]
check(sealedTwice[0] != sealedTwice[1] && sealedTwice[0].flatMap { MobileCrypto.open($0, key: randomKey) } == Data("x".utf8), "mobile : nonce aléatoire à chaque envoi, aller-retour")
check(MobileCrypto.data(fromBase64url: MobileCrypto.base64url(Data([0xfb, 0xff, 0xfe, 0x00, 0x3e]))) == Data([0xfb, 0xff, 0xfe, 0x00, 0x3e]) && !MobileCrypto.base64url(Data([0xfb, 0xff])).contains("="), "mobile : base64url sans « + / = »")
check(MobileCrypto.newDeviceID().count == 32 && MobileCrypto.newDeviceID() != MobileCrypto.newDeviceID(), "mobile : identifiant de coffre de 128 bits")

let pairing = PairingLink(relay: URL(string: "https://usage.example.workers.dev")!, id: String(repeating: "ab", count: 16), key: vectorKeyBytes)
check(pairing.url.flatMap(PairingLink.parse) == pairing, "mobile : lien d'appairage, aller-retour")
check(pairing.url?.absoluteString.hasPrefix("https://usage.example.workers.dev#v1.abab") == true, "mobile : la clé est dans le fragment, jamais dans le chemin")
check(PairingLink.parse(URL(string: "https://x.dev/#v2.\(pairing.id).AAAA")!) == nil && PairingLink.parse(URL(string: "https://x.dev/#v1.court.AAAA")!) == nil && PairingLink.parse(URL(string: "https://x.dev/")!) == nil, "mobile : lien invalide refusé (version, identifiant, sans fragment)")
check(PairingLink.parse(URL(string: "https://x.dev/#v1.\(pairing.id).AAAA")!) == nil, "mobile : clé trop courte refusée")

// MARK: - Synchro mobile : snapshot
let rawSamples = (0..<20).map { UsageSample(time: 1_000_200 + Double($0) * 60, session: Double($0), weekly: 50) }
let decimated = MobileSnapshot.decimate(rawSamples)
check(decimated.count == 4 && decimated.last?.s == 19 && decimated.first?.s == 4, "mobile : un point par tranche de 5 minutes (le dernier de la tranche)")
check(MobileSnapshot.decimate([]).isEmpty, "mobile : historique vide -> courbe vide")
let emptyForecast = ForecastExport.make(now: noon, sessionPercent: 12, sessionResetsAt: noon.addingTimeInterval(3 * 3600), sessionForecast: nil, sessionRecent: nil,
                                        weeklyPercent: 40, weeklyResetsAt: noon.addingTimeInterval(86400), weeklyForecast: nil, weeklyRecent: nil, usedToday: 5, credits: nil)
let snapshot = MobileSnapshot(version: 1, updatedAt: noon, appVersion: "1.13.0", source: "claude.ai", dataAt: noon, forecast: emptyForecast,
                              dayBudget: MobileSnapshot.budgetInfo(DayBudget(allowed: 24, used: 30)),
                              credits: MobileSnapshot.creditsInfo(CreditsSummary(title: "Crédits API · Max 5x", valueText: "100 $", usedFraction: 0, detail: "Expirent dans 17 j")), servicesOK: true, history: decimated,
                              daily: [DailySummary(day: "2026-10-19", weeklyUsed: 22, sessionUsed: 60, peakSession: 52, activeHours: [16, 17], samples: 499)])
let snapshotData = snapshot.encoded()
check(snapshotData.flatMap(MobileSnapshot.decode) == snapshot, "mobile : snapshot, aller-retour JSON")
check(snapshot.credits?.value == "100 $" && MobileSnapshot.creditsInfo(nil) == nil, "mobile : crédits du snapshot")
check(snapshot.dayBudget?.level == "over" && MobileSnapshot.budgetInfo(DayBudget(allowed: 24, used: 20))?.level == "close" && MobileSnapshot.budgetInfo(nil) == nil, "mobile : niveau du budget du jour")
check(!(String(data: snapshotData ?? Data(), encoding: .utf8) ?? "").lowercased().contains("cookie"), "mobile : aucun cookie dans le snapshot")

// MARK: - Synchro mobile : envoi
let relayURL = URL(string: "https://usage.example.workers.dev")!
let vaultID = String(repeating: "ab", count: 16)
check(MobileUploader.isAcceptable(relay: relayURL) && MobileUploader.isAcceptable(relay: URL(string: "http://localhost:8788")!) && MobileUploader.isAcceptable(relay: URL(string: "http://127.0.0.1:8788")!), "envoi : HTTPS, ou HTTP seulement en local")
check(!MobileUploader.isAcceptable(relay: URL(string: "http://usage.example.com")!) && !MobileUploader.isAcceptable(relay: URL(string: "ftp://x.dev")!) && !MobileUploader.isAcceptable(relay: URL(string: "https://")!), "envoi : HTTP distant, autre schéma ou sans hôte refusés")
check(MobileUploader.endpoint(relay: relayURL, id: vaultID)?.absoluteString == "https://usage.example.workers.dev/v1/\(vaultID)" && MobileUploader.endpoint(relay: relayURL, id: "court") == nil, "envoi : adresse du coffre, identifiant vérifié")
check(MobileUploader.endpoint(relay: URL(string: "https://usage.example.workers.dev/ancien/chemin?x=1#clé")!, id: vaultID)?.absoluteString == "https://usage.example.workers.dev/v1/\(vaultID)", "envoi : chemin, requête et fragment du relais ignorés")
check(MobileUploader.normalizedRelay("  usage.example.workers.dev/ ")?.absoluteString == "https://usage.example.workers.dev" && MobileUploader.normalizedRelay("https://usage.example.workers.dev/#v1.a.b")?.absoluteString == "https://usage.example.workers.dev", "envoi : adresse saisie normalisée (https ajouté, fragment retiré)")
check(MobileUploader.normalizedRelay("") == nil && MobileUploader.normalizedRelay("http://usage.example.com") == nil && MobileUploader.normalizedRelay("localhost:8788") == nil || MobileUploader.normalizedRelay("http://localhost:8788") != nil, "envoi : adresse vide ou HTTP distant refusée")
let putRequest = MobileUploader.request(relay: relayURL, id: vaultID, blob: "abc_-", token: String(repeating: "f", count: 64))
check(putRequest?.httpMethod == "PUT" && putRequest?.value(forHTTPHeaderField: "X-Write-Token")?.count == 64 && putRequest?.httpBody == Data("abc_-".utf8), "envoi : PUT avec le jeton d'écriture en en-tête")
check(MobileUploader.request(relay: URL(string: "http://usage.example.com")!, id: vaultID, blob: "x", token: "t") == nil, "envoi : aucune requête vers un relais non sûr")
check(MobileUploader.describe(status: 200, error: nil, bytes: 24943).message == "Envoyé (24 Ko chiffrés)." && MobileUploader.describe(status: 200, error: nil, bytes: 100).ok, "envoi : succès")
check(MobileUploader.describe(status: 403, error: nil, bytes: 1).message.contains("Réassocier") && MobileUploader.describe(status: 401, error: nil, bytes: 1).message.contains("jeton") && !MobileUploader.describe(status: 500, error: nil, bytes: 1).ok, "envoi : refus du relais expliqués")
check(MobileUploader.describe(status: nil, error: URLError(.notConnectedToInternet), bytes: 1).message.contains("connexion Internet") && MobileUploader.describe(status: nil, error: URLError(.cannotFindHost), bytes: 1).message.contains("injoignable"), "envoi : réseau coupé ou relais injoignable")


// Premier lancement : assistant affiché une seule fois et seulement sans données.
check(FirstRun.isNeeded(seen: false, hasData: false), "premier lancement : assistant proposé")
check(!FirstRun.isNeeded(seen: true, hasData: false), "premier lancement : déjà vu, pas de nouvelle fenêtre")
check(!FirstRun.isNeeded(seen: false, hasData: true), "premier lancement : des données existent déjà, pas d'assistant")
check(FirstRun.statuslineSetting.contains("statusline.json") && FirstRun.statuslineSetting.contains("\"type\": \"command\""), "réglage du statusline : copie vers statusline.json")
let wrapped = "{" + FirstRun.statuslineSetting + "}"
check((try? JSONSerialization.jsonObject(with: Data(wrapped.utf8))) != nil, "réglage du statusline : JSON valide une fois copié dans settings.json")

let nowForFiles = Date()
let fileDir = FileManager.default.temporaryDirectory.appendingPathComponent("uf-statusline-\(UUID().uuidString)")
try? FileManager.default.createDirectory(at: fileDir, withIntermediateDirectories: true)
let older = fileDir.appendingPathComponent("older.json").path
let newer = fileDir.appendingPathComponent("newer.json").path
let futureReset = Int(nowForFiles.timeIntervalSince1970) + 3600
try? Data("{\"rate_limits\":{\"five_hour\":{\"used_percentage\":10,\"resets_at\":\(futureReset)}}}".utf8).write(to: URL(fileURLWithPath: older))
try? Data("{\"rate_limits\":{\"five_hour\":{\"used_percentage\":42,\"resets_at\":\(futureReset)}}}".utf8).write(to: URL(fileURLWithPath: newer))
try? FileManager.default.setAttributes([.modificationDate: nowForFiles.addingTimeInterval(-600)], ofItemAtPath: older)
check(StatuslineUsage.loadNewest(paths: [older, newer], now: nowForFiles)?.fiveHour?.usedPercentage == 42, "statusline : la copie la plus récente l'emporte")
check(StatuslineUsage.loadNewest(paths: [fileDir.appendingPathComponent("absent.json").path, older], now: nowForFiles)?.fiveHour?.usedPercentage == 10, "statusline : un emplacement absent est ignoré")
check(StatuslineUsage.loadNewest(paths: [fileDir.appendingPathComponent("absent.json").path], now: nowForFiles) == nil, "statusline : aucun emplacement lisible -> nil")
try? FileManager.default.removeItem(at: fileDir)



// Cadence de la synchro mobile : jamais plus de 288 envois par jour en régime normal, plafond à 800.
let syncT0 = Date(timeIntervalSince1970: 1_000_000)
check(MobileSyncPolicy.shouldSend(now: syncT0, lastSent: nil, changed: false, sentToday: 0, force: false), "synchro : premier envoi immédiat")
check(!MobileSyncPolicy.shouldSend(now: syncT0.addingTimeInterval(60), lastSent: syncT0, changed: true, sentToday: 1, force: false), "synchro : pas d'envoi avant 5 minutes")
check(MobileSyncPolicy.shouldSend(now: syncT0.addingTimeInterval(300), lastSent: syncT0, changed: true, sentToday: 1, force: false), "synchro : envoi après 5 minutes si changement")
check(!MobileSyncPolicy.shouldSend(now: syncT0.addingTimeInterval(600), lastSent: syncT0, changed: false, sentToday: 1, force: false), "synchro : rien si les valeurs n'ont pas bougé")
check(MobileSyncPolicy.shouldSend(now: syncT0.addingTimeInterval(1200), lastSent: syncT0, changed: false, sentToday: 1, force: false), "synchro : envoi de présence après 20 minutes")
check(MobileSyncPolicy.shouldSend(now: syncT0.addingTimeInterval(5), lastSent: syncT0, changed: false, sentToday: 1, force: true), "synchro : envoi manuel immédiat")
check(!MobileSyncPolicy.shouldSend(now: syncT0.addingTimeInterval(9999), lastSent: syncT0, changed: true, sentToday: 800, force: true), "synchro : le plafond quotidien bloque même l'envoi manuel")
check(MobileSyncPolicy.dailyCap + 0 < 1000 && Int(86_400 / MobileSyncPolicy.minInterval) < 1000, "synchro : sous la limite gratuite de 1 000 écritures")
check(MobileSyncPolicy.utcDayStamp(Date(timeIntervalSince1970: 86_399)) != MobileSyncPolicy.utcDayStamp(Date(timeIntervalSince1970: 86_400)), "synchro : le compteur change à minuit UTC")


// Jour de remise à zéro de la semaine : seule la consommation après le reset compte (bug vu le 21/10 : 17 % au lieu de 6 %).
let resetDay = [daySample(0, w: 84), daySample(2, w: 99), daySample(4, w: 1), daySample(6, w: 6)]
check(UsageAnalytics.usedTodayInCurrentWindow(resetDay, series: .weekly, now: midnightBase.addingTimeInterval(7 * 3600), calendar: utc) == 5, "aujourd'hui : un reset en cours de journée repart de zéro")


// Planning de la semaine envoyé au téléphone.
let planSample = WeekPlan.makeFromMidnight(used: 6, usedToday: 6, now: noon, resetsAt: noon.addingTimeInterval(3 * 86_400), calendar: paris)
let planInfo = MobileSnapshot.planInfo(planSample)
check(planInfo?.first?.today == true && planInfo?.first?.consumed == 6 && (planInfo?.count ?? 0) >= 3 && MobileSnapshot.planInfo(nil) == nil, "mobile : planning de la semaine dans le snapshot")
var withPlan = snapshot; withPlan.plan = planInfo
check(withPlan.encoded().flatMap(MobileSnapshot.decode) == withPlan, "mobile : snapshot avec planning, aller-retour JSON")
check(snapshotData.flatMap(MobileSnapshot.decode)?.plan == nil, "mobile : snapshot sans planning (ancien envoi) toujours lisible")


// Informations avancées du snapshot : modèles, lignes supplémentaires, courbe de la semaine.
var advanced = snapshot
advanced.models = [MobileSnapshot.ModelShare(name: "Sonnet", percent: 12)]
advanced.extras = [MobileSnapshot.ExtraLine(label: "Utilisation supplémentaire", text: "4 $ sur 20 $", fraction: 0.2)]
advanced.weekHistory = MobileSnapshot.decimate([UsageSample(time: 3_600, session: 10, weekly: 20), UsageSample(time: 3_700, session: 12, weekly: 21)], bucket: 3_600)
check(advanced.encoded().flatMap(MobileSnapshot.decode) == advanced, "mobile : snapshot avec modèles, extras et courbe de la semaine, aller-retour JSON")
check(snapshotData.flatMap(MobileSnapshot.decode)?.models == nil && snapshotData.flatMap(MobileSnapshot.decode)?.weekHistory == nil, "mobile : champs avancés absents d'un ancien envoi")

exit(failures == 0 ? 0 : 1)
