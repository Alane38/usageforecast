import Foundation

/// Historique des relevés et grandeurs qui en découlent (rythme récent, consommation du jour).
extension UsageManager {
    /// Les lancements de vérification (aperçus, sondes) ne doivent jamais écrire dans l'historique réel.
    var isProbeRun: Bool {
        !Set(CommandLine.arguments).isDisjoint(with: ["--snapshot", "--demo", "--no-keychain", "--diagnose", "--probe-console"])
    }

    func loadHistory() {
        guard !isProbeRun else { return }
        // Reprise de l'existant : tous les relevés encore présents deviennent des résumés quotidiens AVANT la purge des 8 jours.
        refreshDailySummaries(from: history.load(since: .distantPast))
        history.prune()
        historySamples = history.load(since: Date().addingTimeInterval(-24 * 3600))
    }

    /// Met à jour `daily.jsonl` avec les relevés donnés (le résumé le plus complet de chaque jour est conservé).
    func refreshDailySummaries(from samples: [UsageSample]) {
        guard !samples.isEmpty else { dailySummaries = dailyHistory.load(); return }
        let merged = DailyStats.merge(existing: dailyHistory.load(), fresh: DailyStats.summarize(samples))
        dailyHistory.save(merged)
        dailySummaries = merged
        lastDailyUpdate = Date()
    }

    /// Un relevé par minute au plus. `date` : instant de la donnée (celui du fichier pour le statusline).
    func recordSample(at date: Date = Date()) {
        guard !isProbeRun, hasFetchedData || sessionUsage + weeklyUsage > 0 else { return }
        if let last = lastRecordedAt, date.timeIntervalSince(last) < 50 { return }
        lastRecordedAt = date
        let sample = UsageSample(time: date.timeIntervalSince1970,
                                 session: sessionResetsAt == nil ? nil : Double(sessionUsage),
                                 weekly: weeklyResetsAt == nil ? nil : Double(weeklyUsage))
        history.append(sample)
        historySamples.append(sample)
        let cutoff = date.addingTimeInterval(-24 * 3600).timeIntervalSince1970
        historySamples.removeAll { $0.time < cutoff }
        exportForecast(now: date)
        // Résumé de la journée : toutes les 10 minutes suffit.
        if lastDailyUpdate.map({ date.timeIntervalSince($0) >= 600 }) ?? true { refreshDailySummaries(from: historySamples) }
        sendMobileSnapshotIfEnabled(now: date)
    }

    /// La prévision courante, telle que la lisent le statusline de Claude Code et le téléphone.
    func currentForecast(now: Date = Date()) -> ForecastExport {
        ForecastExport.make(
            now: now,
            sessionPercent: sessionResetsAt == nil ? nil : Double(sessionUsage), sessionResetsAt: sessionResetsAt,
            sessionForecast: sessionForecast, sessionRecent: sessionRecentForecast,
            weeklyPercent: weeklyResetsAt == nil ? nil : Double(weeklyUsage), weeklyResetsAt: weeklyResetsAt,
            weeklyForecast: weeklyForecast, weeklyRecent: weeklyRecentForecast,
            usedToday: weeklyUsedToday, credits: consoleBalance)
    }

    /// Écrit la prévision courante dans un fichier lu par le statusline de Claude Code (si l'export est activé).
    func exportForecast(now: Date = Date()) {
        guard !isProbeRun, exportsForecast, let data = currentForecast(now: now).encoded() else { return }
        let url = ForecastExport.defaultURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    var sessionRecentRate: Double? { UsageAnalytics.recentRate(historySamples, series: .session) }
    /// Sur 24 h au moins 12 h observées : les nuits comptent, sinon on extrapolerait l'activité de la journée à tout le reste.
    var weeklyRecentRate: Double? {
        UsageAnalytics.recentRate(historySamples, series: .weekly, lookback: 24 * 3600, minElapsed: 12 * 3600)
    }
    var weeklyUsedToday: Double? { usedTodayOverride ?? UsageAnalytics.usedToday(historySamples, series: .weekly) }
    var dayBudget: DayBudget? {
        DayBudget.make(weeklyUsed: Double(weeklyUsage), usedToday: weeklyUsedToday, now: AppClock.now, resetsAt: weeklyResetsAt)
    }

    var sessionRecentForecast: RecentForecast? {
        guard let rate = sessionRecentRate, let resetsAt = sessionResetsAt else { return nil }
        return RecentForecast.make(ratePerHour: rate, used: Double(sessionUsage), resetsAt: resetsAt)
    }

    var weeklyRecentForecast: RecentForecast? {
        guard let rate = weeklyRecentRate, let resetsAt = weeklyResetsAt else { return nil }
        return RecentForecast.make(ratePerHour: rate, used: Double(weeklyUsage), resetsAt: resetsAt)
    }
}
