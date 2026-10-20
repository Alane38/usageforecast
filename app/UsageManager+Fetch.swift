import SwiftUI
import AppKit

extension UsageManager {
    func fetchOrganizationId(completion: @escaping (String?) -> Void) {
        // Choix de l'utilisateur, sinon la valeur du cookie lastActiveOrg.
        if let orgId = effectiveOrganizationId() {
            completion(orgId)
            return
        }

        // If not in cookie, fetch from bootstrap
        guard let url = URL(string: "https://claude.ai/api/bootstrap") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("sessionKey=\(sessionCookie)", forHTTPHeaderField: "Cookie")

        NSLog("📡 Fetching bootstrap to get org ID...")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let account = json["account"] as? [String: Any],
                  let lastActiveOrgId = account["lastActiveOrgId"] as? String else {
                NSLog("❌ Could not parse org ID from bootstrap")
                completion(nil)
                return
            }
            NSLog("✅ Got org ID from bootstrap")
            completion(lastActiveOrgId)
        }.resume()
    }

    func noteFetchResult(statusCode: Int) {
        refreshPolicy.record(statusCode: statusCode)
        isRefreshSlowed = refreshPolicy.isSlowed
        if (200..<300).contains(statusCode) { consecutiveAuthFailures = 0 }
        else if statusCode == 401 || statusCode == 403 { consecutiveAuthFailures += 1; evaluateAlerts() }
    }

    /// Applique les limites lues dans le statusline de Claude Code. Retourne false si la source est absente.
    @discardableResult
    func applyStatuslineUsage() -> Bool {
        guard let usage = StatuslineUsage.loadNewest() else { return false }
        // Un statusline plus ancien que la dernière donnée affichée ne doit pas la remplacer :
        // au Refresh, il écrasait les vraies valeurs réseau le temps du chargement.
        guard StatuslineUsage.shouldReplace(displayedAt: lastUpdated, hasDisplayedData: hasFetchedData, capturedAt: usage.capturedAt) else { return true }
        if let session = usage.fiveHour {
            sessionUsage = Int(session.usedPercentage)
            sessionResetsAt = session.resetsAt
        }
        if let weekly = usage.sevenDay {
            weeklyUsage = Int(weekly.usedPercentage)
            weeklyResetsAt = weekly.resetsAt
        }
        lastUpdated = usage.capturedAt
        usageSource = "statusline"
        recordSample(at: usage.capturedAt)
        errorMessage = nil
        hasFetchedData = true
        updatePercentages()
        updateStatusBar()
        return true
    }

    func fetchUsage() {
        // Sans cookie, le statusline suffit ; avec cookie, il sert de repli si le réseau échoue.
        let hasStatusline = applyStatuslineUsage()
        fetchConsoleBalance()
        checkForUpdateIfDue()
        if organizations.isEmpty { fetchOrganizations() }
        guard !sessionCookie.isEmpty else {
            if !hasStatusline {
                DispatchQueue.main.async {
                    self.errorMessage = "Session cookie not set"
                    self.updateStatusBar()
                }
            }
            return
        }

        isLoading = true
        errorMessage = nil

        // Extract org ID from cookie
        fetchOrganizationId { [weak self] orgId in
            guard let self = self, let orgId = orgId else {
                DispatchQueue.main.async {
                    self?.errorMessage = "Could not get org ID from cookie"
                    self?.isLoading = false
                }
                return
            }

            self.fetchUsageWithOrgId(orgId)
            self.fetchExtraUsage(orgId)
            self.fetchFreeCredits(orgId)
            self.fetchLimitResets(orgId)
        }
    }

    // Usage-limit resets the account can still use. claude.ai's Settings > Usage reads
    // the same `cedar_ember` object from /usage with `cedar_ember=1`; we only GET it.
    func fetchLimitResets(_ orgId: String) {
        guard let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage?cedar_ember=1&skip_spend=1") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("claude.ai", forHTTPHeaderField: "authority")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                guard let self = self,
                      let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                let (left, endAt) = Self.parseLimitResets(json["cedar_ember"])
                self.limitResetsLeft = left
                self.limitResetsEndAt = endAt
                NSLog("🔄 Limit resets available: \(left)")
            }
        }.resume()
    }

    /// Counts resets still usable across grants (not paused, inside their window)
    /// and returns the earliest end date among them.
    static func parseLimitResets(_ raw: Any?, now: Date = Date()) -> (Int, Date?) {
        guard let obj = raw as? [String: Any],
              (obj["eligible"] as? Bool) == true,
              let grants = obj["grants"] as? [[String: Any]] else { return (0, nil) }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoNoFrac = ISO8601DateFormatter()
        func date(_ v: Any?) -> Date? {
            guard let s = v as? String else { return nil }
            return iso.date(from: s) ?? isoNoFrac.date(from: s)
        }
        var total = 0
        var earliestEnd: Date?
        for g in grants {
            let left = (g["resets_left"] as? Int) ?? 0
            guard left > 0, (g["paused"] as? Bool) != true,
                  let end = date(g["ends_at"]), end > now else { continue }
            if let start = date(g["starts_at"]), start > now { continue }
            total += left
            earliestEnd = min(earliestEnd ?? end, end)
        }
        return (total, earliestEnd)
    }

}
