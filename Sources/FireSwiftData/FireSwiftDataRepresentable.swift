//
//  File.swift
//  FireSwiftData
//
//  Created by Shafee Rehman on 19/04/2025.
//

import Foundation
import FirebaseFirestore

public protocol FireSwiftDataRepresentable: Codable, Identifiable {
    var id: String { get }
    static var collectionName: String { get }
}

extension FireSwiftDataRepresentable {
    // Dynamically sets the collection name based on struct name
    public static var collectionName: String {
        return String(describing: Self.self)
    }
}
