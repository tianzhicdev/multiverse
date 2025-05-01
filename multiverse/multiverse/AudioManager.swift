import Foundation
import AVFoundation

// Define view states
enum AppView {
    case boxGridView
    case shopView
    case landingView
    case fullImageView
    case other
}

class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var loadingTimer: Timer?
    private var isSearching = false
    private var useFirstSound = true
    
    @Published var loadingBoxCount = 0
    
    // Track current view
    private var currentView: AppView = .other
    
    // Update current view
    func setCurrentView(_ view: AppView) {
        let previousView = currentView
        currentView = view
        
        // Handle view transitions
        if previousView == .boxGridView && currentView != .boxGridView {
            // Left BoxGridView - pause sounds
            pauseSounds()
        } else if previousView != .boxGridView && currentView == .boxGridView {
            // Entered BoxGridView - resume sounds if needed
            resumeSoundsIfNeeded()
        }
    }
    
    private func pauseSounds() {
        // Keep track of state but pause actual playback
        audioPlayer?.pause()
    }
    
    private func resumeSoundsIfNeeded() {
        if isSearching && loadingBoxCount > 0 {
            if let player = audioPlayer {
                player.play()
            } else {
                playNextSearchSound()
            }
        }
    }
    
    func startLoadingSound() {
        if loadingBoxCount == 0 {
            // First box started loading
            isSearching = true
            if currentView == .boxGridView {
                playNextSearchSound()
            }
        }
        
        loadingBoxCount += 1
    }
    
    func stopLoadingSound() {
        loadingBoxCount -= 1
        
        if loadingBoxCount <= 0 {
            // No more boxes loading
            loadingBoxCount = 0
            isSearching = false
            loadingTimer?.invalidate()
            loadingTimer = nil
            audioPlayer?.stop()
        }
    }
    
    private func playNextSearchSound() {
        guard isSearching && currentView == .boxGridView else { return }
        
        // Determine which sound file to play
        let soundName = useFirstSound ? "searching1" : "searching2"
        useFirstSound.toggle()
        
        guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            print("Sound file \(soundName).mp3 not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } catch {
            print("Failed to play sound: \(error.localizedDescription)")
        }
    }
    
    // Play completion sound - will only play if on BoxGridView
    func playDingSound() {
        guard currentView == .boxGridView else { return }
        
        guard let soundURL = Bundle.main.url(forResource: "ding", withExtension: "mp3") else {
            print("Ding sound file not found")
            return
        }
        
        do {
            // Create a new player specifically for the ding
            let dingPlayer = try AVAudioPlayer(contentsOf: soundURL)
            dingPlayer.play()
        } catch {
            print("Failed to play ding sound: \(error.localizedDescription)")
        }
    }
}

// Extension to handle completion of audio playback
extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if isSearching && currentView == .boxGridView {
            // If still in searching state and on BoxGridView, play the next sound
            playNextSearchSound()
        }
    }
} 