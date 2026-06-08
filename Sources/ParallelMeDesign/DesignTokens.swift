import SwiftUI

public enum ParallelMeColor {
    public static let paper = Color(red: 0.982, green: 0.969, blue: 0.932)
    public static let paperLift = Color(red: 1.000, green: 0.989, blue: 0.955)
    public static let ink = Color(red: 0.110, green: 0.100, blue: 0.085)
    public static let inkMuted = Color(red: 0.410, green: 0.380, blue: 0.330)
    public static let line = Color(red: 0.820, green: 0.780, blue: 0.690)
    public static let rest = Color(red: 0.440, green: 0.560, blue: 0.480)
    public static let money = Color(red: 0.680, green: 0.510, blue: 0.250)
    public static let roam = Color(red: 0.300, green: 0.500, blue: 0.690)
    public static let filial = Color(red: 0.690, green: 0.390, blue: 0.360)
    public static let future = Color(red: 0.420, green: 0.420, blue: 0.640)
}

public enum ParallelMeSpacing {
    public static let xs: CGFloat = 6
    public static let sm: CGFloat = 10
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 34
}

public enum ParallelMeRadius {
    public static let control: CGFloat = 8
    public static let card: CGFloat = 8
    public static let sheet: CGFloat = 14
}

public enum ParallelMeTypography {
    public static let eyebrow = Font.system(size: 12, weight: .medium, design: .rounded)
    public static let body = Font.system(size: 16, weight: .regular, design: .serif)
    public static let bodyStrong = Font.system(size: 16, weight: .semibold, design: .serif)
    public static let title = Font.system(size: 30, weight: .semibold, design: .serif)
    public static let compact = Font.system(size: 13, weight: .regular, design: .rounded)
}

public enum ParallelMeTheme {
    public static func voiceColor(_ id: String) -> Color {
        switch id {
        case "lay": ParallelMeColor.rest
        case "money": ParallelMeColor.money
        case "roam": ParallelMeColor.roam
        case "filial": ParallelMeColor.filial
        case "future": ParallelMeColor.future
        default: ParallelMeColor.inkMuted
        }
    }
}

