import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Tests du prêt de quota (ADR 003) : rapport du collecteur, attribution, règles, journaux de ce Mac. Appelés depuis main.swift.
func runLoanTests() {
    // Produit par le collecteur JavaScript (mobile/collector) : le Mac doit lire exactement ce format.
    let reportJSON = """
    {"kind":"guest-activity","version":1,"updatedAt":"2026-11-01T10:08:30.500Z","reason":"activity","collector":{"version":"0.1.0","platform":"win32"},"lastActivityAt":"2026-11-01T10:07:00.000Z","bucketMinutes":5,"buckets":[{"t":1793527200,"n":1,"in":10,"out":20,"cw":30,"cr":40,"models":{"claude-opus-5-5":100}},{"t":1793527500,"n":1,"in":10,"out":20,"cw":30,"cr":40,"models":{"claude-sonnet-5-5":100}}]}
    """
    let report = GuestReport.decode(Data(reportJSON.utf8))
    check(report?.updatedAt.timeIntervalSince1970 == 1_793_527_710.5, "prêt : date du collecteur lue avec ses millisecondes")
    check(report?.lastActivityAt?.timeIntervalSince1970 == 1_793_527_620, "prêt : dernière activité lue")
    check(report?.buckets.count == 2 && report?.buckets.first?.cacheRead == 40 && report?.buckets.first?.weight == 60, "prêt : tranches lues, poids sans la lecture du cache")
    check(report?.platformLabel == "Windows", "prêt : plateforme affichée en clair")
    check(GuestReport.decode(Data(reportJSON.replacingOccurrences(of: "guest-activity", with: "autre").utf8)) == nil, "prêt : un autre document est refusé")
    check(GuestReport.decode(Data(reportJSON.replacingOccurrences(of: "\"version\":1", with: "\"version\":2").utf8)) == nil, "prêt : version inconnue refusée")
    check(GuestReport.decode(Data("pas du json".utf8)) == nil, "prêt : JSON invalide refusé")

    #if canImport(CryptoKit)
    // Le même rapport, chiffré par le collecteur (clé 0x00…0x1f, nonce 0xa0…0xab).
    let sealed = "oKGio6SlpqeoqaqrnToXRCuvIIVAAvK2dA7tvxPYMGb7wztOsCxQ4w3YHG68VH3OgwAmTTv9cK1tO_fbfTl0eFDmN09wcztv8EG1ioSEv1wAi9HQxLjdNK28qdu-ZMWG_-P4GZocSPPF42-4redEx2_L7O_xqSRq_qqbTVYjCMGwF6EeH-HvioR33m-1fdELtS3yehVj3Px7JKLkqqSBSdKxifi8rsmc2a5AUodsPYuUWHAktCcaE0Lih7VGFseoNVyeDqyyRgkGoDN1VkMvogWl9oSdKDSqOgYIgH7Lhp1cCL3MnuNivibkrkVSYAUYiljrCPKMcnNgZWJFOpHgVudwSrZbgY8FEEcKqCUP5aWMu4DaVZN7pwRJTukMISZy1tWnT5QUNOCZkudB-j0ixw1tDbiWQHsBxo28b-gnoygnHeHXUJpcmqy-gDHi6yPg0ldbNanpRyv-avadSvOqM_k7Q9JiLaTmSlmzb3sgknz0Ulp6wPUzsFHOfKqogH1zv0Ygo8hlOHS4yqCGRKXETth3uzZaYpVYG9DVlmJhrVBnC2yqe9ICDMILLMSO"
    let opened = MobileCrypto.open(sealed, key: SymmetricKey(data: Data((0..<32).map { UInt8($0) })))
    check(opened.flatMap(GuestReport.decode) == report, "prêt : le Mac déchiffre et lit le rapport chiffré par le collecteur")
    #endif

    // Attribution : relevés toutes les 20 min, activité au milieu de chaque intervalle (hors de la marge de 5 min des voisins).
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let t0 = start.timeIntervalSince1970
    func sample(_ k: Double, _ weekly: Double) -> UsageSample { UsageSample(time: t0 + k * 1200, session: nil, weekly: weekly) }
    func bucket(_ k: Double, weight: Int) -> ActivityBucket { ActivityBucket(t: t0 + k * 1200 + 600, n: 1, input: 0, output: weight, cacheWrite: 0, cacheRead: 999) }
    let samples = [UsageSample(time: t0 - 600, session: nil, weekly: 10), sample(1, 12), sample(2, 13), sample(3, 17), sample(4, 18), sample(5, 2), sample(6, 2)]
    let guestBuckets = [bucket(0, weight: 50), bucket(2, weight: 300)]
    let ownerBuckets = [bucket(1, weight: 80), bucket(2, weight: 100)]
    let tally = LoanAttribution.tally(samples: samples, guest: guestBuckets, owner: ownerBuckets, from: start, to: start.addingTimeInterval(9000))
    check(tally.guestMeasured == 2, "attribution : seul l'invité actif -> à lui, mesuré (relevé d'avant le prêt pris comme départ)")
    check(tally.ownerMeasured == 1, "attribution : seul le propriétaire actif -> à lui, mesuré")
    check(abs(tally.guestEstimated - 4) < 0.0001 && abs(tally.ownerEstimated - 1) < 0.0001, "attribution : les deux actifs -> au prorata des tokens (3 / 1), estimé ; personne -> à l'invité (+1)")
    check(tally.unexplained == 1, "attribution : la hausse sans activité est suivie à part")
    check(tally.guest == 6 && tally.owner == 2, "attribution : la baisse du reset n'est pas une consommation")
    check(LoanAttribution.tally(samples: samples, guest: [], owner: [], from: start, to: start.addingTimeInterval(1200)).guestEstimated == 2, "attribution : ne compte rien après la fin demandée")
    check(LoanAttribution.tally(samples: [], guest: guestBuckets, owner: [], from: start, to: start).guest == 0, "attribution : sans relevé, rien")

    // État et alertes : 70 % prêtés pendant 7 jours.
    let loan = Loan(id: "test", guestName: "Sam", share: 0.7, startsAt: start, endsAt: start.addingTimeInterval(7 * 86400),
                    relay: "https://relais.example", vaultID: String(repeating: "a", count: 32))
    let utc = { () -> Calendar in var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "UTC")!; return calendar }()
    let twoDays = start.addingTimeInterval(2 * 86400)
    let midway = LoanRules.state(loan: loan, tally: LoanTally(guestMeasured: 28, guestEstimated: 2, ownerMeasured: 10), since: start, now: twoDays, reportAt: twoDays)
    check(midway.guestRatePerDay == 15 && midway.guestLeft == 40 && midway.ownerLeft == 20, "prêt : rythme de l'invité, sa part restante et ta réserve restante")
    check(midway.guestExhaustsAt.map { abs($0.timeIntervalSince(twoDays) - 40.0 / 15 * 86400) < 1 } == true, "prêt : date d'épuisement de la part au rythme moyen")
    check(LoanRules.state(loan: loan, tally: LoanTally(guestMeasured: 30), since: start, now: start.addingTimeInterval(3600), reportAt: nil).guestRatePerDay == nil, "prêt : pas de rythme avant 12 h")
    let early = LoanRules.alerts(loan: loan, state: midway, now: twoDays, calendar: utc)
    check(early.map(\.title) == ["Sam va dépasser sa part"], "alertes : seulement la prévision de dépassement à mi-parcours")
    check(early.first?.body.contains("15 points par jour") == true && early.first?.body.contains("70 points") == true, "alertes : la prévision dit le rythme et la limite")
    let close = LoanRules.state(loan: loan, tally: LoanTally(guestMeasured: 50, guestEstimated: 6), since: start, now: twoDays.addingTimeInterval(4 * 86400), reportAt: twoDays.addingTimeInterval(4 * 86400))
    let closeAlerts = LoanRules.alerts(loan: loan, state: close, now: twoDays.addingTimeInterval(4 * 86400), calendar: utc)
    check(closeAlerts.contains { $0.key == "loan-test-seuil-80" && $0.body.contains("50 mesurés, 6 estimés") }, "alertes : seuil de 80 % de la part, avec la provenance des chiffres")
    let over = LoanRules.state(loan: loan, tally: LoanTally(guestMeasured: 72, ownerMeasured: 14), since: start, now: twoDays, reportAt: twoDays)
    let overAlerts = LoanRules.alerts(loan: loan, state: over, now: twoDays, calendar: utc)
    check(over.ownerLeft == 14 && overAlerts.map(\.key) == ["loan-test-reserve"], "alertes : part dépassée -> réserve entamée (30 - 14 - 2 = 14), sans seuil ni prévision en double")
    let silent = LoanRules.state(loan: loan, tally: LoanTally(), since: start, now: twoDays, reportAt: nil)
    check(LoanRules.alerts(loan: loan, state: silent, now: twoDays, calendar: utc).contains { $0.title.hasPrefix("Collecteur de Sam muet") }, "alertes : collecteur jamais entendu après 7 h")
    check(LoanRules.alerts(loan: loan, state: over, now: loan.endsAt, calendar: utc).isEmpty, "alertes : plus rien une fois le prêt terminé")

    runLoanSyncTests(loan: loan, start: start, samples: samples, guestBuckets: guestBuckets, ownerBuckets: ownerBuckets, utc: utc)

    // Journaux de ce Mac : même lecture que le collecteur.
    let line = #"{"type":"assistant","requestId":"r1","timestamp":"2026-11-01T10:02:00.000Z","message":{"id":"m1","model":"claude-opus-5-5","content":[{"type":"text","text":"PRIVE"}],"usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":40}}}"#
    let parsed = ClaudeTranscripts.parse(line: Substring(line))
    check(parsed == ClaudeTranscripts.Record(key: "m1:r1", time: 1_793_527_320, model: "claude-opus-5-5", input: 10, output: 20, cacheWrite: 30, cacheRead: 40), "journaux du Mac : réponse lue comme le collecteur")
    check(ClaudeTranscripts.parse(line: Substring(line.replacingOccurrences(of: "claude-opus-5-5", with: "<synthetic>"))) == nil, "journaux du Mac : message synthétique ignoré")
    check(ClaudeTranscripts.parse(line: #"{"type":"user","timestamp":"2026-11-01T10:02:00Z","message":{"content":"x"}}"#) == nil, "journaux du Mac : message de l'utilisateur ignoré")
    let partial = ClaudeTranscripts.Record(key: "m1:r1", time: 1_793_527_320, model: "claude-opus-5-5", input: 10, output: 1, cacheWrite: 30, cacheRead: 40)
    let grouped = ClaudeTranscripts.buckets([partial, parsed!, parsed!])
    check(grouped.count == 1 && grouped[0].n == 1 && grouped[0].output == 20, "journaux du Mac : une réponse écrite trois fois comptée une fois, version complète")
    let home = URL(fileURLWithPath: "/Users/alane")
    check(ClaudeTranscripts.projectDirectories(environment: [:], home: home).map(\.path) == ["/Users/alane/.config/claude/projects", "/Users/alane/.claude/projects"], "journaux du Mac : emplacements par défaut")
    check(ClaudeTranscripts.projectDirectories(environment: ["CLAUDE_CONFIG_DIR": "/a, /b"], home: home).map(\.path) == ["/a/projects", "/b/projects"], "journaux du Mac : CLAUDE_CONFIG_DIR prioritaire")
}

/// Étape 3 : commandes du téléphone, vue de l'invité, résumé pour le téléphone, coffre de contrôle.
func runLoanSyncTests(loan: Loan, start: Date, samples: [UsageSample], guestBuckets: [ActivityBucket], ownerBuckets: [ActivityBucket], utc: Calendar) {
    // Commande produite par mobile/pwa/lib/loan.js (prepareLoan), telle que le téléphone la dépose.
    let commandJSON = """
    {"kind":"loan-command","version":1,"id":"6f1c2b9e-1d2a-4c3b-9a8e-7f6d5c4b3a21","action":"create","createdAt":"2026-11-01T15:00:00.000Z","guestName":"Sam","share":0.7,"endsAt":"2026-11-05T09:00:00.000Z","guestVault":{"id":"0123456789abcdef0123456789abcdef","key":"AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"},"viewVault":{"id":"fedcba9876543210fedcba9876543210","key":"Hx4dHBsaGRgXFhUUExIREA8ODQwLCgkIBwYFBAMCAQA"}}
    """
    let command = LoanCommand.decode(Data(commandJSON.utf8))
    if case let .create(name, share, endsAt, guestVault, viewVault)? = command?.action {
        check(name == "Sam" && share == 0.7 && endsAt.timeIntervalSince1970 == 1_793_869_200, "commande du téléphone : prénom, part et fin lus")
        check(guestVault.id == "0123456789abcdef0123456789abcdef" && viewVault.key.hasPrefix("Hx4d"), "commande du téléphone : les deux coffres lus")
    } else {
        check(false, "commande du téléphone : création reconnue")
    }
    check(LoanCommand.decode(Data(#"{"kind":"loan-command","version":1,"id":"x","action":"end","createdAt":"2026-11-01T15:00:00Z"}"#.utf8))?.action == .end, "commande du téléphone : fin reconnue")
    check(LoanCommand.decode(Data(commandJSON.replacingOccurrences(of: "\"share\":0.7", with: "\"share\":1.5").utf8)) == nil, "commande du téléphone : part hors limites refusée")
    check(LoanCommand.decode(Data(commandJSON.replacingOccurrences(of: "0123456789abcdef0123456789abcdef", with: "court").utf8)) == nil, "commande du téléphone : coffre mal formé refusé")
    check(LoanCommand.decode(Data("{}".utf8)) == nil, "commande du téléphone : document vide refusé")

    // Jour par jour : la somme des jours vaut le total (un intervalle à cheval sur minuit va au jour de son relevé de fin).
    let end = start.addingTimeInterval(9000)
    let days = LoanAttribution.daily(samples: samples, guest: guestBuckets, owner: ownerBuckets, from: start.addingTimeInterval(-86400), to: end, calendar: utc)
    let total = LoanAttribution.tally(samples: samples, guest: guestBuckets, owner: ownerBuckets, from: start.addingTimeInterval(-86400), to: end).guest
    check(abs(days.reduce(0) { $0 + $1.points } - total) < 0.0001 && days.count == 2, "vue de l'invité : jours dont la somme vaut le total")
    check(days.first.map { $0.day.count == 10 && $0.day.hasPrefix("2027-01-1") } == true, "vue de l'invité : jours au format AAAA-MM-JJ")

    let state = LoanRules.state(loan: loan, tally: LoanTally(guestMeasured: 35, guestEstimated: 3, ownerMeasured: 14), since: start,
                                now: start.addingTimeInterval(3 * 86400), reportAt: nil)
    let view = LoanPublishing.guestView(loan: loan, state: state, days: [(day: "2027-01-15", points: 6)], showsReserve: true, now: start.addingTimeInterval(3 * 86400))
    let json = LoanPublishing.encode(view).map { String(decoding: $0, as: UTF8.self) } ?? ""
    print("     vue de l'invité (vecteur pour mobile/pwa/test/loan.test.js) : \(json)")
    check(json.contains(#""kind":"guest-view""#) && json.contains(#""reserveLeft":16"#) && json.contains(#""guestUsed":38"#), "vue de l'invité : document lisible par le téléphone, réserve restante 30 - 14 = 16")
    check(!json.contains("ownerUsed") && !json.contains("ownerMeasured"), "vue de l'invité : l'usage du propriétaire n'en fait pas partie")
    let hidden = LoanPublishing.guestView(loan: loan, state: state, days: [], showsReserve: false, now: start)
    check(LoanPublishing.encode(hidden).map { !String(decoding: $0, as: UTF8.self).contains("reserveLeft") } == true, "vue de l'invité : réserve masquée si demandé")
    let info = LoanPublishing.info(loan: loan, state: state, report: nil, status: "", lastCommandID: "c1", now: start.addingTimeInterval(86400))
    check(info.active && info.guestUsed == 38 && info.ownerUsed == 14 && info.lastCommandID == "c1", "résumé pour le téléphone : part, usage de chacun et dernière commande appliquée")

    #if canImport(CryptoKit)
    // Même coffre de contrôle que mobile/pwa/lib/crypto.js (clé 0x00…0x1f).
    let control = UsageManager.controlVault(for: SymmetricKey(data: Data((0..<32).map { UInt8($0) })))
    check(control.id == "5eb8630571dc84b780e161b6770e21bd", "coffre de contrôle : même identifiant que le téléphone")
    check(MobileCrypto.base64url(control.key.withUnsafeBytes { Data($0) }) == "WYnkzqQ3h3V4pt-UEed36U56vxWZghyPB2XK3kn1Xaw", "coffre de contrôle : même clé que le téléphone")
    #endif
}
