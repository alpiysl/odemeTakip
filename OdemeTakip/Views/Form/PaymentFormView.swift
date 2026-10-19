import SwiftUI

struct PaymentFormView: View {
    enum Mode {
        case create
        case edit(Payment)
    }

    let mode: Mode
    var onDeleteRequested: (() -> Void)? = nil

    var body: some View { Text("Form") }
}
