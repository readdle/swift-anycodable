//
//  AnyCodable.swift
//
//  Created by Andrew on 11/16/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

import Foundation

public struct AnyCodable: Codable {
    
    private typealias AnyEncodableClosure = (Encodable, inout KeyedEncodingContainer<CodingKeys>) throws -> Void
    private typealias AnyDecodableClosure = (KeyedDecodingContainer<CodingKeys>) throws -> Decodable
    
    private static var encodableClosures = [String: AnyEncodableClosure]()
    private static var decodableClosures = [String: AnyDecodableClosure]()

    public static let ArrayTypeName = "Array"
    public static let DictionaryTypeName = "Dictionary"
    
    public static func RegisterType<T: Codable>(_ type: T.Type) {
        let typeName = String(describing: type)
        encodableClosures[typeName] = { value, container in
            let castedType: T = value as! T
            try container.encode(castedType, forKey: .value)
        }
        decodableClosures[typeName] = { container in
            try container.decode(T.self, forKey: .value)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case typeName
        case value
    }
    
    private static func RegisterBasicTypes() {
        guard encodableClosures[ArrayTypeName] == nil else {
            // Already registered
            return
        }
        
        RegisterType(Int.self)
        RegisterType(String.self)
        RegisterType(Int.self)
        RegisterType(Int8.self)
        RegisterType(Int16.self)
        RegisterType(Int32.self)
        RegisterType(Int64.self)
        RegisterType(UInt.self)
        RegisterType(UInt8.self)
        RegisterType(UInt16.self)
        RegisterType(UInt32.self)
        RegisterType(UInt64.self)
        RegisterType(Float.self)
        RegisterType(Double.self)
        RegisterType(Bool.self)
        
        encodableClosures[ArrayTypeName] = { value, container in
            var unkeyedContainer = container.nestedUnkeyedContainer(forKey: .value)
            try AnyCodable.encodeAnyArray(value as! [Any], to: &unkeyedContainer)
        }
        decodableClosures[ArrayTypeName] = { container in
            var unkeyedContainer = try container.nestedUnkeyedContainer(forKey: .value)
            return try AnyCodable.decodeAnyArray(from: &unkeyedContainer) as Codable
        }
        
        encodableClosures[DictionaryTypeName] = { value, container in
            var unkeyedContainer = container.nestedUnkeyedContainer(forKey: .value)
            try AnyCodable.encodeAnyDictionary(value as! [AnyHashable: Any], to: &unkeyedContainer)
        }
        decodableClosures[DictionaryTypeName] = { container in
            var unkeyedContainer = try container.nestedUnkeyedContainer(forKey: .value)
            return try AnyCodable.decodeAnyDictionary(from: &unkeyedContainer) as Codable
        }
    }

    public let typeName: String
    public let value: Codable

    public init?(value: Codable?) throws {
        guard let value = value else {
            return nil
        }
        try self.init(value: value)
    }
    
    public init(value: Codable) throws {
        AnyCodable.RegisterBasicTypes()
        self.value = value
        switch value {
        case is Array<Any>: self.typeName = AnyCodable.ArrayTypeName
        case is Dictionary<AnyHashable, Any>: self.typeName = AnyCodable.DictionaryTypeName
        default:
            let typeName = String(describing: type(of: value))
            guard AnyCodable.encodableClosures[typeName] != nil else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [],
                                                                        debugDescription: "AnyCodable: Unsupported type: \(typeName)"))
            }
            self.typeName = typeName
        }
    }
    
    public init(from decoder: Decoder) throws {
        AnyCodable.RegisterBasicTypes()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        guard let closure = AnyCodable.decodableClosures[typeName] else {
            fatalError("Not registered type: \(typeName)")
        }
        self.typeName = typeName
        self.value = try closure(container) as! Codable
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(typeName, forKey: .typeName)
        try AnyCodable.encodableClosures[typeName]!(value, &container)
    }
    
    private static func encodeAnyArray(_ array: [Any],  to container: inout UnkeyedEncodingContainer) throws {
        for value in array {
            guard let codableValue = value as? Codable else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [],
                                                                        debugDescription: "encodeAnyArray: Unsupported type \(type(of: value))"))
            }
        
            try container.encode(AnyCodable(value: codableValue))
        }
    }
    
    private static func decodeAnyArray(from container: inout UnkeyedDecodingContainer) throws -> [Any] {
        var array = [Any]()
        while !container.isAtEnd {
            let value = try container.decode(AnyCodable.self).value
            array.append(value)
        }
        return array
    }
    
    private static func encodeAnyDictionary(_ dict: [AnyHashable: Any],  to container: inout UnkeyedEncodingContainer) throws {
        for (key, value) in dict {
            guard let codableKey = key.base as? Codable else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [],
                                                                        debugDescription: "encodeAnyDictionary: Key unsupported type \(type(of: key.base))"))
            }
            
            guard let codableValue = value as? Codable else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [],
                                                                        debugDescription: "encodeAnyDictionary: Value unsupported type \(type(of: value))"))
            }
            
            try container.encode(AnyCodable(value: codableKey))
            try container.encode(AnyCodable(value: codableValue))
        }
    }
    
    private static func decodeAnyDictionary(from container: inout UnkeyedDecodingContainer) throws -> [AnyHashable: Any] {
        // We're expecting to get pairs. If the container has a known count, it had better be even; no point in doing work if not.
        if let count = container.count {
            guard count % 2 == 0 else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [],
                                                                        debugDescription: "Expected collection of key-value pairs; encountered odd-length array instead."))
            }
        }
        
        var dict = [AnyHashable: Any]()
        while !container.isAtEnd {
        
            guard let key = try container.decode(AnyCodable.self).value as? AnyHashable else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [],
                                                                        debugDescription: "Unkeyed container reached end before value in key-value pair."))
            }
            
            guard !container.isAtEnd else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [],
                                                                        debugDescription: "Unkeyed container reached end before value in key-value pair."))
            }
            
            let value = try container.decode(AnyCodable.self).value
            
            dict[key] = value
        }
        return dict
    }
}
