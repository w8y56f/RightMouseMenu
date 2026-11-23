import Foundation

enum OfficeDocument {
    static func create(at url: URL) throws {
        var data = Data()
        if ["docx", "xlsx", "pptx"].contains(url.pathExtension) {
            guard let template = Bundle.main.url(forResource: "Blank", withExtension: url.pathExtension, subdirectory: "Templates") else {
                throw CocoaError(.fileReadNoSuchFile)
            }
            data = try Data(contentsOf: template)
        }
        try data.write(to: url, options: .withoutOverwriting)
    }
}
