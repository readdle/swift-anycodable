//
//  AnyCodable.swift
//
//  Created by Andrew on 11/16/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

import Foundation

public struct AnyCodable: Codable {
    
    private typealias AnyEncodableClosure = (Any, inout KeyedEncodingContainer<CodingKeys>) throws -> Void
    private typealias AnyDecodableClosure = (KeyedDecodingContainer<CodingKeys>) throws -> Any
    
    private static var encodableClosures = [String: AnyEncodableClosure]()
    private static var decodableClosures = [String: AnyDecodableClosure]()
    
    private static let closuresLock = NSRecursiveLock()
    private static var basicTypeRegistered = false
    
    public static let ArrayTypeName = "Array"
    public static let SetTypeName = "Set"
    public static let DictionaryTypeName = "Dictionary"
    
    public static func RegisterType<T: Codable>(_ type: T.Type) {
        closuresLock.lock()
        defer {
            closuresLock.unlock()
        }
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
        guard basicTypeRegistered == false else {
            // Already registered
            return
        }
        closuresLock.lock()
        defer {
            closuresLock.unlock()
        }
        guard basicTypeRegistered == false else {
            // Double-check lock
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
        RegisterType(Data.self)
        RegisterType(Date.self)
        RegisterType(URL.self)
        
        encodableClosures[ArrayTypeName] = { value, container in
            var unkeyedContainer = container.nestedUnkeyedContainer(forKey: .value)
            try AnyCodable.encodeAnyArray(value as! [Any], to: &unkeyedContainer)
        }
        decodableClosures[ArrayTypeName] = { container in
            var unkeyedContainer = try container.nestedUnkeyedContainer(forKey: .value)
            return try AnyCodable.decodeAnyArray(from: &unkeyedContainer)
        }
        
        encodableClosures[SetTypeName] = { value, container in
            var unkeyedContainer = container.nestedUnkeyedContainer(forKey: .value)
            try AnyCodable.encodeAnySet(value as! Set<AnyHashable>, to: &unkeyedContainer)
        }
        decodableClosures[SetTypeName] = { container in
            var unkeyedContainer = try container.nestedUnkeyedContainer(forKey: .value)
            return try AnyCodable.decodeAnySet(from: &unkeyedContainer)
        }
        
        encodableClosures[DictionaryTypeName] = { value, container in
            var unkeyedContainer = container.nestedUnkeyedContainer(forKey: .value)
            try AnyCodable.encodeAnyDictionary(value as! [AnyHashable: Any], to: &unkeyedContainer)
        }
        decodableClosures[DictionaryTypeName] = { container in
            var unkeyedContainer = try container.nestedUnkeyedContainer(forKey: .value)
            return try AnyCodable.decodeAnyDictionary(from: &unkeyedContainer)
        }
        
        basicTypeRegistered = true
    }
    
    public let typeName: String
    public let value: Any

    @available(*, deprecated, renamed: "init(optionalValue:)", message: "Use explicit init(optionalValue:)")
    public init?(value: Codable?) throws {
        try self.init(optionalValue: value)
    }

    public init?(optionalValue: Codable?) throws {
        guard let value = optionalValue else {
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
        case is Set<AnyHashable>: self.typeName = AnyCodable.SetTypeName
        default:
            let typeName = String(describing: type(of: value))
            guard AnyCodable.encodableClosures[typeName] != nil else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [],
                                                                              debugDescription: "Not registered type: \(typeName)"))
            }
            self.typeName = typeName
        }
    }
    
    public init(value: Array<Any>) throws {
        AnyCodable.RegisterBasicTypes()
        self.value = value
        self.typeName = AnyCodable.ArrayTypeName
    }
    
    public init(value: Dictionary<AnyHashable, Any>) throws {
        AnyCodable.RegisterBasicTypes()
        self.value = value
        self.typeName = AnyCodable.DictionaryTypeName
    }
    
    public init(value: Set<AnyHashable>) throws {
        AnyCodable.RegisterBasicTypes()
        self.value = value
        self.typeName = AnyCodable.SetTypeName
    }
    
    public init(from decoder: Decoder) throws {
        AnyCodable.RegisterBasicTypes()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        guard let closure = AnyCodable.decodableClosures[typeName] else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath,
                                                                    debugDescription: "Not registered type: \(typeName)"))

        }
        self.typeName = typeName
        self.value = try closure(container)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(typeName, forKey: .typeName)
        guard let closure = AnyCodable.encodableClosures[typeName] else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath,
                                                                          debugDescription: "Not registered type: \(typeName)"))
        }
        try closure(value, &container)
    }
    
    private static func encodeAnyArray(_ array: [Any], to container: inout UnkeyedEncodingContainer) throws {
        for value in array {
            if let codableValue = value as? Set<AnyHashable> {
                try container.encode(AnyCodable(value: codableValue))
            }
            else if let codableValue = value as? Array<Any> {
                try container.encode(AnyCodable(value: codableValue))
            }
            else if let codableValue = value as? Dictionary<AnyHashable, Any> {
                try container.encode(AnyCodable(value: codableValue))
            }
            else if let codableValue = value as? Codable {
                try container.encode(AnyCodable(value: codableValue))
            }
            else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath,
                                                                              debugDescription: "Value unsupported type \(type(of: value))"))
            }
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
    
    private static func encodeAnySet(_ set: Set<AnyHashable>, to container: inout UnkeyedEncodingContainer) throws {
        for value in set {
            if let codableValue = value as? Set<AnyHashable> {
                try container.encode(AnyCodable(value: codableValue))
            }
            else if let codableValue = value as? Array<Any> {
                try container.encode(AnyCodable(value: codableValue))
            }
            else if let codableValue = value as? Dictionary<AnyHashable, Any> {
                try container.encode(AnyCodable(value: codableValue))
            }
            else if let codableValue = value as? Codable {
                try container.encode(AnyCodable(value: codableValue))
            }
            else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath,
                                                                              debugDescription: "Value unsupported type \(type(of: value))"))
            }
        }
    }
    
    private static func decodeAnySet(from container: inout UnkeyedDecodingContainer) throws -> Set<AnyHashable> {
        var set = Set<AnyHashable>()
        while !container.isAtEnd {
            let value = try container.decode(AnyCodable.self).value
            if let anyHashableValue = value as? AnyHashable {
                set.insert(anyHashableValue)
            }
            else {
                throw DecodingError.dataCorruptedError(in: container,
                                                       debugDescription: "Expected hashable value in Set. \(type(of: value)) is not Hashable")
            }
        }
        return set
    }
    
    private static func encodeAnyDictionary(_ dict: [AnyHashable: Any], to container: inout UnkeyedEncodingContainer) throws {
        for (key, value) in dict {
            guard let codableKey = key.base as? Codable else {
                throw EncodingError.invalidValue(key.base, EncodingError.Context(codingPath: container.codingPath,
                                                                                 debugDescription: "Key unsupported type \(type(of: key.base))"))
            }
            
            try container.encode(AnyCodable(value: codableKey))
            
            if let codableValue = value as? Set<AnyHashable> {
                try container.encode(AnyCodable(value: codableValue))
            }
            else if let codableValue = value as? Array<Any> {
                try container.encode(AnyCodable(value: codableValue))
            }
            else if let codableValue = value as? Dictionary<AnyHashable, Any> {
                try container.encode(AnyCodable(value: codableValue))
            }
            else if let codableValue = value as? Codable {
                try container.encode(AnyCodable(value: codableValue))
            }
            else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath,
                                                                              debugDescription: "Value unsupported type \(type(of: value))"))
            }
            
        }
    }
    
    private static func decodeAnyDictionary(from container: inout UnkeyedDecodingContainer) throws -> [AnyHashable: Any] {
        // We're expecting to get pairs. If the container has a known count, it had better be even; no point in doing work if not.
        if let count = container.count {
            guard count % 2 == 0 else {
                throw DecodingError.dataCorruptedError(in: container,
                                                       debugDescription: "Expected collection of key-value pairs; encountered odd-length array instead.")
            }
        }
        
        var dict = [AnyHashable: Any]()
        while !container.isAtEnd {
            
            guard let key = try container.decode(AnyCodable.self).value as? AnyHashable else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected Hashable key in Dictionary")
            }
            
            guard !container.isAtEnd else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unkeyed container reached end before value in key-value pair.")
            }
            
            let value = try container.decode(AnyCodable.self).value
            
            dict[key] = value
        }
        return dict
    }
}