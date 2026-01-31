import SwiftUI
import AVFoundation

struct LightweightEditorView: UIViewControllerRepresentable {
    let asset: AVAsset
    let onSave: (AVAsset, CMTimeRange?, CGRect?, Double?) -> Void
    let onCancel: () -> Void
    
    // NEW: Repository context for SmartFill integration
    let repository: ProjectsRepository?
    let take: ProjectTake?
    let session: ProjectSession?
    let project: Project?
    
    init(
        asset: AVAsset,
        repository: ProjectsRepository? = nil,
        take: ProjectTake? = nil,
        session: ProjectSession? = nil,
        project: Project? = nil,
        onSave: @escaping (AVAsset, CMTimeRange?, CGRect?, Double?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.asset = asset
        self.repository = repository
        self.take = take
        self.session = session
        self.project = project
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let editor = LightweightEditorViewController(asset: asset)
        editor.onSaveEdits = onSave
        editor.onCancel = onCancel
        
        // PHASE 3: Setup repository context if available
        if let repository = repository,
           let take = take,
           let session = session,
           let project = project {
            editor.setupWithRepository(repository, take: take, session: session, project: project)
        }
        
        // CRITICAL FIX: Wrap in navigation controller so close button appears
        let navigationController = UINavigationController(rootViewController: editor)
        
        if STS_ENTERPRISE_EDITOR_ENABLED {
            navigationController.setNavigationBarHidden(true, animated: false)
        } else {
            editor.title = "reFactor Video Editor"
            navigationController.navigationBar.barStyle = .black
            navigationController.navigationBar.tintColor = .white
            navigationController.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
            navigationController.navigationBar.isTranslucent = false
            navigationController.navigationBar.backgroundColor = .black
        }
        
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // Updates not needed for this use case
    }
}

// MARK: - Preview Helper
#Preview {
    // Create a simple test asset
    let url = Bundle.main.url(forResource: "test", withExtension: "mov") ?? URL(fileURLWithPath: "")

        let asset = AVURLAsset(url: url)

    LightweightEditorView(
        asset: asset,
        onSave: { asset, trimRange, cropRect, rotation in
            print("Save: \(asset), trim: \(String(describing: trimRange)), crop: \(String(describing: cropRect))")
        },
        onCancel: {
            print("Cancel")
        }
    )
}
