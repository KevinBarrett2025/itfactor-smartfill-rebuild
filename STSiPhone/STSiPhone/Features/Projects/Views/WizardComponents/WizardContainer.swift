//
//  WizardContainer.swift
//  STSiPhone
//
//  Keyboard-safe form container to prevent snapshot + sessionID churn
//

import SwiftUI

struct WizardContainer<Content: View>: View {
    @FocusState private var focused: Bool
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onTapGesture { focused = false }
    }
}