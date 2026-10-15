//
//  ShareSheetPresenter.swift
//  Palettes
//
//  Presents UIActivityViewController from the top-most view controller (so it
//  works from inside sheets) and deletes a temp export once sharing finishes.
//
//  It presents in the window the person is using: on iPad several windows can
//  be open, and on iPhone Duo the app moves between displays, so "the first
//  connected scene" is not reliably the one on screen. On iPad the sheet is a
//  popover, which must have an anchor or UIKit raises an exception.
//

import UIKit

@MainActor
enum ShareSheetPresenter {
    static func present(items: [Any], cleanup: URL? = nil) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            if let cleanup { ExportFiles.remove(cleanup) }
        }
        guard let rootVC = activeWindow?.rootViewController else {
            if let cleanup { ExportFiles.remove(cleanup) }
            return
        }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        if let popover = activityVC.popoverPresentationController {
            // Toolbar actions sit at the top trailing corner; context-menu
            // actions have no lasting anchor, so this is the closest stable one.
            let bounds = topVC.view.bounds
            let isRTL = topVC.view.effectiveUserInterfaceLayoutDirection == .rightToLeft
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: isRTL ? bounds.minX + 50 : bounds.maxX - 50,
                y: topVC.view.safeAreaInsets.top,
                width: 1,
                height: 1
            )
        }
        topVC.present(activityVC, animated: true)
    }

    /// The key window of the foreground scene, falling back to any window of
    /// an active scene.
    private static var activeWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let foreground = scenes.filter { $0.activationState == .foregroundActive }
        return foreground.lazy.compactMap(\.keyWindow).first
            ?? foreground.lazy.compactMap(\.windows.first).first
            ?? scenes.lazy.compactMap(\.keyWindow).first
    }
}
