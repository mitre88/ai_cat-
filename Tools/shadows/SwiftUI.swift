@_exported import Foundation
@_exported import UIKit
import Observation

// A deliberately small shadow of SwiftUI: just enough API shape to type-check AI CAT's views on Linux.
// Signatures follow the real framework where the app relies on them.

// MARK: - Core protocols

@MainActor @preconcurrency
public protocol View {
    associatedtype Body: View
    @ViewBuilder @MainActor var body: Body { get }
}

extension Never: View {
    public var body: Never { fatalError() }
}

public struct AnyView: View {
    public init<V: View>(_ view: V) {}
    public var body: Never { fatalError() }
}

public struct EmptyView: View {
    public init() {}
    public var body: Never { fatalError() }
}

public struct TupleView<T>: View {
    public init(_ value: T) {}
    public var body: Never { fatalError() }
}

public struct _ConditionalContent<T: View, F: View>: View {
    public var body: Never { fatalError() }
}

public struct _Modified<Content: View>: View {
    public var body: Never { fatalError() }
}

@resultBuilder
public enum ViewBuilder {
    public static func buildBlock() -> EmptyView { EmptyView() }
    public static func buildBlock<C: View>(_ c: C) -> C { c }
    public static func buildBlock<C0: View, C1: View>(_ c0: C0, _ c1: C1) -> TupleView<(C0, C1)> { TupleView((c0, c1)) }
    public static func buildBlock<C0: View, C1: View, C2: View>(_ c0: C0, _ c1: C1, _ c2: C2) -> TupleView<(C0, C1, C2)> { TupleView((c0, c1, c2)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> TupleView<(C0, C1, C2, C3)> { TupleView((c0, c1, c2, c3)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> TupleView<(C0, C1, C2, C3, C4)> { TupleView((c0, c1, c2, c3, c4)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> TupleView<(C0, C1, C2, C3, C4, C5)> { TupleView((c0, c1, c2, c3, c4, c5)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> TupleView<(C0, C1, C2, C3, C4, C5, C6)> { TupleView((c0, c1, c2, c3, c4, c5, c6)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7)> { TupleView((c0, c1, c2, c3, c4, c5, c6, c7)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8)> { TupleView((c0, c1, c2, c3, c4, c5, c6, c7, c8)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View, C9: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8, C9)> { TupleView((c0, c1, c2, c3, c4, c5, c6, c7, c8, c9)) }
    public static func buildOptional<C: View>(_ c: C?) -> _ConditionalContent<C, EmptyView> { _ConditionalContent() }
    public static func buildEither<T: View, F: View>(first: T) -> _ConditionalContent<T, F> { _ConditionalContent() }
    public static func buildEither<T: View, F: View>(second: F) -> _ConditionalContent<T, F> { _ConditionalContent() }
    public static func buildLimitedAvailability<C: View>(_ c: C) -> AnyView { AnyView(c) }
    public static func buildExpression<C: View>(_ c: C) -> C { c }
}

// MARK: - Scenes & app

@MainActor @preconcurrency
public protocol Scene {}
public struct WindowGroup<Content: View>: Scene {
    public init(@ViewBuilder content: () -> Content) {}
}
@resultBuilder
public enum SceneBuilder {
    public static func buildBlock<S: Scene>(_ s: S) -> S { s }
}
@MainActor @preconcurrency
public protocol App {
    associatedtype Body: Scene
    @SceneBuilder @MainActor var body: Body { get }
    init()
}
extension App {
    public static func main() {}
}

// MARK: - Property wrappers & bindings

@propertyWrapper
public struct Binding<Value> {
    public var wrappedValue: Value { get { getter() } nonmutating set { setter(newValue) } }
    private let getter: () -> Value
    private let setter: (Value) -> Void
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) { getter = get; setter = set }
    public var projectedValue: Binding<Value> { self }
}

final class _Box<Value> { var value: Value; init(_ v: Value) { value = v } }

@propertyWrapper
public struct State<Value> {
    private let box: _Box<Value>
    public var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.value = newValue }
    }
    public init(wrappedValue: Value) { box = _Box(wrappedValue) }
    public init(initialValue: Value) { box = _Box(initialValue) }
    public var projectedValue: Binding<Value> {
        let b = box
        return Binding(get: { b.value }, set: { b.value = $0 })
    }
}

@propertyWrapper
@dynamicMemberLookup
public struct Bindable<Value: AnyObject & Observable> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public init(_ wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public var projectedValue: Bindable<Value> { self }
    public subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, T>) -> Binding<T> {
        let object = wrappedValue
        return Binding(get: { object[keyPath: keyPath] }, set: { object[keyPath: keyPath] = $0 })
    }
}

public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

public enum UserInterfaceSizeClass { case compact, regular }
public struct DismissAction { public func callAsFunction() {} }

public struct EnvironmentValues {
    private var storage: [ObjectIdentifier: Any] = [:]
    public init() {}
    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get { (storage[ObjectIdentifier(key)] as? K.Value) ?? K.defaultValue }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
    public var horizontalSizeClass: UserInterfaceSizeClass? = .compact
    public var accessibilityReduceMotion: Bool = false
    public var verticalSizeClass: UserInterfaceSizeClass? = .regular
    public var dismiss: DismissAction = DismissAction()
    public var locale: Locale = Locale(identifier: "en_US")
}

@propertyWrapper
public struct Environment<Value> {
    private let read: () -> Value
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) { read = { EnvironmentValues()[keyPath: keyPath] } }
    public init(_ objectType: Value.Type) where Value: AnyObject & Observable { read = { fatalError() } }
    public var wrappedValue: Value { read() }
}

// MARK: - Geometry & styling primitives

public struct Alignment: Equatable {
    public static let center = Alignment(), top = Alignment(), bottom = Alignment(), leading = Alignment(), trailing = Alignment()
    public static let topLeading = Alignment(), topTrailing = Alignment(), bottomLeading = Alignment(), bottomTrailing = Alignment()
}
public struct HorizontalAlignment: Equatable { public static let leading = HorizontalAlignment(), center = HorizontalAlignment(), trailing = HorizontalAlignment() }
public struct VerticalAlignment: Equatable { public static let top = VerticalAlignment(), center = VerticalAlignment(), bottom = VerticalAlignment() }
public enum TextAlignment { case leading, center, trailing }
public enum Axis { case horizontal, vertical
    public struct Set: OptionSet { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }
        public static let horizontal = Set(rawValue: 1), vertical = Set(rawValue: 2) }
}
public enum Edge { case top, leading, bottom, trailing
    public struct Set: OptionSet { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }
        public static let top = Set(rawValue: 1), leading = Set(rawValue: 2), bottom = Set(rawValue: 4), trailing = Set(rawValue: 8)
        public static let horizontal: Set = [.leading, .trailing], vertical: Set = [.top, .bottom], all: Set = [.horizontal, .vertical] }
}
public struct UnitPoint {
    public var x: CGFloat
    public var y: CGFloat
    public init() { x = 0; y = 0 }
    public init(x: CGFloat, y: CGFloat) { self.x = x; self.y = y }
    public static let zero = UnitPoint(), center = UnitPoint(x: 0.5, y: 0.5)
    public static let top = UnitPoint(x: 0.5, y: 0), bottom = UnitPoint(x: 0.5, y: 1), leading = UnitPoint(x: 0, y: 0.5), trailing = UnitPoint(x: 1, y: 0.5)
    public static let topLeading = UnitPoint(x: 0, y: 0), topTrailing = UnitPoint(x: 1, y: 0)
    public static let bottomLeading = UnitPoint(x: 0, y: 1), bottomTrailing = UnitPoint(x: 1, y: 1)
}
public enum RoundedCornerStyle { case circular, continuous }
public struct Angle: Equatable, Hashable, Sendable {
    public var degrees: Double
    public var radians: Double { degrees * .pi / 180 }
    public init(degrees: Double) { self.degrees = degrees }
    public static func degrees(_ v: Double) -> Angle { Angle(degrees: v) }
}
public enum Visibility { case automatic, visible, hidden }
public enum ColorScheme { case light, dark }
public enum AccessibilityChildBehavior { case ignore, contain, combine }
public enum SubmitLabel { case done, go, next, search }

public struct Font {
    public struct Weight { public static let regular = Weight(), bold = Weight(), semibold = Weight(), medium = Weight() }
    public enum Design { case `default`, serif, rounded, monospaced }
    public enum TextStyle { case largeTitle, title, title2, title3, headline, subheadline, body, callout, footnote, caption, caption2 }
    public static let largeTitle = Font(), title = Font(), title2 = Font(), title3 = Font(), headline = Font(), subheadline = Font()
    public static let body = Font(), callout = Font(), footnote = Font(), caption = Font(), caption2 = Font()
    public static func system(size: CGFloat, weight: Weight = .regular, design: Design = .default) -> Font { Font() }
    public static func system(_ style: TextStyle, design: Design = .default) -> Font { Font() }
    public func bold() -> Font { self }
    public func monospaced() -> Font { self }
    public func weight(_ w: Weight) -> Font { self }
}

public struct Animation: Equatable {
    public static let easeInOut = Animation(), easeIn = Animation(), easeOut = Animation(), linear = Animation(), smooth = Animation(), snappy = Animation(), bouncy = Animation()
    public static func easeInOut(duration: Double) -> Animation { Animation() }
    public static func easeIn(duration: Double) -> Animation { Animation() }
    public static func easeOut(duration: Double) -> Animation { Animation() }
    public static func spring(response: Double = 0.5, dampingFraction: Double = 0.8, blendDuration: Double = 0) -> Animation { Animation() }
    public func repeatForever(autoreverses: Bool = true) -> Animation { self }
}
public struct AnyTransition { public static let opacity = AnyTransition(), slide = AnyTransition(), scale = AnyTransition() }
public func withAnimation<Result>(_ animation: Animation? = .easeInOut, _ body: () throws -> Result) rethrows -> Result { try body() }

// MARK: - Shape styles & colors

public protocol ShapeStyle {}
public struct Color: ShapeStyle, View, Equatable, Hashable, Sendable {
    public static let primary = Color(red: 0, green: 0, blue: 0)
    public static let secondary = Color(red: 0.5, green: 0.5, blue: 0.5)
    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {}
    public init(white: Double, opacity: Double = 1) {}
    public static let red = Color(white: 0), blue = Color(white: 0), orange = Color(white: 0), pink = Color(white: 0)
    public static let purple = Color(white: 0), white = Color(white: 1), black = Color(white: 0), gray = Color(white: 0.5)
    public static let green = Color(white: 0), yellow = Color(white: 0), accentColor = Color(white: 0), clear = Color(white: 0), indigo = Color(white: 0)
    public func opacity(_ value: Double) -> Color { self }
    public var body: Never { fatalError() }
}
extension UIColor {
    public convenience init(_ color: Color) { self.init(white: 0, alpha: 1) }
}
extension ShapeStyle where Self == Color {
    public static var white: Color { Color.white }
    public static var black: Color { Color.black }
    public static var red: Color { Color.red }
    public static var green: Color { Color.green }
    public static var blue: Color { Color.blue }
    public static var orange: Color { Color.orange }
    public static var yellow: Color { Color.yellow }
    public static var pink: Color { Color.pink }
    public static var purple: Color { Color.purple }
    public static var gray: Color { Color.gray }
    public static var accentColor: Color { Color.accentColor }
}
public struct HierarchicalShapeStyle: ShapeStyle { public static let primary = HierarchicalShapeStyle(), secondary = HierarchicalShapeStyle(), tertiary = HierarchicalShapeStyle() }
extension ShapeStyle where Self == HierarchicalShapeStyle {
    public static var primary: HierarchicalShapeStyle { .primary }
    public static var secondary: HierarchicalShapeStyle { .secondary }
    public static var tertiary: HierarchicalShapeStyle { .tertiary }
}
public struct Material: ShapeStyle { public static let regularMaterial = Material(), ultraThinMaterial = Material(), thinMaterial = Material(), thickMaterial = Material() }
extension ShapeStyle where Self == Material {
    public static var regularMaterial: Material { .regularMaterial }
    public static var ultraThinMaterial: Material { .ultraThinMaterial }
    public static var thinMaterial: Material { .thinMaterial }
}
public struct LinearGradient: ShapeStyle, View {
    public init(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) {}
    public var body: Never { fatalError() }
}
public struct RadialGradient: ShapeStyle, View {
    public init(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {}
    public var body: Never { fatalError() }
}

// MARK: - Shapes

public struct StrokeStyle {
    public init(lineWidth: CGFloat = 1, lineCap: CGLineCap = .butt, lineJoin: CGLineJoin = .miter, miterLimit: CGFloat = 10,
                dash: [CGFloat] = [], dashPhase: CGFloat = 0) {}
}
public struct Path {
    public init() {}
    public mutating func move(to p: CGPoint) {}
    public mutating func addLine(to p: CGPoint) {}
    public mutating func addQuadCurve(to end: CGPoint, control: CGPoint) {}
    public mutating func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {}
    public mutating func closeSubpath() {}
}
public struct _ShapeView<S: Shape>: View { public var body: Never { fatalError() } }
public protocol Shape: View {
    func path(in rect: CGRect) -> Path
}
extension Shape {
    public var body: _ShapeView<Self> { _ShapeView() }
    public func fill<S: ShapeStyle>(_ style: S) -> _ShapeView<Self> { _ShapeView() }
    public func stroke<S: ShapeStyle>(_ style: S, lineWidth: CGFloat = 1) -> _ShapeView<Self> { _ShapeView() }
    public func stroke<S: ShapeStyle>(_ style: S, style strokeStyle: StrokeStyle) -> _ShapeView<Self> { _ShapeView() }
}
public struct Circle: Shape { public init() {}; public func path(in rect: CGRect) -> Path { Path() } }
public struct Ellipse: Shape { public init() {}; public func path(in rect: CGRect) -> Path { Path() } }
public struct Capsule: Shape { public init() {}; public func path(in rect: CGRect) -> Path { Path() } }
public struct Rectangle: Shape { public init() {}; public func path(in rect: CGRect) -> Path { Path() } }
public struct RoundedRectangle: Shape {
    public init(cornerRadius: CGFloat, style: RoundedCornerStyle = .circular) {}
    public func path(in rect: CGRect) -> Path { Path() }
}

// MARK: - Text & basic views

public struct LocalizedStringKey: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    public init(stringLiteral value: String) {}
    public init(_ value: String) {}
}
public struct Text: View, Equatable {
    public init(_ key: LocalizedStringKey) {}
    public init<S: StringProtocol>(_ content: S) {}
    public init(verbatim: String) {}
    public static func == (lhs: Text, rhs: Text) -> Bool { true }
    public var body: Never { fatalError() }
    public func font(_ font: Font?) -> Text { self }
    public func bold() -> Text { self }
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> Text { self }
}
public struct Image: View {
    public init(systemName: String) {}
    public init(_ name: String) {}
    public var body: Never { fatalError() }
}
public struct Label<Title: View, Icon: View>: View {
    public init(@ViewBuilder title: () -> Title, @ViewBuilder icon: () -> Icon) {}
    public var body: Never { fatalError() }
}
extension Label where Title == Text, Icon == Image {
    public init(_ titleKey: LocalizedStringKey, systemImage: String) {}
    public init<S: StringProtocol>(_ title: S, systemImage: String) {}
}
public struct Spacer: View { public init(minLength: CGFloat? = nil) {}; public var body: Never { fatalError() } }
public struct Divider: View { public init() {}; public var body: Never { fatalError() } }
public struct Group<Content: View>: View { public init(@ViewBuilder content: () -> Content) {}; public var body: Never { fatalError() } }

// MARK: - Stacks & containers

public struct VStack<Content: View>: View {
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
    public var body: Never { fatalError() }
}
public struct HStack<Content: View>: View {
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
    public var body: Never { fatalError() }
}
public struct ZStack<Content: View>: View {
    public init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {}
    public var body: Never { fatalError() }
}
public struct ScrollView<Content: View>: View {
    public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {}
    public var body: Never { fatalError() }
}
public struct GridItem {
    public enum Size { case fixed(CGFloat), flexible(minimum: CGFloat = 10, maximum: CGFloat = .infinity), adaptive(minimum: CGFloat, maximum: CGFloat = .infinity) }
    public init(_ size: Size = .flexible(), spacing: CGFloat? = nil, alignment: Alignment? = nil) {}
}
public struct LazyVGrid<Content: View>: View {
    public init(columns: [GridItem], alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
    public var body: Never { fatalError() }
}
public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    public var body: Never { fatalError() }
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {}
}
extension ForEach where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {}
}
public struct GeometryProxy {
    public var size: CGSize { .zero }
    public var safeAreaInsets: EdgeInsets { EdgeInsets() }
}
public struct EdgeInsets: Equatable { public var top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0; public init() {} }
public struct GeometryReader<Content: View>: View {
    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {}
    public var body: Never { fatalError() }
}

// MARK: - Controls

public enum ButtonRole { case destructive, cancel }
public struct Button<Label: View>: View {
    public init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {}
    public init(role: ButtonRole?, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {}
    public var body: Never { fatalError() }
}
extension Button where Label == Text {
    public init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {}
    public init<S: StringProtocol>(_ title: S, action: @escaping () -> Void) {}
    public init(_ titleKey: LocalizedStringKey, role: ButtonRole?, action: @escaping () -> Void) {}
    public init<S: StringProtocol>(_ title: S, role: ButtonRole?, action: @escaping () -> Void) {}
}
public struct ButtonStyleConfiguration {
    public struct Label: View { public var body: Never { fatalError() } }
    public var label: Label { Label() }
    public var isPressed: Bool { false }
}
@MainActor @preconcurrency
public protocol ButtonStyle {
    associatedtype Body: View
    typealias Configuration = ButtonStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}
public struct PlainButtonStyle: ButtonStyle { public func makeBody(configuration: Configuration) -> some View { configuration.label } }
public struct BorderedButtonStyle: ButtonStyle { public func makeBody(configuration: Configuration) -> some View { configuration.label } }
public struct BorderedProminentButtonStyle: ButtonStyle { public func makeBody(configuration: Configuration) -> some View { configuration.label } }
extension ButtonStyle where Self == PlainButtonStyle { public static var plain: PlainButtonStyle { PlainButtonStyle() } }
extension ButtonStyle where Self == BorderedButtonStyle { public static var bordered: BorderedButtonStyle { BorderedButtonStyle() } }
extension ButtonStyle where Self == BorderedProminentButtonStyle { public static var borderedProminent: BorderedProminentButtonStyle { BorderedProminentButtonStyle() } }

public struct Toggle<Label: View>: View {
    public init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {}
    public var body: Never { fatalError() }
}
extension Toggle where Label == Text {
    public init<S: StringProtocol>(_ title: S, isOn: Binding<Bool>) {}
}
public struct Slider<Label: View>: View {
    public var body: Never { fatalError() }
}
extension Slider where Label == EmptyView {
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V>, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {}
}
public struct TextField<Label: View>: View {
    public var body: Never { fatalError() }
}
extension TextField where Label == Text {
    public init<S: StringProtocol>(_ title: S, text: Binding<String>) {}
}
public protocol TextFieldStyle {}
public struct RoundedBorderTextFieldStyle: TextFieldStyle {}
extension TextFieldStyle where Self == RoundedBorderTextFieldStyle { public static var roundedBorder: RoundedBorderTextFieldStyle { RoundedBorderTextFieldStyle() } }
public struct Picker<Label: View, SelectionValue: Hashable, Content: View>: View {
    public var body: Never { fatalError() }
}
extension Picker where Label == Text {
    public init<S: StringProtocol>(_ title: S, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
}
public protocol PickerStyle {}
public struct InlinePickerStyle: PickerStyle {}
public struct SegmentedPickerStyle: PickerStyle {}
public struct MenuPickerStyle: PickerStyle {}
extension PickerStyle where Self == InlinePickerStyle { public static var inline: InlinePickerStyle { InlinePickerStyle() } }
extension PickerStyle where Self == SegmentedPickerStyle { public static var segmented: SegmentedPickerStyle { SegmentedPickerStyle() } }
extension PickerStyle where Self == MenuPickerStyle { public static var menu: MenuPickerStyle { MenuPickerStyle() } }
public struct ProgressView<Label: View>: View {
    public var body: Never { fatalError() }
}
extension ProgressView where Label == EmptyView {
    public init() {}
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0) {}
}
public struct Form<Content: View>: View {
    public init(@ViewBuilder content: () -> Content) {}
    public var body: Never { fatalError() }
}
public struct Section<Parent: View, Content: View, Footer: View>: View {
    public var body: Never { fatalError() }
}
extension Section where Parent == Text, Footer == EmptyView {
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {}
}
extension Section where Parent == EmptyView {
    public init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {}
}
extension Section where Parent == EmptyView, Footer == EmptyView {
    public init(@ViewBuilder content: () -> Content) {}
}
public struct LabeledContent<Label: View, Content: View>: View {
    public var body: Never { fatalError() }
}
extension LabeledContent where Label == Text, Content == Text {
    public init<S: StringProtocol>(_ title: S, value: String) {}
}

// MARK: - Navigation

public struct NavigationPath {
    public init() {}
    public var isEmpty: Bool { true }
    public var count: Int { 0 }
    public mutating func append<V: Hashable>(_ value: V) {}
    public mutating func removeLast(_ k: Int = 1) {}
}

public struct NavigationStack<Root: View>: View {
    public init(@ViewBuilder root: () -> Root) {}
    public init(path: Binding<NavigationPath>, @ViewBuilder root: () -> Root) {}
    public var body: Never { fatalError() }
}
public enum NavigationBarItem { public enum TitleDisplayMode { case automatic, inline, large } }
public struct ToolbarItemPlacement { public static let topBarTrailing = ToolbarItemPlacement(), topBarLeading = ToolbarItemPlacement(), principal = ToolbarItemPlacement(), bottomBar = ToolbarItemPlacement(), automatic = ToolbarItemPlacement() }
public struct ToolbarItem<Content: View>: View {
    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {}
    public var body: Never { fatalError() }
}

// MARK: - Gestures

public protocol Gesture { associatedtype Value }
public struct _ChangedGesture<G: Gesture>: Gesture { public typealias Value = G.Value }
extension Gesture {
    public func onChanged(_ action: @escaping (Value) -> Void) -> _ChangedGesture<Self> { _ChangedGesture() }
    public func onEnded(_ action: @escaping (Value) -> Void) -> _ChangedGesture<Self> { _ChangedGesture() }
}
public protocol CoordinateSpaceProtocol {}
public struct LocalCoordinateSpace: CoordinateSpaceProtocol { public init() {} }
public struct GlobalCoordinateSpace: CoordinateSpaceProtocol { public init() {} }
extension CoordinateSpaceProtocol where Self == LocalCoordinateSpace { public static var local: LocalCoordinateSpace { LocalCoordinateSpace() } }
extension CoordinateSpaceProtocol where Self == GlobalCoordinateSpace { public static var global: GlobalCoordinateSpace { GlobalCoordinateSpace() } }
public struct DragGesture: Gesture {
    public struct Value { public var location: CGPoint; public var startLocation: CGPoint; public var translation: CGSize }
    public init(minimumDistance: CGFloat = 10, coordinateSpace: some CoordinateSpaceProtocol = LocalCoordinateSpace()) {}
}

public enum ContentMode { case fit, fill }
public struct NamedCoordinateSpace: CoordinateSpaceProtocol {
    public init() {}
    public static func named(_ name: some Hashable) -> NamedCoordinateSpace { NamedCoordinateSpace() }
}
extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
    public static func named(_ name: some Hashable) -> NamedCoordinateSpace { NamedCoordinateSpace() }
}

// MARK: - View modifiers

extension View {
    public func position(x: CGFloat, y: CGFloat) -> _Modified<Self> { _Modified() }
    public func position(_ point: CGPoint) -> _Modified<Self> { _Modified() }
    public func onTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> _Modified<Self> { _Modified() }
    public func clipped(antialiased: Bool = false) -> _Modified<Self> { _Modified() }
    public func coordinateSpace(_ name: NamedCoordinateSpace) -> _Modified<Self> { _Modified() }
    public func aspectRatio(_ ratio: CGFloat? = nil, contentMode: ContentMode) -> _Modified<Self> { _Modified() }
    public func zIndex(_ value: Double) -> _Modified<Self> { _Modified() }
    public func font(_ font: Font?) -> _Modified<Self> { _Modified() }
    public func bold(_ isActive: Bool = true) -> _Modified<Self> { _Modified() }
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> _Modified<Self> { _Modified() }
    public func tint(_ tint: Color?) -> _Modified<Self> { _Modified() }
    public func opacity(_ value: Double) -> _Modified<Self> { _Modified() }
    public func padding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> _Modified<Self> { _Modified() }
    public func padding(_ length: CGFloat) -> _Modified<Self> { _Modified() }
    public func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> _Modified<Self> { _Modified() }
    public func frame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment = .center) -> _Modified<Self> { _Modified() }
    public func background<S: ShapeStyle>(_ style: S, ignoresSafeAreaEdges: Edge.Set = .all) -> _Modified<Self> { _Modified() }
    public func background<S: ShapeStyle, Sh: Shape>(_ style: S, in shape: Sh) -> _Modified<Self> { _Modified() }
    public func background<V: View>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> _Modified<Self> { _Modified() }
    @_disfavoredOverload
    public func background<V: View>(_ background: V, alignment: Alignment = .center) -> _Modified<Self> { _Modified() }
    public func overlay<V: View>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> _Modified<Self> { _Modified() }
    @_disfavoredOverload
    public func overlay<V: View>(_ overlay: V, alignment: Alignment = .center) -> _Modified<Self> { _Modified() }
    public func clipShape<S: Shape>(_ shape: S) -> _Modified<Self> { _Modified() }
    public func shadow(color: Color = .black, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> _Modified<Self> { _Modified() }
    public func scaleEffect(_ s: CGFloat, anchor: UnitPoint = .center) -> _Modified<Self> { _Modified() }
    public func scaleEffect(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> _Modified<Self> { _Modified() }
    public func rotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> _Modified<Self> { _Modified() }
    public func blur(radius: CGFloat, opaque: Bool = false) -> _Modified<Self> { _Modified() }
    public func compositingGroup() -> _Modified<Self> { _Modified() }
    public func mask<M: View>(alignment: Alignment = .center, @ViewBuilder _ mask: () -> M) -> _Modified<Self> { _Modified() }
    public func accessibilityHidden(_ hidden: Bool) -> _Modified<Self> { _Modified() }
    public func preferredColorScheme(_ colorScheme: ColorScheme?) -> _Modified<Self> { _Modified() }
    public func saturation(_ amount: Double) -> _Modified<Self> { _Modified() }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> _Modified<Self> { _Modified() }
    public func multilineTextAlignment(_ alignment: TextAlignment) -> _Modified<Self> { _Modified() }
    public func lineLimit(_ number: Int?) -> _Modified<Self> { _Modified() }
    public func animation<V: Equatable>(_ animation: Animation?, value: V) -> _Modified<Self> { _Modified() }
    public func transition(_ t: AnyTransition) -> _Modified<Self> { _Modified() }
    public func ignoresSafeArea(_ regions: Int = 0, edges: Edge.Set = .all) -> _Modified<Self> { _Modified() }
    public func accessibilityLabel(_ label: Text) -> _Modified<Self> { _Modified() }
    public func accessibilityElement(children: AccessibilityChildBehavior = .ignore) -> _Modified<Self> { _Modified() }
    public func allowsHitTesting(_ enabled: Bool) -> _Modified<Self> { _Modified() }
    public func disabled(_ disabled: Bool) -> _Modified<Self> { _Modified() }
    public func id<ID: Hashable>(_ id: ID) -> _Modified<Self> { _Modified() }
    public func tag<V: Hashable>(_ tag: V) -> _Modified<Self> { _Modified() }
    public func labelsHidden() -> _Modified<Self> { _Modified() }
    public func environment<T: AnyObject & Observable>(_ object: T?) -> _Modified<Self> { _Modified() }
    public func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> _Modified<Self> { _Modified() }
    public func onAppear(perform action: (() -> Void)? = nil) -> _Modified<Self> { _Modified() }
    public func onDisappear(perform action: (() -> Void)? = nil) -> _Modified<Self> { _Modified() }
    public func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping (V, V) -> Void) -> _Modified<Self> { _Modified() }
    public func scrollDisabled(_ disabled: Bool) -> _Modified<Self> { _Modified() }
    public func keyboardType(_ type: UIKeyboardType) -> _Modified<Self> { _Modified() }
    public func task(priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async -> Void) -> _Modified<Self> { _Modified() }
    public func task<T: Equatable>(id value: T, priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async -> Void) -> _Modified<Self> { _Modified() }
    public func onSubmit(_ action: @escaping () -> Void) -> _Modified<Self> { _Modified() }
    public func submitLabel(_ label: SubmitLabel) -> _Modified<Self> { _Modified() }
    public func onLongPressGesture(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10, perform action: @escaping () -> Void) -> _Modified<Self> { _Modified() }
    public func gesture<G: Gesture>(_ gesture: G) -> _Modified<Self> { _Modified() }
    public func buttonStyle<S: ButtonStyle>(_ style: S) -> _Modified<Self> { _Modified() }
    public func textFieldStyle<S: TextFieldStyle>(_ style: S) -> _Modified<Self> { _Modified() }
    public func pickerStyle<S: PickerStyle>(_ style: S) -> _Modified<Self> { _Modified() }
    public func navigationTitle<S: StringProtocol>(_ title: S) -> _Modified<Self> { _Modified() }
    public func navigationTitle(_ title: LocalizedStringKey) -> _Modified<Self> { _Modified() }
    public func navigationBarTitleDisplayMode(_ mode: NavigationBarItem.TitleDisplayMode) -> _Modified<Self> { _Modified() }
    public func navigationDestination<D: Hashable, C: View>(for data: D.Type, @ViewBuilder destination: @escaping (D) -> C) -> _Modified<Self> { _Modified() }
    public func toolbar<C: View>(@ViewBuilder content: () -> C) -> _Modified<Self> { _Modified() }
    public func sheet<C: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> C) -> _Modified<Self> { _Modified() }
    public func confirmationDialog<S: StringProtocol, A: View>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A) -> _Modified<Self> { _Modified() }
}

// MARK: - iPhone Duo (iOS 27.1) surface

@available(iOS 27.1, *)
public struct ReservedRegion: Identifiable, Hashable, Sendable {
    public struct ID: Hashable, Sendable { public init() {} }
    public struct Kind: Hashable, Sendable {
        public static let division = Kind(), occlusion = Kind()
    }
    public struct QueryOptions: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let includeInactive = QueryOptions(rawValue: 1)
    }
    public var id: ID { ID() }
    public var frame: CGRect { .zero }
    public var margins: EdgeInsets { EdgeInsets() }
    public var isActive: Bool { false }
    public var kind: Kind { .division }
    public static func == (lhs: ReservedRegion, rhs: ReservedRegion) -> Bool { true }
    public func hash(into hasher: inout Hasher) {}
}
public enum LayoutDirectionBehavior { case mirrors, fixed }
@available(iOS 27.1, *)
extension GeometryProxy {
    public func reservedRegions(kind: ReservedRegion.Kind, options: ReservedRegion.QueryOptions = [], layoutDirectionBehavior: LayoutDirectionBehavior = .mirrors) -> [ReservedRegion] { [] }
}
@available(iOS 27.1, *)
public struct DeviceHinge: Equatable, Sendable, Hashable {
    public struct Status: Equatable, Sendable, Hashable { public static let closed = Status(), partiallyOpen = Status(), fullyOpen = Status() }
    public var angle: Angle
    public var status: Status
}
@available(iOS 27.1, *)
public struct DeviceHingeContext { public var hinge: DeviceHinge? }
@available(iOS 27.1, *)
extension View {
    public func onHingeChange(isEnabled: Bool = true, _ action: @escaping (DeviceHingeContext, DeviceHingeContext) -> Void) -> _Modified<Self> { _Modified() }
    public func arrangementViewStyle<S: ArrangementViewStyle>(_ style: S) -> _Modified<Self> { _Modified() }
}
@available(iOS 27.1, *)
public protocol ArrangementViewStyle {}
@available(iOS 27.1, *)
public struct SplitArrangementViewStyle: ArrangementViewStyle {
    public init() {}
    public func axes(_ axes: Axis.Set) -> SplitArrangementViewStyle { self }
}
@available(iOS 27.1, *)
public struct OverlayArrangementViewStyle: ArrangementViewStyle { public init() {} }
@available(iOS 27.1, *)
extension ArrangementViewStyle where Self == SplitArrangementViewStyle { public static var split: SplitArrangementViewStyle { SplitArrangementViewStyle() } }
@available(iOS 27.1, *)
extension ArrangementViewStyle where Self == OverlayArrangementViewStyle { public static var overlay: OverlayArrangementViewStyle { OverlayArrangementViewStyle() } }
@available(iOS 27.1, *)
public struct ArrangementView<Primary: View, Secondary: View>: View {
    public init(@ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {}
    public var body: Never { fatalError() }
}
