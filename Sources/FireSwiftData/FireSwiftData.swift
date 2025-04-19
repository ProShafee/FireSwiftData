import Foundation
import FirebaseFirestore

public final class FireSwiftData {
    private let db = Firestore.firestore()
    private init() {}
    public static let shared = FireSwiftData()
}

//Extension for functions with Async/Await
extension FireSwiftData {
    
    public func save<T: FireSwiftDataRepresentable>(item: T) async throws {
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
    
    public func fetch<T: FireSwiftDataRepresentable>(_ type: T.Type) async throws -> [T] {
        let snapshot = try await db.collection(T.collectionName).order(by: "createdAt").getDocuments()
        return try snapshot.documents.compactMap { document in
            try document.data(as: T.self)
        }
    }
    
    public func delete<T: FireSwiftDataRepresentable>(_ type: T.Type, id: String) async throws {
        try await db.collection(T.collectionName).document(id).delete()
    }
}

//Extension for functions with completion
extension FireSwiftData {
    
    public func save<T: FireSwiftDataRepresentable>(item: T, completion: @escaping (Result<Void, Error>) -> ()) {
        do {
            try db.collection(T.collectionName).document(item.id).setData(from: item, merge: true)
            completion(.success(()))
        } catch (let error) {
            completion(.failure(error))
        }
    }
    
    public func fetch<T: FireSwiftDataRepresentable>(_ type: T.Type, completion: @escaping (Result<[T], Error>) -> ()) {
        db.collection(T.collectionName).order(by: "createdAt").getDocuments { snapshot, error in
            if let snapshot {
                do {
                    let data = try snapshot.documents.compactMap({
                        return try $0.data(as: type)
                    })
                    
                    completion(.success(data))
                } catch (let error) {
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func delete<T: FireSwiftDataRepresentable>(_ type: T.Type, id: String, completion: @escaping (Result<Void, Error>) -> ()) {
        db.collection(String(describing: T.self)).document(id).delete { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}

struct User: FireSwiftDataRepresentable {
    var id: String
    var name: String
}
