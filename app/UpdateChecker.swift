import Foundation

/// Dernière version publiée sur GitHub (`releases/latest`) : seule la logique pure, sans réseau.
struct ReleaseInfo: Equatable {
    let version: String
    let pageURL: URL
    /// Application zippée et sa somme SHA-256, publiées par la release ; nil si la release n'en a pas (installation manuelle).
    var zipURL: URL? = nil
    var checksumURL: URL? = nil
}

enum UpdateChecker {
    static let latestReleaseURL = URL(string: "https://api.github.com/repos/Alane38/usageforecast/releases/latest")!
    /// Une vérification toutes les 6 h suffit : les versions sortent au plus quelques fois par jour.
    static let interval: TimeInterval = 6 * 3600

    /// Lit `tag_name` (« v1.8.1 ») et `html_url` ; nil si la réponse n'est pas une release (404, brouillon, JSON inattendu).
    static func parse(_ data: Data) -> ReleaseInfo? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let json = object as? [String: Any],
              let tag = json["tag_name"] as? String,
              let link = json["html_url"] as? String, let url = URL(string: link),
              url.scheme == "https", url.host == "github.com",
              json["draft"] as? Bool != true, json["prerelease"] as? Bool != true,
              components(tag) != nil else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let assets = (json["assets"] as? [[String: Any]] ?? []).compactMap { asset -> (name: String, url: URL)? in
            guard let name = asset["name"] as? String, let link = asset["browser_download_url"] as? String,
                  let url = URL(string: link), isTrustedDownload(url) else { return nil }
            return (name, url)
        }
        let zip = assets.first { $0.name == "\(Brand.assetPrefix)-\(version)-arm64.zip" }?.url
        let checksum = assets.first { $0.name == "\(Brand.assetPrefix)-\(version)-arm64.zip.sha256" }?.url
        return ReleaseInfo(version: version, pageURL: url, zipURL: zip, checksumURL: zip == nil ? nil : checksum)
    }

    /// Un téléchargement n'est accepté que depuis les releases de ce dépôt, en HTTPS.
    static func isTrustedDownload(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "github.com" && url.path.hasPrefix("/Alane38/usageforecast/releases/download/")
    }

    /// « 1.8.1 » > « 1.8.0 », comparaison numérique composante par composante (1.10.0 > 1.9.0).
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let new = components(candidate), let old = components(current) else { return false }
        for index in 0..<max(new.count, old.count) {
            let candidatePart = index < new.count ? new[index] : 0
            let currentPart = index < old.count ? old[index] : 0
            if candidatePart == currentPart { continue }
            return candidatePart > currentPart
        }
        return false
    }

    static func shouldCheck(lastCheck: Date?, now: Date = Date()) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= interval
    }

    private static func components(_ version: String) -> [Int]? {
        let bare = version.hasPrefix("v") ? String(version.dropFirst()) : version
        let parts = bare.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        return parts.compactMap { $0 }
    }
}
