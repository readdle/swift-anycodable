//
//  AnyCodableTests.swift
//  SmartMailCommon
//
//  Created by fox on 3/31/18.
//  Copyright © 2018 Readdle. All rights reserved.
//

import XCTest
import AnyCodable
import Foundation

class AnyCodableTests: XCTestCase {

    func testDictionary() {
        var d = [String: Int]()
        d["a"] = 1
        d["b"] = 2
        
        let anyCodable = try! AnyCodable(value: d)
        
        let data = try! JSONEncoder().encode(anyCodable)
        let object = try! JSONDecoder().decode(AnyCodable.self, from: data)
       
        let d_test = object.value as! [String: Int]
        
        XCTAssertEqual(d, d_test)
    }
    
    func testArray() {
        var a = [AnyHashable]()
        a.append("123")
        a.append(123)
        
        let anyCodable = try! AnyCodable(value: a)
        
        let data = try! JSONEncoder().encode(anyCodable)
        let object = try! JSONDecoder().decode(AnyCodable.self, from: data)
        
        let a_test = object.value as! [AnyHashable]
        
        XCTAssertEqual(a, a_test)
    }
    
    func testSet() {
        var s = Set<AnyHashable>()
        _ = s.insert("123")
        _ = s.insert(123)
        
        let anyCodable = try! AnyCodable(value: s)
        
        let data = try! JSONEncoder().encode(anyCodable)
        let object = try! JSONDecoder().decode(AnyCodable.self, from: data)
        
        let s_test = object.value as! Set<AnyHashable>
        
        XCTAssertEqual(s, s_test)
    }
    
    func testTwoDimensionalArray() {
        var a = [[String]]()
        a.append(["1", "2", "3"])
        a.append(["4", "5", "6"])
        
        let anyCodable = try! AnyCodable(value: a)
        
        let data = try! JSONEncoder().encode(anyCodable)
        let object = try! JSONDecoder().decode(AnyCodable.self, from: data)
        
        let a_test = object.value as! [[String]]
        
        XCTAssertEqual(a[0], a_test[0])
        XCTAssertEqual(a[1], a_test[1])
    }
    
    struct UnregistredType: Codable {
        let str: String
    }
    
    func testUnregistredEncodingDecoding() throws {
        let a = UnregistredType(str: "42")
        let json = "{\"value\":{\"str\":\"42\"},\"typeName\":\"UnregistredType\"}"
        
        do {
            _ = try AnyCodable(value: a)
            XCTFail()
        }
        catch let error where error is EncodingError {
            NSLog("error \(error)")
        }
        
        do {
            _ = try JSONDecoder().decode(AnyCodable.self, from: json.data(using: .utf8)!)
            XCTFail()
        }
        catch let error where error is DecodingError {
            NSLog("error \(error)")
        }

        AnyCodable.RegisterType(UnregistredType.self)

        do {
            _ = try AnyCodable(value: a)
        }
        catch let error where error is EncodingError {
            XCTFail()
        }
        
        do {
            _ = try JSONDecoder().decode(AnyCodable.self, from: json.data(using: .utf8)!)
        }
        catch let error where error is DecodingError {
            XCTFail()
        }
    }

    func testNSNumberBool() throws {
        let value = NSNumber(value: true)
        let anyCodable = try AnyCodable(value: value)
        let data = try JSONEncoder().encode(anyCodable)
        let object = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(value, object.value as? NSNumber)
    }

    func testNSNumberInt() throws {
        let value = NSNumber(value: 1)
        let anyCodable = try AnyCodable(value: value)
        let data = try JSONEncoder().encode(anyCodable)
        let object = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(value, object.value as? NSNumber)
    }

    func testNSNumberDouble() throws {
        let value = NSNumber(value: 1.0)
        let anyCodable = try AnyCodable(value: value)
        let data = try JSONEncoder().encode(anyCodable)
        let object = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(value, object.value as? NSNumber)
    }
    
}
