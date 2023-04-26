import Markdown
import AppKit

public struct DefaultStylesheet: Stylesheet { }

extension Stylesheet where Self == DefaultStylesheet {
    static public var `default`: Self {
        DefaultStylesheet()
    }
}

struct HighlightCode: EnvironmentKey {
    static var defaultValue: ((Code) -> NSAttributedString)? = nil
}

extension EnvironmentValues {
    public var highlightCode: ((Code) -> NSAttributedString)? {
        get {
            self[HighlightCode.self]
        }
        set {
            self[HighlightCode.self] = newValue
        }
    }
}

public struct Code: Hashable, Codable {
    public init(language: String? = nil, code: String) {
        self.language = language
        self.code = code
    }

    public var language: String?
    public var code: String
}

struct AttributedStringWalker: MarkupWalker {
    var attributes: Attributes
    let stylesheet: Stylesheet
    var makeCheckboxURL: ((ListItem) -> URL?)?
    var highlightCode: ((Code) -> NSAttributedString)?

    var attributedString = NSMutableAttributedString()

    mutating func visitDocument(_ document: Document) -> () {
        for block in document.blockChildren {
            if !attributedString.string.isEmpty {
                attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
            }
            visit(block)
        }
    }

    func visitText(_ text: Text) -> () {
        attributedString.append(NSAttributedString(string: text.string, attributes: attributes))
    }

    func visitLineBreak(_ lineBreak: LineBreak) -> () {
        attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
    }

    func visitSoftBreak(_ softBreak: SoftBreak) -> () {
        return
    }

    func visitInlineCode(_ inlineCode: InlineCode) -> () {
        var attributes = attributes
        stylesheet.inlineCode(attributes: &attributes)
        attributedString.append(NSAttributedString(string: inlineCode.code, attributes: attributes))
    }

    func visitCodeBlock(_ codeBlock: CodeBlock) -> () {
        var attributes = attributes
        let code = codeBlock.code.trimmingCharacters(in: .whitespacesAndNewlines)
        if let h = highlightCode {
            let result = h(Code(language: codeBlock.language, code: codeBlock.code))
            attributedString.append(result)
        } else {
            stylesheet.codeBlock(attributes: &attributes)
            attributedString.append(NSAttributedString(string: code, attributes: attributes))
        }
    }

    func visitInlineHTML(_ inlineHTML: InlineHTML) -> () {
        fatalError()
    }

    func visitHTMLBlock(_ html: HTMLBlock) -> () {
        fatalError()
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> () {
        let original = attributes
        defer { attributes = original }

        stylesheet.emphasis(attributes: &attributes)

        for child in emphasis.children {
            visit(child)
        }
    }

    mutating func visitStrong(_ strong: Strong) -> () {
        let original = attributes
        defer { attributes = original }

        stylesheet.strong(attributes: &attributes)

        for child in strong.children {
            visit(child)
        }
    }

    func visitCustomBlock(_ customBlock: CustomBlock) -> () {
        fatalError()
    }

    func visitCustomInline(_ customInline: CustomInline) -> () {
        fatalError()
    }

    mutating func visitLink(_ link: Link) -> () {
        let original = attributes
        defer { attributes = original }

        stylesheet.link(attributes: &attributes)
        attributes.link = link.destination.flatMap(URL.init(string:))

        for child in link.children {
            visit(child)
        }
    }

    mutating func visitHeading(_ heading: Heading) -> () {
        let original = attributes
        defer { attributes = original }
        stylesheet.heading(level: heading.level, attributes: &attributes)
        attributes.heading(title: heading.plainText, level: heading.level)
        for child in heading.children {
            visit(child)
        }
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> () {
        visit(list: orderedList)
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> () {
        visit(list: unorderedList)
    }

    mutating private func visit(list: ListItemContainer) {
        let original = attributes
        defer { attributes = original }

        stylesheet.list(attributes: &attributes)

        let isOrdered = list is OrderedList

        attributes.headIndent += attributes.tabStops[1].location

        for (item, number) in zip(list.listItems, 1...) {
            // Append list item prefix
            let prefix: String
            var prefixAttributes = attributes
            
            if let checkbox = item.checkbox {
                switch checkbox {
                case .checked:
                    prefix = stylesheet.checkboxCheckedPrefix
                    stylesheet.checkboxCheckedPrefix(attributes: &prefixAttributes)
                case .unchecked:
                    prefix = stylesheet.checkboxUncheckedPrefix
                    stylesheet.checkboxUncheckedPrefix(attributes: &prefixAttributes)
                }
                if let url = makeCheckboxURL?(item) {
                    prefixAttributes.link = url
                }
            } else {
                if isOrdered {
                    stylesheet.orderedListItemPrefix(attributes: &prefixAttributes)
                    prefix = stylesheet.orderedListItemPrefix(number: number)
                } else {
                    stylesheet.unorderedListItemPrefix(attributes: &prefixAttributes)
                    prefix = stylesheet.unorderedListItemPrefix
                }
            }
            
            if number == list.childCount {
                // Restore spacing for last list item
                attributes.paragraphSpacing = original.paragraphSpacing
                prefixAttributes.paragraphSpacing = original.paragraphSpacing
            }
            
            attributedString.append(NSAttributedString(string: "\t", attributes: attributes))
            attributedString.append(NSAttributedString(string: prefix, attributes: prefixAttributes))
            attributedString.append(NSAttributedString(string: "\t", attributes: attributes))

            visit(item)
            if number < list.childCount {
                attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
            }
        }
    }

    mutating func visitListItem(_ listItem: ListItem) -> () {
        let original = attributes
        defer { attributes = original }

        stylesheet.listItem(attributes: &attributes, checkbox: listItem.checkbox?.bool)

        var first = true
        for child in listItem.children {
            if !first {
                attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
            }
            first = false
            visit(child)
        }
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> () {
        let original = attributes
        defer { attributes = original }
        stylesheet.blockQuote(attributes: &attributes)
        for child in blockQuote.children {
            visit(child)
        }
    }

    func visitThematicBreak(_ thematicBreak: ThematicBreak) -> () {
        // TODO we could consider making this stylable, but ideally the stylesheet doesn't know about NSAttributedString?
        let thematicBreak = NSAttributedString(string: "\n\r\u{00A0} \u{0009} \u{00A0}\n\n", attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue, .strikethroughColor: NSColor.gray])
        attributedString.append(thematicBreak)

    }
}

extension Checkbox {
    var bool: Bool {
        get {
            self == .checked
        }
        set {
            self = newValue ? .checked : .unchecked
        }
    }
}

fileprivate struct MarkdownHelper: AttributedStringConvertible {
    var document: Document
    var stylesheet: any Stylesheet
    var makeCheckboxURL: ((ListItem) -> URL?)?
    var highlightCode: ((Code) -> NSAttributedString)?

    func attributedString(environment: EnvironmentValues) -> [NSAttributedString] {
        var walker = AttributedStringWalker(attributes: environment.attributes, stylesheet: stylesheet, makeCheckboxURL: makeCheckboxURL, highlightCode: highlightCode)
        walker.visit(document)
        return [walker.attributedString]
    }
}

public struct Markdown: AttributedStringConvertible {
    public var source: String
    public init(_ source: String) {
        self.source = source
    }

    public func attributedString(environment: EnvironmentValues) async -> [NSAttributedString] {
        await EnvironmentReader(\.markdownStylesheet) { stylesheet in
            EnvironmentReader(\.highlightCode) { highlightCode in
                MarkdownHelper(string: source, stylesheet: stylesheet, highlightCode: highlightCode)
            }
        }.attributedString(environment: environment)
    }
}

extension MarkdownHelper {
    init(string: String, stylesheet: any Stylesheet, highlightCode: ((Code) -> NSAttributedString)? = nil) {
        self.document = Document(parsing: string)
        self.stylesheet = stylesheet
        self.makeCheckboxURL = nil
        self.highlightCode = highlightCode
    }
}

struct MarkdownStylesheetKey: EnvironmentKey {
    static var defaultValue: any Stylesheet = .default
}

extension EnvironmentValues {
    public var markdownStylesheet: any Stylesheet {
        get { self[MarkdownStylesheetKey.self] }
        set { self[MarkdownStylesheetKey.self] = newValue }
    }
}

extension String {
    public func markdown(stylesheet: any Stylesheet = .default, highlightCode: ((Code) -> NSAttributedString)? = nil) -> some AttributedStringConvertible {
        var result = MarkdownHelper(string: self, stylesheet: stylesheet)
        result.highlightCode = highlightCode
        return result
    }
}

extension Document {
    public func markdown(stylesheet: any Stylesheet = .default, makeCheckboxURL: ((ListItem) -> URL?)? = nil) -> some AttributedStringConvertible {
        MarkdownHelper(document: self, stylesheet: stylesheet, makeCheckboxURL: makeCheckboxURL)
    }
}
