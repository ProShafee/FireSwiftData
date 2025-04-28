import Foundation
import PDFKit
import FirebaseFirestore
import PDFGenerator

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
            if let page = PDFGenerator.createPDFPage(title: type(of: representableFirst).collectionName, headers: headers, rows: rows) {
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
}
