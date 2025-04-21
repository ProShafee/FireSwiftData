//
//  PDFGenerator.swift
//  FireSwiftData
//
//  Created by Shafee Rehman on 21/04/2025.
//


import Foundation
import PDFKit

final class PDFGenerator {
    
    static let shared = PDFGenerator()

    func createPDF(_ allData: [Any]) -> PDFDocument {
        let pdfDocument = PDFDocument()
        var pageIndex = 0

        for dataSet in allData {
            // Ensure it’s a non-empty array of FireSwiftDataRepresentable
            guard let validArray = dataSet as? [any FireSwiftDataRepresentable],
                  let first = validArray.first else {
                continue // skip invalid or empty
            }

            let mirror = Mirror(reflecting: first)
            let headers = mirror.children.compactMap { $0.label }

            let rows = validArray.map { obj in
                Mirror(reflecting: obj).children.map { formatValue($0.value) }
            }

            if let page = createPDFPage(title: type(of: first).collectionName, headers: headers, rows: rows) {
                pdfDocument.insert(page, at: pageIndex)
                pageIndex += 1
            }
        }

        return pdfDocument
    }

    private func formatValue(_ value: Any) -> String {
        let mirror = Mirror(reflecting: value)

        if mirror.displayStyle == .optional {
            if let child = mirror.children.first {
                return formatValue(child.value)
            } else {
                return "nil"
            }
        }

        if let identifiableArray = value as? [any Identifiable] {
            return identifiableArray.map { "\($0.id)" }.joined(separator: ", ")
        }

        return "\(value)"
    }

    private func createPDFPage(title: String, headers: [String], rows: [[String]]) -> PDFPage? {
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

        let titleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 20)]
        let textAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]

        let titlePoint = CGPoint(x: margin, y: margin)
        title.draw(at: titlePoint, withAttributes: titleAttributes)

        var yOffset = margin + titleHeight
        let columnWidth = (pageWidth - margin * 2) / CGFloat(headers.count)
        let headerHeight: CGFloat = 24

        for (index, header) in headers.enumerated() {
            let rect = CGRect(x: margin + CGFloat(index) * columnWidth, y: yOffset, width: columnWidth, height: headerHeight)
            context.stroke(rect)
            header.draw(in: rect.insetBy(dx: 4, dy: 4), withAttributes: textAttributes)
        }

        yOffset += headerHeight

        for row in rows {
            let rowHeights = row.enumerated().map { (_, text) -> CGFloat in
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

            if yOffset + maxRowHeight > pageHeight - margin {
                break
            }

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
