//
//  GrowingTextEditor.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 5/22/25.
//


import SwiftUI

struct GrowingTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat         // <- will be updated

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isScrollEnabled = false
        tv.font = .systemFont(ofSize: 15)
        tv.backgroundColor = .clear
        tv.delegate = context.coordinator
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text { tv.text = text }
        // Measure
        let size = tv.sizeThatFits(CGSize(width: tv.bounds.width,
                                          height: .greatestFiniteMagnitude))
        if abs(size.height - height) > 0.5 {
            DispatchQueue.main.async { height = size.height }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextEditor
        init(_ p: GrowingTextEditor) { parent = p }
        func textViewDidChange(_ tv: UITextView) { parent.text = tv.text }
    }
}
