@_exported import Foundation

public class CGImage { public init() {} }
public enum UIKeyboardType { case `default`, numberPad, decimalPad }

open class UIColor {
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}
    public init(white: CGFloat, alpha: CGFloat) {}
    public static let white = UIColor(white: 1, alpha: 1)
    public static let black = UIColor(white: 0, alpha: 1)
    public static let clear = UIColor(white: 0, alpha: 0)
}

open class UIFont {
    public struct Weight { public static let bold = Weight(); public static let regular = Weight(); public static let semibold = Weight() }
    public static func systemFont(ofSize: CGFloat, weight: Weight) -> UIFont { UIFont() }
    public static func systemFont(ofSize: CGFloat) -> UIFont { UIFont() }
}

public enum UIAccessibility {
    public static var isReduceMotionEnabled: Bool { false }
}
