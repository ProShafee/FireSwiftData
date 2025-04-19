//
//  File.swift
//  FireSwiftData
//
//  Created by Shafee Rehman on 19/04/2025.
//

import Foundation

public protocol FireSwiftDataRepresentable: Codable, Identifiable {
    var id: String { get }
    var createdAt: Date { get }
    
    static var collectionName: String { get }
}

extension FireSwiftDataRepresentable {
    // Automatically assigns the current date when accessed
    public var createdAt: Date {
        return Date()
    }

    // Dynamically sets the collection name based on struct name
    public static var collectionName: String {
        return String(describing: Self.self)
    }
}
