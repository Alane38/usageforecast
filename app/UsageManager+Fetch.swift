import SwiftUI
import AppKit

/// Cycle de rafraîchissement : statusline, puis requêtes claude.ai pour l'organisation suivie.
extension UsageManager {

    // MARK: Point d'entrée

    func fetchUsage() {
        // Sans cookie le statusline suffit ; avec cookie il sert de repli si le réseau échoue.
        let statuslineApplied = applyStatuslineUsage()
        fetchConsoleBalance()
        checkForUpdateIfDue()
        if organizations.isEmpty { fetchOrganizations() }

        if sessionCookie.isEmpty {
            if !statuslineApplied && !DevFlags.isSet("--demo") { showOnMain(error: "Session cookie not set") }
            return
        }

        setLoading(true, error: nil)
        fetchOrganizationId { [weak self] resolvedId in
            guard let orgId = resolvedId else {
                self?.showOnMain(error: "Could not get org ID from cookie", stopLoading: true)
                return
            }
            self?.fetchAllEndpoints(orgId: orgId)
        }
    }

    private func setLoading(_ loading: Bool, error: String?) {
        isLoading = loading
        errorMessage = error
    }

    /// Affiche une erreur depuis n'importe quel thread ; la barre de menu suit si le chargement continue.
    private func showOnMain(error message: String, stopLoading: Bool = false) {
        DispatchQueue.main.async { [self] in
            if stopLoading {
                setLoading(false, error: message)
            } else {
                errorMessage = message
                updateStatusBar()
            }
        }
    }

    private func fetchAllEndpoints(orgId: String) {
        fetchUsageWithOrgId(orgId)
        fetchExtraUsage(orgId)
        fetchFreeCredits(orgId)
        fetchLimitResets(orgId)
    }

    // MARK: Requêtes

    /// Requête GET vers claude.ai avec les en-têtes donnés ; nil si l'adresse est invalide.
    func claudeRequest(_ address: String, headers: [String: String]) -> URLRequest? {
        guard let url = URL(string: address) else { return nil }
        var prepared = URLRequest(url: url)
        for (name, value) in headers { prepared.setValue(value, forHTTPHeaderField: name) }
        return prepared
    }

    func perform(_ request: URLRequest, then handle: @escaping (Data?, URLResponse?) -> Void) {
        URLSession.shared.dataTask(with: request) { data, response, _ in handle(data, response) }.resume()
    }

    // MARK: Organisation

    /// Le choix de l'utilisateur ou le cookie `lastActiveOrg` d'abord, sinon l'endpoint bootstrap.
    func fetchOrganizationId(completion: @escaping (String?) -> Void) {
        if let knownId = effectiveOrganizationId() {
            completion(knownId)
            return
        }
        guard let request = claudeRequest("https://claude.ai/api/bootstrap",
                                          headers: ["Cookie": "sessionKey=\(sessionCookie)"]) else {
            completion(nil)
            return
        }
        NSLog("📡 Lecture de bootstrap pour trouver l'organisation…")
        perform(request) { data, _ in
            let orgId = data.flatMap(Self.lastActiveOrganizationId(inBootstrap:))
            NSLog(orgId == nil ? "❌ Organisation introuvable dans bootstrap" : "✅ Organisation lue dans bootstrap")
            completion(orgId)
        }
    }

    private static func lastActiveOrganizationId(inBootstrap data: Data) -> String? {
        let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let account = root?["account"] as? [String: Any]
        return account?["lastActiveOrgId"] as? String
    }

    // MARK: Suivi des réponses

    func noteFetchResult(statusCode: Int) {
        refreshPolicy.record(statusCode: statusCode)
        isRefreshSlowed = refreshPolicy.isSlowed
        switch statusCode {
        case 200..<300:
            consecutiveAuthFailures = 0
        case 401, 403:
            consecutiveAuthFailures += 1
            evaluateAlerts()
        default:
            break
        }
    }

    // MARK: Statusline Claude Code

    /// Applique les limites lues dans le statusline de Claude Code. Renvoie false si la source est absente.
    @discardableResult
    func applyStatuslineUsage() -> Bool {
        guard let usage = StatuslineUsage.loadNewest() else { return false }
        // Un statusline plus ancien que la dernière donnée affichée ne doit pas la remplacer :
        // au Refresh, il écrasait les vraies valeurs réseau pendant le chargement.
        let isNewer = StatuslineUsage.shouldReplace(displayedAt: lastUpdated,
                                                    hasDisplayedData: hasFetchedData,
                                                    capturedAt: usage.capturedAt)
        guard isNewer else { return true }

        if let fiveHour = usage.fiveHour {
            sessionUsage = Int(fiveHour.usedPercentage)
            sessionResetsAt = fiveHour.resetsAt
        }
        if let sevenDay = usage.sevenDay {
            weeklyUsage = Int(sevenDay.usedPercentage)
            weeklyResetsAt = sevenDay.resetsAt
        }
        lastUpdated = usage.capturedAt
        usageSource = "statusline"
        recordSample(at: usage.capturedAt)
        (errorMessage, hasFetchedData) = (nil, true)
        refreshDisplay()
        return true
    }

    private func refreshDisplay() {
        [updatePercentages, updateStatusBar].forEach { $0() }
    }

    // MARK: Remises à zéro de limite

    /// Les mêmes données que Réglages > Usage sur claude.ai (`cedar_ember=1`) : lecture seule.
    func fetchLimitResets(_ orgId: String) {
        let address = "https://claude.ai/api/organizations/\(orgId)/usage?cedar_ember=1&skip_spend=1"
        guard let request = claudeRequest(address, headers: browserHeaders(cookie: sessionCookie)) else { return }

        perform(request) { [weak self] data, response in
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let data,
                  let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            DispatchQueue.main.async { self?.applyLimitResets(payload["cedar_ember"]) }
        }
    }

    private func applyLimitResets(_ rawGrants: Any?) {
        let (count, endDate) = Self.parseLimitResets(rawGrants)
        limitResetsLeft = count
        limitResetsEndAt = endDate
        NSLog("🔄 Remises à zéro disponibles : \(count)")
    }

    private func browserHeaders(cookie: String) -> [String: String] {
        [
            "Cookie": cookie,
            "Accept": "*/*",
            "Content-Type": "application/json",
            "Origin": "https://claude.ai",
            "Referer": "https://claude.ai",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "authority": "claude.ai",
        ]
    }
}
