import SwiftUI

extension Color {
    /// Brand primary color aligned with mistyislet.com: #62B7A8.
    static let brandPrimary = Color("BrandPrimary")
}

extension ShapeStyle where Self == Color {
    static var brandPrimary: Color { .brandPrimary }
}
