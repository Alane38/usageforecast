import Foundation

/// Une organisation claude.ai (compte personnel, équipe) dont on peut suivre l'usage.
struct Organization: Identifiable, Equatable {
    let id: String
    let name: String
    /// Seules les organisations avec la capacité « chat » ont des limites d'usage à suivre.
    let hasChat: Bool
}

enum OrganizationList {
    /// Lit la réponse de `claude.ai/api/organizations` : un tableau d'objets `uuid`, `name`, `capabilities`.
    /// Tolérant : une entrée sans identifiant est ignorée, un nom absent devient « Organisation » suivi du début de l'identifiant.
    static func parse(_ data: Data) -> [Organization] {
        guard let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return [] }
        return list.compactMap { entry in
            guard let id = entry["uuid"] as? String, !id.isEmpty else { return nil }
            let name = (entry["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Organisation \(id.prefix(8))"
            let capabilities = entry["capabilities"] as? [String] ?? []
            return Organization(id: id, name: name, hasChat: capabilities.contains("chat"))
        }
    }

    /// Organisations proposées dans les réglages : celles qui ont des limites d'usage, sinon toutes (réponse sans capacités).
    static func followable(_ organizations: [Organization]) -> [Organization] {
        let withChat = organizations.filter(\.hasChat)
        return withChat.isEmpty ? organizations : withChat
    }

    /// Organisation à interroger : le choix de l'utilisateur s'il existe encore, sinon la dernière active du cookie.
    static func resolve(selected: String?, available: [Organization], cookieOrg: String?) -> String? {
        if let selected, available.isEmpty || available.contains(where: { $0.id == selected }) { return selected }
        return cookieOrg
    }
}
