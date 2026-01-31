import AVFoundation

/// 🚨 CRITICAL FIX: Safe factory that always returns fresh AVPlayerItem instances
/// SOLVES: "An AVPlayerItem cannot be associated with more than one instance of AVPlayer" crash
/// RULE: Never reuse the same AVPlayerItem across multiple AVPlayer instances
public enum PlayerItemFactory {
    
    /// Creates a fresh AVPlayerItem - NEVER reuses existing items
    /// This prevents the critical crash when same item is attached to multiple players
    public static func makeItem(
        asset: AVAsset,
        videoComposition: AVVideoComposition? = nil,
        audioMix: AVAudioMix? = nil
    ) -> AVPlayerItem {
        let item = AVPlayerItem(asset: asset)
        item.videoComposition = videoComposition
        item.audioMix = audioMix
        
        print("🏭 PlayerItemFactory: Created fresh AVPlayerItem for asset")
        print("   📍 Item address: \(Unmanaged.passUnretained(item).toOpaque())")
        print("   🎬 Asset: \(asset)")
        print("   🎨 Has video composition: \(videoComposition != nil)")
        
        return item
    }
    
    /// Creates a fresh item from URL - convenience method
    public static func makeItem(
        url: URL,
        videoComposition: AVVideoComposition? = nil,
        audioMix: AVAudioMix? = nil
    ) -> AVPlayerItem {
        let asset = AVURLAsset(url: url)
        return makeItem(asset: asset, videoComposition: videoComposition, audioMix: audioMix)
    }
    
    /// Safely detach item from player before reuse/deallocation
    public static func detachItem(from player: AVPlayer) {
        print("🧹 PlayerItemFactory: Detaching item from player to prevent reuse")
#if DEBUG
        let playerID = String(describing: ObjectIdentifier(player))
        let itemID = player.currentItem.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
        print("🧪 PlayerItemFactory.detach player=\(playerID) item=\(itemID) main=\(Thread.isMainThread)")
#endif
        
        if let currentItem = player.currentItem {
            print("   📍 Detaching item: \(Unmanaged.passUnretained(currentItem).toOpaque())")
        }
        
        // Stop playback first
        player.pause()
        
        // Remove all time observers (prevents KVO issues)
        // Note: Specific time observers should be removed by their creators
        
        // Detach the item
        player.replaceCurrentItem(with: nil)
        
        print("✅ PlayerItemFactory: Item successfully detached")
    }
    
    /// Debug helper to log player item addresses for crash debugging
    public static func logPlayerItems(
        playerA: AVPlayer, labelA: String,
        playerB: AVPlayer, labelB: String
    ) {
        #if DEBUG
        print("🔍 PlayerItemFactory: Debug item addresses")
        
        if let itemA = playerA.currentItem {
            print("   \(labelA) item: \(Unmanaged.passUnretained(itemA).toOpaque())")
        } else {
            print("   \(labelA) item: nil")
        }
        
        if let itemB = playerB.currentItem {
            print("   \(labelB) item: \(Unmanaged.passUnretained(itemB).toOpaque())")
        } else {
            print("   \(labelB) item: nil")
        }
        
        // Check for dangerous reuse
        if let itemA = playerA.currentItem, let itemB = playerB.currentItem {
            let addressA = Unmanaged.passUnretained(itemA).toOpaque()
            let addressB = Unmanaged.passUnretained(itemB).toOpaque()
            
            if addressA == addressB {
                print("❌ CRITICAL ERROR: Same AVPlayerItem instance detected in both players!")
                print("   This WILL cause a crash. Use PlayerItemFactory.makeItem() for fresh items.")
                assertionFailure("AVPlayerItem reuse detected - this causes crashes")
            } else {
                print("✅ PlayerItemFactory: No item reuse detected - safe")
            }
        }
        #endif
    }
}

// MARK: - Safe Player Management Extensions

public extension AVPlayer {
    
    /// Safely replace current item using PlayerItemFactory hygiene
    func safelyReplaceItem(with newItem: AVPlayerItem?) {
#if DEBUG
        let playerID = String(describing: ObjectIdentifier(self))
        let currentID = currentItem.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
        let newID = newItem.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
        print("🧪 AVPlayer.safelyReplaceItem player=\(playerID) current=\(currentID) new=\(newID) main=\(Thread.isMainThread)")
#endif
        PlayerItemFactory.detachItem(from: self)
        
        if let newItem = newItem {
            print("🔄 AVPlayer: Attaching new item: \(Unmanaged.passUnretained(newItem).toOpaque())")
        }
        
        replaceCurrentItem(with: newItem)
    }
    
    /// Create a fresh item and attach it safely
    func setFreshItem(
        asset: AVAsset,
        videoComposition: AVVideoComposition? = nil,
        audioMix: AVAudioMix? = nil
    ) {
        let freshItem = PlayerItemFactory.makeItem(
            asset: asset,
            videoComposition: videoComposition,
            audioMix: audioMix
        )
        
        safelyReplaceItem(with: freshItem)
    }
}
