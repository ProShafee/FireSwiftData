import Foundation
import PDFKit
import FirebaseFirestore

public final class FireSwiftData {
    private let db = Firestore.firestore()
    private init() {}
    public static let shared = FireSwiftData()
    
    private let concurrentQueue = DispatchQueue(label: "com.FireSwiftData.concurrentQueue", attributes: .concurrent)
}

//Extension for functions with completion
extension FireSwiftData {
    public func write<T: FireSwiftDataRepresentable>(item: T, completion: @escaping (Result<Void, Error>) -> ()) {
        concurrentQueue.async(flags: .barrier) {
            do {
                try self.db.collection(T.collectionName).document(item.id).setData(from: item, merge: true) { error in
                    if let error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            } catch(let error) {
                completion(.failure(error))
            }
        }
    }

    public func delete<T: FireSwiftDataRepresentable>(_ type: T.Type, id: String, completion: @escaping (Result<Void, Error>) -> ()) {
        concurrentQueue.async(flags: .barrier) {
            self.db.collection(T.collectionName).document(id).delete { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    public func read<T: FireSwiftDataRepresentable>(_ type: T.Type, completion: @escaping (Result<[T], Error>) -> ()) {
        concurrentQueue.async {
            self.db.collection(T.collectionName).getDocuments { snapshot, error in
                if let snapshot {
                    do {
                        let data = try snapshot.documents.compactMap {
                            try $0.data(as: T.self)
                        }
                        completion(.success(data))
                    } catch(let error) {
                        completion(.failure(error))
                    }
                } else if let error {
                    completion(.failure(error))
                }
            }
        }
    }
}

//Extension for functions with Async/Await
extension FireSwiftData {
    @FireSwiftDataActor
    public func write<T: FireSwiftDataRepresentable>(item: T) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try db.collection(T.collectionName).document(item.id).setData(from: item, merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            } catch(let error) {
                continuation.resume(throwing: error)
            }
        }
    }
    
    @FireSwiftDataActor
    public func delete<T: FireSwiftDataRepresentable>(_ type: T.Type, id: String) async throws {
        try await db.collection(T.collectionName).document(id).delete()
    }
    
    @FireSwiftDataActor
    public func read<T: FireSwiftDataRepresentable>(_ type: T.Type) async throws -> [T] {
        let snapshot = try await db.collection(T.collectionName).getDocuments()
        return try snapshot.documents.compactMap { document in
            try document.data(as: T.self)
        }
    }
    
    @FireSwiftDataActor
    public func readBatch(_ types: [any FireSwiftDataRepresentable.Type]) async -> [Result<[any FireSwiftDataRepresentable], Error>] {
        return await withTaskGroup(of: Result<[any FireSwiftDataRepresentable], Error>.self) { group in
            var results: [Result<[any FireSwiftDataRepresentable], Error>] = []
            for type in types {
                group.addTask {
                    do {
                        let snapshot = try await self.db
                            .collection(type.collectionName)
                            .getDocuments()

                        let data = try snapshot.documents.compactMap {
                            try $0.data(as: type)
                        }

                        return .success(data)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            for await result in group {
                results.append(result)
            }
            
            return results
        }
    }
}

//Report Generator
extension FireSwiftData {
    public func generatePDFReport(_ allData: [[any FireSwiftDataRepresentable]]) -> PDFDocument {
        let pdfDocument = PDFDocument()

        for (index, dataSet) in allData.enumerated() {
            // Skip empty arrays
            guard let first = dataSet.first else { continue }

            // We already know that the dataSet contains elements conforming to FireSwiftDataRepresentable
            let representableFirst = first as any FireSwiftDataRepresentable

            // Get headers based on properties of the conforming type
            let mirror = Mirror(reflecting: representableFirst)
            let headers = mirror.children.compactMap { $0.label }

            // Map data to rows based on type
            let rows = dataSet.compactMap { item -> [String]? in
                // Each item in dataSet is already a conforming FireSwiftDataRepresentable
                let conformingItem = item as any FireSwiftDataRepresentable
                return Mirror(reflecting: conformingItem).children.map { formatValue($0.value) }
            }

            // Create and insert the PDF page for the data set
            if let page = createPDFPage(title: type(of: representableFirst).collectionName, headers: headers, rows: rows) {
                pdfDocument.insert(page, at: index)
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
                return ""
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
