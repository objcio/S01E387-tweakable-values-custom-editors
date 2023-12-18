//

import SwiftUI

struct PreferenceValue: Equatable {
    var initialValue: Any
    var edit: (String, Binding<Any>) -> AnyView
    init<T>(initialValue: T, edit: @escaping (String, Binding<T>) -> AnyView) {
        self.initialValue = initialValue
        self.edit = { label, binding in
            let b: Binding<T> = Binding(get: { binding.wrappedValue as! T }, set: { binding.wrappedValue = $0 })
            return edit(label, b)
        }
    }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        return true // todo we can't compare closures
    }
}

struct TweakablePreference: PreferenceKey {
    static var defaultValue: [String:PreferenceValue] = [:]
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct TweakableValuesKey: EnvironmentKey {
    static var defaultValue: [String: Any] = [:]
}

extension EnvironmentValues {
    var tweakables: TweakableValuesKey.Value {
        get { self[TweakableValuesKey.self] }
        set { self[TweakableValuesKey.self] = newValue }
    }
}

protocol TweakableType {
    associatedtype V: View
    static func edit(label: String, binding: Binding<Self>) -> V
}

extension Double: TweakableType {
    static func edit(label: String, binding: Binding<Self>) -> some View {
        Slider(value: binding, in: 0...300) { Text(label) }
    }
}

extension Color: TweakableType {
    static func edit(label: String, binding: Binding<Self>) -> some View {
        ColorPicker(label, selection: binding)
    }
}

extension View {
    func tweakable<Value: TweakableType, Output: View>(_ label: String, initialValue: Value, @ViewBuilder content: @escaping (AnyView, Value) -> Output) -> some View {
        modifier(Tweakable(label: label, initialValue: initialValue, edit: Value.edit, run: content))
    }

    func tweakable<Value, Editor: View, Output: View>(_ label: String, initialValue: Value, edit: @escaping (String, Binding<Value>) -> Editor, @ViewBuilder content: @escaping (AnyView, Value) -> Output) -> some View {
        modifier(Tweakable(label: label, initialValue: initialValue, edit: edit, run: content))
    }
}

struct Tweakable<Value, Editor: View, Output: View>: ViewModifier {
    var label: String
    var initialValue: Value
    var edit: (String, Binding<Value>) -> Editor
    @ViewBuilder var run: (AnyView, Value) -> Output
    @Environment(\.tweakables) var tweakables

    func body(content: Content) -> some View {
        run(AnyView(content), (tweakables[label] as? Value) ?? initialValue)
            .transformPreference(TweakablePreference.self) { value in
                value[label] = .init(initialValue: initialValue, edit: { AnyView(edit($0, $1)) })
            }
    }
}

struct TweakableGUI: ViewModifier {
    @State private var definitions: [String: PreferenceValue] = [:]
    @State private var values: [String: Any] = [:]

    func body(content: Content) -> some View {
        content
            .environment(\.tweakables, values)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                ScrollView {
                    VStack {
                        ForEach(values.keys.sorted(), id: \.self) { key in
                            let b = Binding($values[key])!
                            definitions[key]!.edit(key, b)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            .onPreferenceChange(TweakablePreference.self, perform: { value in
                values = value.mapValues { $0.initialValue }
                definitions = value
            })
    }
}

struct ContentView: View {
    var body: some View {
        Text("Hello, world!")
            .tweakable("alignment", initialValue: Alignment.center, edit: { title, binding in
                HStack {
                    Button("Leading") { binding.wrappedValue = .leading }
                    Button("Center") { binding.wrappedValue = .center }
                    Button("Trailing") { binding.wrappedValue = .trailing }
                }
            }) {
                $0.frame(maxWidth: .infinity, alignment: $1)
            }
            .tweakable("padding", initialValue: 10) {
                $0.padding($1)
            }
            .tweakable("offset", initialValue: 10) {
                $0.offset(x: $1)
            }
            .tweakable("foreground color", initialValue: Color.white) {
                $0.foregroundStyle($1)
            }
            .tweakable("padding", initialValue: Color.blue) {
                $0.background($1)
            }
//            .background(Color.blue)
            .modifier(TweakableGUI())
    }
}

#Preview {
    ContentView()
}
