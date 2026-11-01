import Foundation

/// Résumé du prêt envoyé au téléphone du propriétaire (champ facultatif `loan` du snapshot, lu par mobile/pwa/lib/loan-view.js).
struct LoanInfo: Codable, Equatable {
    let guestName: String
    let share: Double
    let startsAt: Date
    let endsAt: Date
    let active: Bool
    let guestUsed: Double
    let guestMeasured: Double
    let guestEstimated: Double
    let ownerUsed: Double
    let guestRatePerDay: Double?
    let guestExhaustsAt: Date?
    let collectorAt: Date?
    let collectorPlatform: String?
    let status: String
    let lastCommandID: String?
}

/// Ce que voit l'invité (document `guest-view`, déposé chiffré dans son coffre de lecture) : sa part, pas l'usage du propriétaire.
struct GuestViewDocument: Encodable, Equatable {
    struct Day: Encodable, Equatable {
        let day: String
        let points: Double
    }

    var kind = "guest-view"
    var version = 1
    let updatedAt: Date
    let guestName: String
    let share: Double
    let startsAt: Date
    let endsAt: Date
    let active: Bool
    let guestUsed: Double
    let guestMeasured: Double
    let guestEstimated: Double
    let guestRatePerDay: Double?
    let guestExhaustsAt: Date?
    /// Réserve restante du propriétaire ; nil s'il ne veut pas la montrer.
    let reserveLeft: Double?
    let days: [Day]
}

/// Commande déposée par le téléphone dans le coffre de contrôle (mobile/pwa/lib/loan.js) : créer ou terminer un prêt.
struct LoanCommand: Equatable {
    struct Vault: Equatable {
        let id: String
        /// Clé en base64url (convertie par l'appelant, qui a CryptoKit).
        let key: String
    }

    enum Action: Equatable {
        case create(guestName: String, share: Double, endsAt: Date, guestVault: Vault, viewVault: Vault)
        case end
    }

    let id: String
    let createdAt: Date
    let action: Action

    private static func vault(_ value: Any?) -> Vault? {
        guard let object = value as? [String: Any], let id = object["id"] as? String, let key = object["key"] as? String,
              id.count == 32, id.allSatisfy(\.isHexDigit), key.count >= 43 else { return nil }
        return Vault(id: id, key: key)
    }

    /// nil si ce n'est pas une commande connue et complète.
    static func decode(_ data: Data) -> LoanCommand? {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any], raw["kind"] as? String == "loan-command",
              raw["version"] as? Int == 1, let id = raw["id"] as? String, !id.isEmpty,
              let createdAt = GuestReport.date(raw["createdAt"] as? String) else { return nil }
        switch raw["action"] as? String {
        case "end":
            return LoanCommand(id: id, createdAt: createdAt, action: .end)
        case "create":
            guard let share = raw["share"] as? Double, Loan.shareRange.contains(share), let endsAt = GuestReport.date(raw["endsAt"] as? String),
                  let guestVault = vault(raw["guestVault"]), let viewVault = vault(raw["viewVault"]) else { return nil }
            return LoanCommand(id: id, createdAt: createdAt, action: .create(guestName: raw["guestName"] as? String ?? "", share: share, endsAt: endsAt,
                                                                            guestVault: guestVault, viewVault: viewVault))
        default:
            return nil
        }
    }
}

enum LoanPublishing {
    static func info(loan: Loan, state: LoanState?, report: GuestReport?, status: String, lastCommandID: String?, now: Date) -> LoanInfo {
        let tally = state?.tally ?? LoanTally()
        return LoanInfo(guestName: loan.displayName, share: loan.share, startsAt: loan.startsAt, endsAt: loan.endsAt, active: loan.isActive(at: now),
                        guestUsed: tally.guest, guestMeasured: tally.guestMeasured, guestEstimated: tally.guestEstimated, ownerUsed: tally.owner,
                        guestRatePerDay: state?.guestRatePerDay, guestExhaustsAt: state?.guestExhaustsAt, collectorAt: report?.updatedAt,
                        collectorPlatform: report?.platformLabel, status: status, lastCommandID: lastCommandID)
    }

    static func guestView(loan: Loan, state: LoanState, days: [(day: String, points: Double)], showsReserve: Bool, now: Date, active: Bool? = nil) -> GuestViewDocument {
        GuestViewDocument(updatedAt: now, guestName: loan.displayName, share: loan.share, startsAt: loan.startsAt, endsAt: loan.endsAt,
                          active: active ?? loan.isActive(at: now), guestUsed: state.tally.guest, guestMeasured: state.tally.guestMeasured,
                          guestEstimated: state.tally.guestEstimated, guestRatePerDay: state.guestRatePerDay, guestExhaustsAt: state.guestExhaustsAt,
                          reserveLeft: showsReserve ? state.ownerLeft : nil, days: days.map { GuestViewDocument.Day(day: $0.day, points: $0.points) })
    }

    /// JSON trié, dates ISO 8601 : le format que lit l'application mobile.
    static func encode<T: Encodable>(_ value: T) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(value)
    }
}
