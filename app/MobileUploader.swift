import Foundation

/// Envoi du snapshot chiffré au relais. La logique pure (adresse, validation, messages) est testée ; l'envoi lui-même est un simple PUT.
enum MobileUploader {
    struct Outcome: Equatable {
        let ok: Bool
        let message: String
        let bytes: Int
    }

    /// Le relais doit être en HTTPS ; seul `localhost` (essais en local) peut rester en HTTP.
    static func isAcceptable(relay: URL) -> Bool {
        guard let host = relay.host, !host.isEmpty else { return false }
        return relay.scheme == "https" || (relay.scheme == "http" && (host == "localhost" || host == "127.0.0.1"))
    }

    /// `https://relais/v1/<identifiant>` ; nil si l'adresse est refusée.
    static func endpoint(relay: URL, id: String) -> URL? {
        guard isAcceptable(relay: relay), id.count == 32 else { return nil }
        var components = URLComponents(url: relay, resolvingAgainstBaseURL: false)
        components?.path = "/v1/\(id)"
        components?.fragment = nil
        components?.query = nil
        return components?.url
    }

    /// Adresse saisie dans les Réglages : espaces retirés, schéma https ajouté si absent, chemin et fragment ignorés. nil si inutilisable.
    static func normalizedRelay(_ text: String) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains("://") { trimmed = "https://" + trimmed }
        guard var components = URLComponents(string: trimmed) else { return nil }
        components.path = ""
        components.query = nil
        components.fragment = nil
        guard let url = components.url, isAcceptable(relay: url) else { return nil }
        return url
    }

    static func request(relay: URL, id: String, blob: String, token: String) -> URLRequest? {
        guard let url = endpoint(relay: relay, id: id) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = Data(blob.utf8)
        request.setValue(token, forHTTPHeaderField: "X-Write-Token")
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        return request
    }

    /// Message lisible pour la fenêtre des Réglages.
    static func describe(status: Int?, error: Error?, bytes: Int) -> Outcome {
        guard let status else {
            let reason = (error as? URLError)?.code == .notConnectedToInternet ? "pas de connexion Internet" : "relais injoignable"
            return Outcome(ok: false, message: "Envoi impossible : \(reason).", bytes: bytes)
        }
        switch status {
        case 200..<300: return Outcome(ok: true, message: "Envoyé (\(max(bytes / 1024, 1)) Ko chiffrés).", bytes: bytes)
        case 401: return Outcome(ok: false, message: "Le relais refuse le jeton d'écriture.", bytes: bytes)
        case 403: return Outcome(ok: false, message: "Ce coffre est lié à une autre clé : clique sur « Réassocier ».", bytes: bytes)
        case 413: return Outcome(ok: false, message: "Données trop volumineuses pour le relais.", bytes: bytes)
        default: return Outcome(ok: false, message: "Le relais a répondu une erreur (\(status)).", bytes: bytes)
        }
    }

    static func upload(_ request: URLRequest, bytes: Int, completion: @escaping (Outcome) -> Void) {
        URLSession.shared.dataTask(with: request) { _, response, error in
            completion(describe(status: (response as? HTTPURLResponse)?.statusCode, error: error, bytes: bytes))
        }.resume()
    }

    /// Variante bloquante pour les outils en ligne de commande (jamais utilisée par l'interface).
    static func uploadAndWait(_ request: URLRequest, bytes: Int) -> Outcome {
        let done = DispatchSemaphore(value: 0)
        var result = Outcome(ok: false, message: "Aucune réponse.", bytes: bytes)
        upload(request, bytes: bytes) { result = $0; done.signal() }
        _ = done.wait(timeout: .now() + 30)
        return result
    }
}
