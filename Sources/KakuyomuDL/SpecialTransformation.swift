import EpubBuilder

extension Book {
    enum SpecialTransformationID: String {
        case 微熱の糸が灼きついてほどけないので = "1177354054917306070"
        case アフタヌーンティーは如何ですか？ = "16818023214131449614"
    }

    mutating func applySpecialTransformation(id: String) {
        guard let transformationID = SpecialTransformationID(rawValue: id) else {
            return
        }

        print("Applying special transformation for work ID \(id)")

        switch transformationID {
        case .微熱の糸が灼きついてほどけないので:
            func transformTitle(_ title: String) -> String {
                var title = title
                let final = /^(\d+)\.\s*=\s*(.*)$/
                if let match = title.firstMatch(of: final) {
                    title.replaceSubrange(match.range, with: "\(match.1)＝\(match.2)")
                    return title
                }

                let dot = /^\s*(\d+)\.\s*(.*)$/
                if let match = title.firstMatch(of: dot) {
                    title.replaceSubrange(match.range, with: "\(match.1)・\(match.2)")
                    return title
                }
                let sharp = /^#(\d+)\.\s*(.*)$/
                if let match = title.firstMatch(of: sharp) {
                    title.replaceSubrange(match.range, with: "\(match.1)＃\(match.2)")
                    return title
                }
                let wideSharp = /^=\/\/=\s*(\d+)\.\s*(.*)$/
                if let match = title.firstMatch(of: wideSharp) {
                    title.replaceSubrange(match.range, with: "\(match.1)／\(match.2)")
                    return title
                }
                return title
            }
            for i in sections.indices {
                for j in sections[i].subsections.indices {
                    sections[i].subsections[j].title = transformTitle(sections[i].subsections[j].title)
                }
            }
        case .アフタヌーンティーは如何ですか？:
            let normal = /^([\s　]+)[^「　\s]/
            let quote = /^([\s　]+)「/
            for i in sections.indices {
                for j in sections[i].subsections.indices {
                    for k in sections[i].subsections[j].content.indices {
                        let content = sections[i].subsections[j].content[k]
                        if case .paragraph(let text) = content {
                            if let match = text.firstMatch(of: normal) {
                                sections[i].subsections[j].content[k] = .paragraph("　" + text[match.1.endIndex...])
                            }
                            else if let match = text.firstMatch(of: quote) {
                                sections[i].subsections[j].content[k] = .paragraph(String(text[match.1.endIndex...]))
                            }
                        }
                    }
                }
            }
        }
    }
}