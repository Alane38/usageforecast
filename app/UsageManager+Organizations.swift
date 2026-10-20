import Foundation

/// Choix de l'organisation suivie quand le compte en a plusieurs (personnel + équipe).
extension UsageManager {
    private static let selectedOrganizationKey = "selected_org_id"

    func loadSelectedOrganization() {
        selectedOrganizationId = UserDefaults.standard.string(forKey: Self.selectedOrganizationKey)
    }

    func selectOrganization(_ id: String?) {
        persistSelectedOrganization(id)
        // Les données affichées appartenaient à l'ancienne organisation : on repart de zéro.
        (selectedOrganizationId, hasFetchedData) = (id, false)
        fetchUsage()
    }

    private func persistSelectedOrganization(_ id: String?) {
        let defaults = UserDefaults.standard
        guard let id else {
            defaults.removeObject(forKey: Self.selectedOrganizationKey)
            return
        }
        defaults.set(id, forKey: Self.selectedOrganizationKey)
    }

    /// Identifiant à interroger : le choix de l'utilisateur, sinon l'organisation active de la session.
    func effectiveOrganizationId() -> String? {
        let cookieOrg = SyncHelpers.organizationId(fromCookie: sessionCookie)
        return OrganizationList.resolve(selected: selectedOrganizationId,
                                        available: organizations,
                                        cookieOrg: cookieOrg)
    }

    func fetchOrganizations() {
        guard !sessionCookie.isEmpty else { return }
        let cookieHeader = sessionCookie.contains("=") ? sessionCookie : "sessionKey=\(sessionCookie)"
        let headers = ["Cookie": cookieHeader, "Accept": "application/json"]
        guard let request = claudeRequest("https://claude.ai/api/organizations", headers: headers) else { return }

        perform(request) { [weak self] data, _ in
            let found = data.map(OrganizationList.parse) ?? []
            guard !found.isEmpty else { return }
            DispatchQueue.main.async { self?.organizations = OrganizationList.followable(found) }
        }
    }
}
