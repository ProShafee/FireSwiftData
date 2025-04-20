import Foundation
import FirebaseFirestore

public final class FireSwiftData {
    private let db = Firestore.firestore()
    private init() {}
    public static let shared = FireSwiftData()
    
    private let concurrentQueue = DispatchQueue(label: "com.FireSwiftData.concurrentQueue", attributes: .concurrent)
}

//Extension for functions with completion
extension FireSwiftData {
    public func save<T: FireSwiftDataRepresentable>(item: T, completion: @escaping (Result<Void, Error>) -> ()) {
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
    public func readBatch<T: FireSwiftDataRepresentable>(_ types: [T.Type]) async -> [Result<[T], Error>] {
        return await withTaskGroup(of: Result<[T], Error>.self) { group in
            var results: [Result<[T], Error>] = []
            for type in types {
                group.addTask {
                    do {
                        let snapshot = try await self.db.collection(type.collectionName).getDocuments()
                        let data = try snapshot.documents.compactMap { try $0.data(as: T.self) }
                        return .success(data)
                    } catch (let error) {
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
