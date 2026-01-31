import Foundation

public enum STSMode {
    case scene(Int)
    case slate
    case photo
}

public protocol CameraControlling: AnyObject {
    func startRecording()
    func stopRecording()
    func capturePhotoViaRemote()
}

public protocol ModeControlling: AnyObject {
    func setMode(_ mode: STSMode)
}
