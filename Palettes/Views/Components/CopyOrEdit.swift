//
//  CopyOrEdit.swift
//  Palettes
//
//  The HEX and RGB value fields' gesture, shared by the add panel's Pick
//  source and Edit Color.
//

import SwiftUI

extension View {
    /// A value field that copies on tap and opens for typing on press and
    /// hold. While it is being edited, touches go to the text field itself.
    func copyOrEdit(isEditing: Bool, copy: @escaping () -> Void, edit: @escaping () -> Void) -> some View {
        contentShape(Rectangle())
            .onTapGesture {
                if !isEditing { copy() }
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                if !isEditing { edit() }
            }
            .accessibilityHint("Double-tap to copy. Use the Edit action to type a value.")
            .accessibilityAction(named: "Copy", copy)
            .accessibilityAction(named: "Edit", edit)
    }
}
