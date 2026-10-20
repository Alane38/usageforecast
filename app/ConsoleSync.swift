import Foundation

/// Synchronisation des crédits API de la Console (`platform.claude.com`) et import des sessions du navigateur.
extension UsageManager {
    private static let secrets = AppSecrets.store
    private static let consoleAccount = AppSecrets.consoleAccount

    func loadConsoleCookie() {
        guard !CommandLine.arguments.contains("--no-keychain") else { return }
        consoleCookie = Self.secrets.read(account: Self.consoleAccount) ?? ""
    }

    func saveConsoleCookie(_ cookie: String) {
        consoleCookie = cookie
        if !Self.secrets.write(cookie, account: Self.consoleAccount) {
            NSLog("ClaudeUsage: secret storage write failed for the Console session")
        }
    }

    func disconnectConsole() {
        consoleCookie = ""
        consoleBalance = nil
        consoleUpdatedAt = nil
        consoleStatus = "Console non connectée"
        Self.secrets.delete(account: Self.consoleAccount)
    }

    func fetchConsoleBalance() {
        guard !consoleCookie.isEmpty else {
            consoleStatus = "Console non connectée"
            return
        }
        guard let orgId = SyncHelpers.organizationId(fromCookie: consoleCookie) else {
            consoleStatus = "Cookie Console sans lastActiveOrg : colle l'en-tête Cookie complet"
            return
        }

        var responses: [String: (status: Int, data: Data?)] = [:]
        let group = DispatchGroup()
        for path in ["prepaid/credits", "current_spend"] {
            group.enter()
            URLSession.shared.dataTask(with: consoleRequest(orgId: orgId, path: path)) { data, response, _ in
                DispatchQueue.main.async {
                    responses[path] = ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
                    group.leave()
                }
            }.resume()
        }
        group.notify(queue: .main) { [weak self] in self?.applyConsole(responses) }
    }

    private func consoleRequest(orgId: String, path: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://platform.claude.com/api/organizations/\(orgId)/\(path)")!)
        request.setValue(consoleCookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("web_console", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("https://platform.claude.com/settings/billing", forHTTPHeaderField: "Referer")
        request.setValue("https://platform.claude.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func applyConsole(_ responses: [String: (status: Int, data: Data?)]) {
        let credits = responses["prepaid/credits"]
        let status = credits?.status ?? 0

        if status == 401 || status == 403 {
            // Session périmée : on tente une fois de la reprendre dans le navigateur, sans boucler.
            if shouldAutoImport(), importBrowserCookies(), !consoleCookie.isEmpty {
                fetchConsoleBalance()
            } else {
                consoleStatus = "Console : session expirée (HTTP \(status)). Reconnecte-toi."
            }
            return
        }
        guard status == 200, let data = credits?.data,
              let balance = ConsoleBalance.parse(credits: data, spend: responses["current_spend"]?.data) else {
            consoleStatus = "Console : réponse inattendue (HTTP \(status))"
            return
        }
        consoleBalance = balance
        consoleUpdatedAt = Date()
        consoleStatus = ""
        evaluateAlerts()
    }

    // MARK: - Import depuis le navigateur

    /// Limite les reprises automatiques à une toutes les 10 minutes.
    func shouldAutoImport(now: Date = Date()) -> Bool {
        if let last = lastAutoImport, now.timeIntervalSince(last) < 600 { return false }
        lastAutoImport = now
        return true
    }

    /// Reprend les sessions claude.ai et Console depuis Zen/Firefox. Les cookies vont directement dans le Keychain.
    @discardableResult
    func importBrowserCookies() -> Bool {
        var imported: [String] = []
        if let header = FirefoxCookies.cookieHeader(domain: "claude.ai") {
            saveSessionCookie(header)
            imported.append("claude.ai")
        }
        if let header = FirefoxCookies.cookieHeader(domain: "claude.com") {
            saveConsoleCookie(header)
            imported.append("Console")
        }
        browserAccessDenied = imported.isEmpty && FirefoxCookies.accessDenied()
        if imported.isEmpty {
            browserImportReport = browserAccessDenied
                ? "macOS bloque la lecture de ton navigateur : \(Brand.name) a besoin de l'Accès complet au disque."
                : "Aucune session trouvée dans Zen/Firefox : connecte-toi à claude.ai et à platform.claude.com dans ce navigateur."
        } else {
            browserImportReport = "Importé : " + imported.joined(separator: ", ")
        }
        return !imported.isEmpty
    }

    // MARK: - Sonde de développement

    /// `--probe-console` : liste les organisations de la Console puis lit solde et dépense de celle qui a la capacité « api ».
    /// N'imprime que des statuts, des noms de champs et des valeurs (identifiants masqués) ; jamais le cookie.
    func probeConsole() {
        guard !sessionCookie.isEmpty else { print("sonde : pas de cookie claude.ai"); return }
        func get(_ path: String) -> (Int, Any?) {
            var request = URLRequest(url: URL(string: "https://platform.claude.com/api/\(path)")!)
            request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("web_console", forHTTPHeaderField: "anthropic-client-platform")
            request.setValue("https://platform.claude.com/settings/billing", forHTTPHeaderField: "Referer")
            request.setValue("https://platform.claude.com", forHTTPHeaderField: "Origin")
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            let done = DispatchSemaphore(value: 0)
            var result: (Int, Any?) = (0, nil)
            URLSession.shared.dataTask(with: request) { data, response, _ in
                result = ((response as? HTTPURLResponse)?.statusCode ?? 0, data.flatMap { try? JSONSerialization.jsonObject(with: $0) })
                done.signal()
            }.resume()
            done.wait()
            return result
        }
        func masked(_ value: Any) -> Any {
            if let text = value as? String, text.range(of: "^[0-9a-f]{8}-[0-9a-f-]{27}$", options: .regularExpression) != nil { return "<uuid>" }
            if let dict = value as? [String: Any] { return dict.mapValues(masked) }
            if let list = value as? [Any] { return list.map(masked) }
            return value
        }

        let (status, orgs) = get("organizations")
        guard let list = orgs as? [[String: Any]],
              let api = list.first(where: { (($0["capabilities"] as? [String]) ?? []).contains("api") }),
              let orgId = api["uuid"] as? String else { print("sonde : organisations -> HTTP \(status), pas d'org api"); return }
        print("sonde : org api trouvée ; free_credits_status =", masked(api["free_credits_status"] ?? "absent"),
              "| billing_type =", api["billing_type"] ?? "-", "| api_disabled_reason =", api["api_disabled_reason"] ?? "nil")
        for path in ["prepaid/credits", "current_spend", "rate_limits"] {
            let (code, body) = get("organizations/\(orgId)/\(path)")
            print("sonde : \(path) -> HTTP \(code)", body.map { masked($0) } ?? "(vide)")
        }
    }

    #if !RELEASE
    /// Reprend les cookies de l'ancien stockage (trousseau). macOS demande le mot de passe une fois, à l'initiative de l'utilisateur.
    func importLegacyKeychain() {
        let legacy = KeychainStore(service: AppSecrets.keychainService)
        var imported: [String] = []
        if let value = legacy.read(account: AppSecrets.claudeAccount) { saveSessionCookie(value); imported.append("claude.ai") }
        if let value = legacy.read(account: AppSecrets.consoleAccount) { saveConsoleCookie(value); imported.append("Console") }
        legacyImportReport = imported.isEmpty ? "Rien trouvé dans l'ancien trousseau." : "Importé depuis le trousseau : " + imported.joined(separator: ", ")
        if !imported.isEmpty { fetchUsage() }
    }
    #endif
}

