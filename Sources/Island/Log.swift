import Foundation

/// Tiny stderr logger so we can confirm geometry/behaviour during development.
func elog(_ message: String) {
    FileHandle.standardError.write(Data(("Island: " + message + "\n").utf8))
}
