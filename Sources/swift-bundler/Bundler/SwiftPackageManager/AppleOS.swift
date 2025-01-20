import Foundation

/// An Apple OS to build for.
enum AppleOS: String, CaseIterable {
  case macOS
  case iOS
  case visionOS
  case tvOS

  /// The display name of the os.
  var name: String {
    return rawValue
  }
}
