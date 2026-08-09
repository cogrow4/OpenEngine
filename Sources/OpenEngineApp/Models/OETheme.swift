import Foundation
import SwiftUI

/// A minimal design system: native macOS aesthetic, muted frosted glass surfaces.
public enum OE_Theme {
    /// Spacing scale (4pt grid).
    public enum Sp {
        public static let xs:  CGFloat = 4
        public static let s:   CGFloat = 8
        public static let m:   CGFloat = 12
        public static let l:   CGFloat = 16
        public static let xl:  CGFloat = 24
        public static let xxl: CGFloat = 32
    }
    public enum R {
        public static let card: CGFloat = 12
        public static let thumb: CGFloat = 8
        public static let pill: CGFloat = 999
    }
}
