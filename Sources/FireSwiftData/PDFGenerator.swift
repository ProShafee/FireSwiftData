import Foundation
import PDFKit

public final class PDFGenerator {

    public static let shared = PDFGenerator()

    public func createPDF<T: FireSwiftDataRepresentable>(_ allData: [[T]]) -> PDFDocument {
        let pdfDocument = PDFDocument()

        for (index, dataSet) in allData.enumerated() {
            guard let first = dataSet.first else { continue }

            let mirror = Mirror(reflecting: first)
            let headers = mirror.children.compactMap { $0.label }

            let rows = dataSet.map { obj in
                Mirror(reflecting: obj).children.map { formatValue($0.value) }
            }

            if let page = createPDFPage(title: T.collectionName, headers: headers, rows: rows) {
                pdfDocument.insert(page, at: index)
            }
        }

        return pdfDocument
    }

    /// Formats the value for PDF display
    func formatValue(_ value: Any) -> String {
        let mirror = Mirror(reflecting: value)

        // Handle Optional values manually
        if mirror.displayStyle == .optional {
            if let child = mirror.children.first {
                return formatValue(child.value)
            } else {
                return "nil"
            }
        }

        // Handle arrays of Identifiable
        if let identifiableArray = value as? [any Identifiable] {
            return identifiableArray.map { "\($0.id)" }.joined(separator: ", ")
        }

        return "\(value)"
    }

    func createPDFPage(title: String, headers: [String], rows: [[String]]) -> PDFPage? {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 20
        let titleHeight: CGFloat = 30
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        UIGraphicsBeginImageContextWithOptions(pageRect.size, true, 0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(pageRect)

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20)
        ]
        let titlePoint = CGPoint(x: margin, y: margin)
        title.draw(at: titlePoint, withAttributes: titleAttributes)

        var yOffset = margin + titleHeight
        let columnWidth = (pageWidth - margin * 2) / CGFloat(headers.count)

        let textFont = UIFont.systemFont(ofSize: 12)
        let textAttributes: [NSAttributedString.Key: Any] = [.font: textFont]

        // Draw headers
        let headerHeight: CGFloat = 24
        for (index, header) in headers.enumerated() {
            let rect = CGRect(x: margin + CGFloat(index) * columnWidth, y: yOffset, width: columnWidth, height: headerHeight)
            context.stroke(rect)
            header.draw(in: rect.insetBy(dx: 4, dy: 4), withAttributes: textAttributes)
        }

        yOffset += headerHeight

        // Draw rows with dynamic height
        for row in rows {
            // Calculate height for each cell and take the max
            let rowHeights = row.enumerated().map { (index, text) -> CGFloat in
                let boundingSize = CGSize(width: columnWidth - 8, height: .greatestFiniteMagnitude)
                let boundingRect = NSString(string: text).boundingRect(
                    with: boundingSize,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: textAttributes,
                    context: nil
                )
                return ceil(boundingRect.height + 8)
            }
            let maxRowHeight = rowHeights.max() ?? 24

            // Check page overflow
            if yOffset + maxRowHeight > pageHeight - margin {
                break
            }

            // Draw cells
            for (index, cell) in row.enumerated() {
                let rect = CGRect(x: margin + CGFloat(index) * columnWidth, y: yOffset, width: columnWidth, height: maxRowHeight)
                context.stroke(rect)
                cell.draw(in: rect.insetBy(dx: 4, dy: 4), withAttributes: textAttributes)
            }

            yOffset += maxRowHeight
        }

        guard let image = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        return PDFPage(image: image)
    }
}
