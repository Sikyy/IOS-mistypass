import SwiftUI

extension Color {
    /// Brand primary color: #4F55FF (light) / #8589FF (dark)
    static let brandPrimary = Color("BrandPrimary")
}

extension ShapeStyle where Self == Color {
    static var brandPrimary: Color { .brandPrimary }
}
