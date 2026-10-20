import Foundation

/// Choix de l'organisation suivie quand le compte en a plusieurs (personnel + équipe).
extension UsageManager {
    func loadSelectedOrganization() {
        selectedOrganizationId = UserDefaults.standard.string(forKey: "selected_org_id")
    }

    func selectOrganization(_ id: String?) {
        selectedOrganizationId = id
        if let id { UserDefaults.standard.set(id, forKey: "selected_org_id") } else { UserDefaults.standard.removeObject(forKey: "selected_org_id") }
        hasFetchedData = false
        fetchUsage()
    }

    /// Identifiant à interroger : le choix de l'utilisateur, sinon l'organisation active de la session.
    func effectiveOrganizationId() -> String? {
        OrganizationList.resolve(selected: selectedOrganizationId, available: organizations,
                                 cookieOrg: SyncHelpers.organizationId(fromCookie: sessionCookie))
    }

    func fetchOrganizations() {
        guard !sessionCookie.isEmpty, let url = URL(string: "https://claude.ai/api/organizations") else { return }
        var request = URLRequest(url: url)
        request.setValue(sessionCookie.contains("=") ? sessionCookie : "sessionKey=\(sessionCookie)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            let found = data.map(OrganizationList.parse) ?? []
            DispatchQueue.main.async {
                guard let self, !found.isEmpty else { return }
                self.organizations = OrganizationList.followable(found)
            }
        }.resume()
    }
}
