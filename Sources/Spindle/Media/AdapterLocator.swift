import Foundation

/// Finds the bundled adapter payload.
///
/// Inside the built .app these live in `Contents/Resources`. When running the
/// raw SwiftPM binary during development they are in `.build/adapter`, so both
/// locations are searched.
enum AdapterLocator {
    struct Payload {
        let perl: URL
        let script: URL
        let dylib: URL
    }

    enum LocatorError: LocalizedError {
        case missingPerl
        case missingResource(String)

        var errorDescription: String? {
            switch self {
            case .missingPerl:
                return "/usr/bin/perl is missing. It is required to read now-playing info."
            case .missingResource(let name):
                return "Bundled adapter file '\(name)' not found. Rebuild with ./build.sh."
            }
        }
    }

    private static let perlPath = "/usr/bin/perl"
    private static let scriptName = "stream.pl"
    private static let dylibName = "MediaRemoteAdapter.dylib"

    static func locate() throws -> Payload {
        let perl = URL(fileURLWithPath: perlPath)
        guard FileManager.default.isExecutableFile(atPath: perlPath) else {
            throw LocatorError.missingPerl
        }
        return Payload(
            perl: perl,
            script: try find(scriptName),
            dylib: try find(dylibName)
        )
    }

    private static func find(_ name: String) throws -> URL {
        for candidate in searchPaths(for: name)
        where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        throw LocatorError.missingResource(name)
    }

    private static func searchPaths(for name: String) -> [URL] {
        var paths: [URL] = []
        if let resource = Bundle.main.resourceURL {
            paths.append(resource.appendingPathComponent(name))
        }
        // Development fallback: `swift run` from the package root.
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        paths.append(cwd.appendingPathComponent(".build/adapter/\(name)"))
        paths.append(cwd.appendingPathComponent("Sources/MediaRemoteAdapter/\(name)"))
        return paths
    }
}
