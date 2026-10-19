import SwiftUI

struct CashDetailView: View {
    let payment: Payment
    var body: some View { Text(payment.name) }
}
