import SwiftUI
import Combine

/// Manages display of a small confirmation pill/toast under the Dynamic Island.
@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var message: String = ""
    @Published var icon: String = "checkmark.circle.fill"
    @Published var isShowing: Bool = false
    
    private var hideWork: DispatchWorkItem?
    
    func show(_ message: String, icon: String = "doc.on.doc.fill") {
        hideWork?.cancel()
        self.message = message
        self.icon = icon
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isShowing = true
        }
        
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) {
                self?.isShowing = false
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }
}

/// A view modifier that overlays the toast pill at the top of the screen.
struct ToastOverlay: ViewModifier {
    @StateObject private var manager = ToastManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if manager.isShowing {
                    HStack(spacing: 8) {
                        Image(systemName: manager.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(manager.message)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .liquidGlass(.regular, in: .capsule)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                }
            }
    }
}

extension View {
    func toastOverlay() -> some View {
        modifier(ToastOverlay())
    }
}

/// Convenience: copy to clipboard and show toast.
@MainActor
func copyToClipboard(_ text: String, label: String) {
    UIPasteboard.general.string = text
    ToastManager.shared.show(label)
}
