import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    
    private var audioPlayers: [AVAudioPlayer] = []
    private var isPlaying = false
    private var timer: Timer?
    
    private init() {
        // Set up audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
        
        // Preload the sound files
        preloadSounds()
    }
    
    private func preloadSounds() {
        do {
            if let searching1URL = Bundle.main.url(forResource: "searching1", withExtension: "mp3") {
                let player1 = try AVAudioPlayer(contentsOf: searching1URL)
                player1.prepareToPlay()
                
                if let searching2URL = Bundle.main.url(forResource: "searching2", withExtension: "mp3") {
                    let player2 = try AVAudioPlayer(contentsOf: searching2URL)
                    player2.prepareToPlay()
                    
                    audioPlayers = [player1, player2]
                }
            }
        } catch {
            print("Error preloading audio players: \(error.localizedDescription)")
        }
    }
    
    func startLoadingSound() {
        guard !isPlaying else { return }
        
        // If players aren't loaded yet, try to load them
        if audioPlayers.isEmpty {
            preloadSounds()
        }
        
        guard !audioPlayers.isEmpty else {
            print("Cannot start loading sound: No audio players available")
            return
        }
        
        isPlaying = true
        
        // Start playing the first sound
        playNextSound()
    }
    
    private func playNextSound() {
        guard isPlaying, !audioPlayers.isEmpty else { return }
        
        // Get the first player, play it, and move it to the end of the array
        let currentPlayer = audioPlayers.removeFirst()
        audioPlayers.append(currentPlayer)
        
        // Reset player to start
        currentPlayer.currentTime = 0
        currentPlayer.play()
        
        // Schedule the next sound to play when this one finishes
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: currentPlayer.duration - 0.1, repeats: false) { [weak self] _ in
            self?.playNextSound()
        }
    }
    
    func stopLoadingSound() {
        guard isPlaying else { return }
        
        isPlaying = false
        timer?.invalidate()
        timer = nil
        
        // Stop all players
        audioPlayers.forEach { $0.stop() }
    }
    
    // Called when app is terminating or going to background
    func cleanup() {
        stopLoadingSound()
        
        // Release audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
} 