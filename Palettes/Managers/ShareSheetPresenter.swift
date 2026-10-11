//
//  ShareSheetPresenter.swift
//  Palettes
//
//  Presents UIActivityViewController from the top-most view controller (so it
//  works from inside sheets) and deletes a temp export once sharing finishes.
//

import UIKit

@MainActor
enum ShareSheetPresenter {
    static func present(items: [Any], cleanup: URL? = nil) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            if let cleanup { ExportFiles.remove(cleanup) }
        }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            if let cleanup { ExportFiles.remove(cleanup) }
            return
        }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        activityVC.popoverPresentationController?.sourceView = topVC.view
        activityVC.popoverPresentationController?.sourceRect = CGRect(x: topVC.view.bounds.maxX - 50, y: 0, width: 1, height: 1)
        topVC.present(activityVC, animated: true)
    }
}
