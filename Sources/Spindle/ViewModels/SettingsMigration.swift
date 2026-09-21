import Foundation

/// Carries saved settings across a change of bundle identifier.
///
/// `UserDefaults.standard` is keyed by the bundle identifier, so renaming the
/// app moves it to an empty domain: skin, size, placement, every toggle and the
/// widget's position on screen would silently reset on upgrade, and the old
/// values would sit orphaned in a plist nothing reads.
///
/// Runs once, before any settings are read, and never overwrites a value the
/// new domain already holds.
enum SettingsMigration {

    /// Identifiers this app has shipped under, **newest first**. The order is
    /// what makes a second rename safe: a key found in a more recent domain
    /// wins over the same key in an older one.
    static let legacyDomains = [
        "nl.jopmors.Podlet",
        "nl.jopmors.iPodWidget"
    ]

    /// Stored in the new domain, so the copy happens exactly once even if the
    /// old plists are still on disk afterwards.
    private static let markerKey = "migration.fromLegacyDomain"

    /// `from` exists so tests can point at domains they invented.
    ///
    /// `setPersistentDomain` and `removePersistentDomain` act on the named
    /// domain for the whole user, not on the `UserDefaults` instance they are
    /// sent to — so a test that seeds and cleans up the *real* legacy domains
    /// destroys the preferences of the installed app. This one did exactly
    /// that before it took the list as an argument.
    @discardableResult
    static func run(
        into defaults: UserDefaults = .standard,
        from domains: [String] = legacyDomains
    ) -> Int {
        guard defaults.object(forKey: markerKey) == nil else { return 0 }
        defaults.set(true, forKey: markerKey)

        var carried = 0
        for domain in domains {
            let legacy = defaults.persistentDomain(forName: domain) ?? [:]
            for (key, value) in legacy where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
                carried += 1
            }
        }
        if carried > 0 {
            Diagnostics.log("carried \(carried) settings over from a previous name")
        }
        return carried
    }
}
