import SwiftUI

struct CreditDetailView: View {
    let payment: Payment
    var body: some View { Text(payment.name) }
}
