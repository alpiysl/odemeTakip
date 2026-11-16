import Foundation

/// `Banks.xcstrings`: banka adları ve rozet kısaltmaları.
extension L10n {
    enum Banks {
        private static func s(_ key: String, _ args: CVarArg...) -> String {
            L10n.string(key, table: "Banks", args: args)
        }

        static func name(_ bank: Bank) -> String {
            switch bank {
            case .isbank: s("banks.isbankName")
            case .garanti: s("banks.garantiName")
            case .akbank: s("banks.akbankName")
            case .qnb: s("banks.qnbName")
            case .halkbank: s("banks.halkbankName")
            case .vakifbank: s("banks.vakifbankName")
            case .ziraat: s("banks.ziraatName")
            }
        }

        static func monogram(_ bank: Bank) -> String {
            switch bank {
            case .isbank: s("banks.isbankMonogram")
            case .garanti: s("banks.garantiMonogram")
            case .akbank: s("banks.akbankMonogram")
            case .qnb: s("banks.qnbMonogram")
            case .halkbank: s("banks.halkbankMonogram")
            case .vakifbank: s("banks.vakifbankMonogram")
            case .ziraat: s("banks.ziraatMonogram")
            }
        }

        static var sectionBanks: String { s("banks.sectionBanks") }
        static var sectionOther: String { s("banks.sectionOther") }
    }
}
