import SwiftUI
import AppKit

private enum ClaudeEndpoint {
    static let origin = "https://claude.ai"
    static let browserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    static func organizationURL(_ orgId: String, _ resource: String) -> URL? {
        URL(string: "\(origin)/api/organizations/\(orgId)/\(resource)")
    }

    static func dateWithFractions(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text)
    }
}

extension UsageManager {
    /// GET authentifié par le cookie de session, avec les en-têtes d'un navigateur.
    private func authenticatedGet(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60)
        let browserHeaders: [String: String] = [
            "Cookie": sessionCookie,
            "Accept": "*/*",
            "Content-Type": "application/json",
            "Origin": ClaudeEndpoint.origin,
            "Referer": ClaudeEndpoint.origin,
            "User-Agent": ClaudeEndpoint.browserAgent,
            "authority": "claude.ai",
        ]
        browserHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }

    /// Lance l'appel et, sur le fil principal, remet l'objet JSON d'une réponse 200 exploitable.
    private func loadJSON(orgId: String, resource: String,
                          onSuccess: @escaping (UsageManager, [String: Any]) -> Void) {
        guard let url = ClaudeEndpoint.organizationURL(orgId, resource) else { return }
        URLSession.shared.dataTask(with: authenticatedGet(url)) { [weak self] body, response, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, (response as? HTTPURLResponse)?.statusCode == 200, let body,
                      let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
                else { return }
                onSuccess(self, object)
            }
        }.resume()
    }

    /// Solde des crédits gratuits ou promotionnels.
    func fetchFreeCredits(_ orgId: String) { loadFreeCredits(orgId) }

    private func loadFreeCredits(_ orgId: String) {
        loadJSON(orgId: orgId, resource: "prepaid/credits") { manager, object in
            manager.freeCreditsMinor = Self.creditBalance(object)
            if let code = object["currency"] as? String { manager.creditCurrency = code }
            NSLog("🎁 Crédits gratuits restants : \(manager.freeCreditsMinor) \(manager.creditCurrency)")
        }
    }

    /// `amount` est le solde courant ; sans lui, on additionne ce qu'il reste dans chaque tranche.
    private static func creditBalance(_ object: [String: Any]) -> Int {
        if let balance = object["amount"] as? Int { return balance }
        let tranches = ["tranches", "promo_tranches"].flatMap { object[$0] as? [[String: Any]] ?? [] }
        return tranches.reduce(0) { $0 + (($1["remaining_amount_minor_units"] as? Int) ?? 0) }
    }

    /// Dépense supplémentaire et plafond mensuel : un endpoint distinct de /usage.
    func fetchExtraUsage(_ orgId: String) {
        loadJSON(orgId: orgId, resource: "overage_spend_limit") { manager, object in
            let spent = object["used_credits"] as? Int ?? 0
            let ceiling = object["monthly_credit_limit"] as? Int ?? 0
            manager.extraSpentMinor = spent
            manager.extraLimitMinor = ceiling
            manager.creditCurrency = object["currency"] as? String ?? "USD"
            if let text = object["disabled_until"] as? String {
                manager.extraResetsAt = ClaudeEndpoint.dateWithFractions(text) ?? ISO8601DateFormatter().date(from: text)
            }
            manager.hasCreditUsage = spent > 0
            NSLog("💳 Dépense supplémentaire : \(spent) / \(ceiling) \(manager.creditCurrency)")
        }
    }

    func fetchUsageWithOrgId(_ orgId: String) { requestUsage(orgId: orgId) }

    private func requestUsage(orgId: String) {
        guard let url = ClaudeEndpoint.organizationURL(orgId, "usage") else {
            DispatchQueue.main.async { [self] in
                errorMessage = "Invalid URL"
                isLoading = false
            }
            return
        }
        NSLog("🔍 Relevé de consommation demandé")
        URLSession.shared.dataTask(with: authenticatedGet(url)) { [weak self] body, response, failure in
            DispatchQueue.main.async { self?.finishUsageRequest(body: body, response: response, failure: failure) }
        }.resume()
    }

    private func finishUsageRequest(body: Data?, response: URLResponse?, failure: Error?) {
        isLoading = false
        defer { updateStatusBar() }

        if let failure {
            NSLog("❌ Échec réseau : \(failure.localizedDescription)")
            errorMessage = "Network error"
            return
        }
        guard let http = response as? HTTPURLResponse else {
            errorMessage = "Invalid response"
            return
        }

        NSLog("📡 Code HTTP \(http.statusCode)")
        noteFetchResult(statusCode: http.statusCode)

        if http.statusCode == 200, let body {
            parseUsageData(body)
            return
        }
        errorMessage = "HTTP \(http.statusCode)"
        let sessionRefused = [401, 403].contains(http.statusCode)
        if sessionRefused, shouldAutoImport(), importBrowserCookies() { fetchUsage() }
    }
}
