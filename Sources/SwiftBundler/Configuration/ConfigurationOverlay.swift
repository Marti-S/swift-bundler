import Foundation
import Parsing

protocol ConfigurationOverlay {
  associatedtype Base
  associatedtype CodingKeys: CodingKey, RawRepresentable<String>

  static var exclusiveProperties: [OverlayCondition: PropertySet<Self>] { get }

  var condition: OverlayCondition { get }

  func merge(into base: inout Base)
}

extension ConfigurationOverlay {
  /// Default implementation with no exclusive properties.
  static var exclusiveProperties: [OverlayCondition: PropertySet<Self>] {
    [:]
  }
}

struct StringCodingKey: CodingKey {
  var value: String

  init(_ value: String) {
    self.value = value
  }

  init?(stringValue: String) {
    value = stringValue
  }

  init?(intValue: Int) {
    return nil
  }

  var stringValue: String {
    value
  }

  var intValue: Int? {
    nil
  }
}

struct CodingIndex: CodingKey {
  var value: Int

  init(_ value: Int) {
    self.value = value
  }

  init?(intValue: Int) {
    value = intValue
  }

  init?(stringValue: String) {
    return nil
  }

  var stringValue: String {
    description
  }

  var intValue: Int? {
    value
  }
}

extension ConfigurationOverlay {
  static func merge<T>(_ current: inout T?, _ overlay: T?) {
    current = overlay ?? current
  }

  static func merge<T>(_ current: inout T, _ overlay: T?) {
    current = overlay ?? current
  }
}

struct PropertySet<Overlay: ConfigurationOverlay> {
  var propertyPresenceCheckers: [(name: String, checker: (Overlay) -> Bool)] = []

  func add<T>(
    _ codingKey: Overlay.CodingKeys,
    _ property: KeyPath<Overlay, T?>
  ) -> PropertySet {
    var list = self
    list.propertyPresenceCheckers.append(
      (
        codingKey.rawValue,
        { overlay in
          overlay[keyPath: property] != nil
        }
      )
    )
    return list
  }

  func propertiesPresent(in overlay: Overlay) -> [String] {
    propertyPresenceCheckers.filter { (_, check) in
      check(overlay)
    }.map(\.0)
  }
}

enum OverlayCondition: Codable, Hashable, CustomStringConvertible {
  case platform(String)
  case bundler(String)

  var description: String {
    switch self {
      case .platform(let identifier):
        return "platform(\(identifier))"
      case .bundler(let identifier):
        return "bundler(\(identifier))"
    }
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)

    let parser = OneOf {
      Parse {
        "platform("
        OneOf {
          for platform in Platform.allCases {
            platform.rawValue.map {
              platform
            }
          }
        }
        ")"
      }.map { platform in
        OverlayCondition.platform(platform.rawValue)
      }

      Parse {
        "bundler("
        OneOf {
          for bundler in BundlerChoice.allCases {
            bundler.rawValue.map {
              bundler
            }
          }
        }
        ")"
      }.map { bundler in
        OverlayCondition.bundler(bundler.rawValue)
      }
    }

    self = try parser.parse(value)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()

    let value: String
    switch self {
      case .platform(let identifier):
        value = "platform(\(identifier))"
      case .bundler(let identifier):
        value = "bundler(\(identifier))"
    }

    try container.encode(value)
  }
}
