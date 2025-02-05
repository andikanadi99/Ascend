//
//  BannerNotification.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/5/25.
//

import SwiftUI

struct BannerNotification: ViewModifier {
    let message: String
    @Binding var isPresented: Bool
    let duration: Double

    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                VStack {
                    Text(message)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 0, green: 1, blue: 1))  // bright cyan background
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 5)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .transition(.move(edge: .top))
                    Spacer()
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        withAnimation {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
}

extension View {
    func banner(message: String, isPresented: Binding<Bool>, duration: Double = 2.5) -> some View {
        self.modifier(BannerNotification(message: message, isPresented: isPresented, duration: duration))
    }
}
