import Cocoa

struct Joined<Content: AttributedStringConvertible>: AttributedStringConvertible {
    var separator: AttributedStringConvertible = "\n"
    @AttributedStringBuilder var content: Content

    func attributedString(environment: EnvironmentValues) -> [NSAttributedString] {
        [single(environment: environment)]
    }

    @MainActor
    func single(environment: EnvironmentValues) -> NSAttributedString {
        let pieces = content.attributedString(environment: environment)
        guard let f = pieces.first else { return .init() }
        let result = NSMutableAttributedString(attributedString: f)
        let sep = separator.attributedString(environment: environment)
        for piece in pieces.dropFirst() {
            for sepPiece in sep {
                result.append(sepPiece)
            }
            result.append(piece)
        }
        return result
    }
}

extension AttributedStringConvertible {
    public func joined(separator: AttributedStringConvertible = "\n") -> some AttributedStringConvertible {
        Joined(separator: separator, content: {
            self
        })
    }
}
