import Foundation

/// Every available skin. Purely data — extend this list to add colourways.
enum ThemeCatalog {
    static let classicWhite = Theme(
        id: "classic-white",
        name: "Classic White",
        bodyTop: "FDFDFD", bodyBottom: "E4E6E9", bodyBorder: "C3C7CC",
        screenBezel: "D6D9DD", screenBackground: "1C1F24",
        screenText: "FFFFFF", screenSecondaryText: "A9B0BA",
        wheelTop: "FAFBFC", wheelBottom: "E2E5E9", wheelBorder: "C8CCD2",
        wheelLabel: "8A9199",
        centerButtonTop: "FFFFFF", centerButtonBottom: "E8EBEF",
        isDarkBody: false, isGlass: false
    )

    static let classicBlack = Theme(
        id: "classic-black",
        name: "Classic Black",
        bodyTop: "3A3D42", bodyBottom: "191B1E", bodyBorder: "0E0F11",
        screenBezel: "26282C", screenBackground: "0B0D10",
        screenText: "FFFFFF", screenSecondaryText: "9AA1AB",
        wheelTop: "45484E", wheelBottom: "2A2D31", wheelBorder: "17191C",
        wheelLabel: "C4C9D0",
        centerButtonTop: "4B4E54", centerButtonBottom: "303338",
        isDarkBody: true, isGlass: false
    )

    static let miniSilver = Theme(
        id: "mini-silver",
        name: "Mini Silver",
        bodyTop: "E9EBED", bodyBottom: "C4C8CD", bodyBorder: "A8ADB3",
        screenBezel: "B9BEC4", screenBackground: "1A1D21",
        screenText: "FFFFFF", screenSecondaryText: "A9B0BA",
        wheelTop: "F2F3F5", wheelBottom: "D6D9DD", wheelBorder: "B0B5BB",
        wheelLabel: "7C838B",
        centerButtonTop: "F7F8F9", centerButtonBottom: "DDE0E4",
        isDarkBody: false, isGlass: false
    )

    static let miniBlue = Theme(
        id: "mini-blue",
        name: "Mini Blue",
        bodyTop: "AFC9DF", bodyBottom: "7FA5C4", bodyBorder: "5F86A6",
        screenBezel: "9DBAD3", screenBackground: "16202A",
        screenText: "FFFFFF", screenSecondaryText: "B4C6D6",
        wheelTop: "D8E6F1", wheelBottom: "AEC8DE", wheelBorder: "89A8C4",
        wheelLabel: "4A6A87",
        centerButtonTop: "E4EEF6", centerButtonBottom: "BFD4E5",
        isDarkBody: false, isGlass: false
    )

    static let miniPink = Theme(
        id: "mini-pink",
        name: "Mini Pink",
        bodyTop: "F0C2D2", bodyBottom: "DB94B0", bodyBorder: "BE7392",
        screenBezel: "E5B0C4", screenBackground: "27161D",
        screenText: "FFFFFF", screenSecondaryText: "DDBAC8",
        wheelTop: "F8DDE7", wheelBottom: "EBBACD", wheelBorder: "CE94AF",
        wheelLabel: "8E5570",
        centerButtonTop: "FBE7EE", centerButtonBottom: "F0C8D8",
        isDarkBody: false, isGlass: false
    )

    static let miniGreen = Theme(
        id: "mini-green",
        name: "Mini Green",
        bodyTop: "C3DBA8", bodyBottom: "9BBE79", bodyBorder: "7B9E5B",
        screenBezel: "B2CE97", screenBackground: "1A2416",
        screenText: "FFFFFF", screenSecondaryText: "C3D4B5",
        wheelTop: "DEEBCC", wheelBottom: "BCD3A2", wheelBorder: "98B77A",
        wheelLabel: "5A7841",
        centerButtonTop: "E8F1DB", centerButtonBottom: "CBDEB4",
        isDarkBody: false, isGlass: false
    )

    static let miniGold = Theme(
        id: "mini-gold",
        name: "Mini Gold",
        bodyTop: "EBD9B4", bodyBottom: "D2B784", bodyBorder: "B39A69",
        screenBezel: "DFC9A0", screenBackground: "241E14",
        screenText: "FFFFFF", screenSecondaryText: "D6C6A9",
        wheelTop: "F5E9CF", wheelBottom: "E0CBA4", wheelBorder: "C0A87C",
        wheelLabel: "7E6944",
        centerButtonTop: "FAF1DE", centerButtonBottom: "EADBBC",
        isDarkBody: false, isGlass: false
    )

    /// Dark translucent skin that matches the stock macOS desktop widgets.
    /// Colours are deliberately low-alpha: a vibrancy layer behind the window
    /// supplies the blur, and these only tint it.
    static let liquidGlass = Theme(
        id: "liquid-glass",
        name: "Liquid Glass",
        bodyTop: "1C1C1E59", bodyBottom: "0A0A0C80", bodyBorder: "FFFFFF26",
        screenBezel: "FFFFFF14", screenBackground: "00000073",
        screenText: "FFFFFF", screenSecondaryText: "FFFFFFA6",
        wheelTop: "FFFFFF26", wheelBottom: "FFFFFF12", wheelBorder: "FFFFFF2E",
        wheelLabel: "FFFFFFD9",
        centerButtonTop: "FFFFFF33", centerButtonBottom: "FFFFFF1A",
        isDarkBody: true, isGlass: true
    )

    /// The same construction, tuned for light wallpapers.
    static let frostedGlass = Theme(
        id: "frosted-glass",
        name: "Frosted Glass",
        bodyTop: "FFFFFF73", bodyBottom: "F2F2F759", bodyBorder: "FFFFFF8C",
        screenBezel: "0000000F", screenBackground: "1C1F2499",
        screenText: "FFFFFF", screenSecondaryText: "FFFFFFB3",
        wheelTop: "FFFFFF99", wheelBottom: "FFFFFF66", wheelBorder: "FFFFFFB3",
        wheelLabel: "3C3C43D9",
        centerButtonTop: "FFFFFFB3", centerButtonBottom: "FFFFFF80",
        isDarkBody: false, isGlass: true
    )

    static let all: [Theme] = [
        liquidGlass, frostedGlass,
        classicWhite, classicBlack, miniSilver,
        miniBlue, miniPink, miniGreen, miniGold
    ]

    /// Glass is the default so the widget looks native on the desktop.
    static let fallback = liquidGlass

    static func theme(withID id: String) -> Theme {
        all.first { $0.id == id } ?? fallback
    }
}
