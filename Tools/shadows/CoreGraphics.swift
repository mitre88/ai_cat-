@_exported import Foundation

// Shadow of the CoreGraphics surface the app touches: enough to type-check the image packaging of the
// procedural textures and sky. Values are never produced here (every initializer fails).
public typealias CFData = Data

public class CGColorSpace { public init() {} }
public func CGColorSpaceCreateDeviceRGB() -> CGColorSpace { CGColorSpace() }

public class CGDataProvider {
    public init?(data: CFData) { return nil }
}

public struct CGBitmapInfo: OptionSet {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}

public enum CGImageAlphaInfo: UInt32 {
    case none = 0, premultipliedLast = 1, premultipliedFirst = 2, last = 3, first = 4
}

public enum CGColorRenderingIntent { case defaultIntent }
public enum CGLineCap: Int32 { case butt = 0, round = 1, square = 2 }
public enum CGLineJoin: Int32 { case miter = 0, round = 1, bevel = 2 }

public class CGImage {
    public init() {}
    public init?(width: Int, height: Int, bitsPerComponent: Int, bitsPerPixel: Int, bytesPerRow: Int, space: CGColorSpace,
                 bitmapInfo: CGBitmapInfo, provider: CGDataProvider, decode: UnsafePointer<CGFloat>?, shouldInterpolate: Bool,
                 intent: CGColorRenderingIntent) { return nil }
    public var width: Int { 0 }
    public var height: Int { 0 }
}
