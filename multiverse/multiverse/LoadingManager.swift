import Foundation

class LoadingManager: ObservableObject {
    static let shared = LoadingManager()
    
    @Published var activeBoxNumber: Int? = nil
    private var boxes: Set<Int> = []
    private var timer: Timer?
    
    private init() {}
    
    func registerBox(_ boxNumber: Int, isLoading: Bool) {
        if isLoading {
            boxes.insert(boxNumber)
            startRotation()
        } else {
            boxes.remove(boxNumber)
            if boxes.isEmpty {
                stopRotation()
            }
        }
    }
    
    private func startRotation() {
        guard timer == nil, !boxes.isEmpty else { return }
        
        // Start with the first box
        if activeBoxNumber == nil || !boxes.contains(activeBoxNumber!) {
            activeBoxNumber = boxes.first
        }
        
        // Create timer to rotate between boxes every 0.5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, !self.boxes.isEmpty else { return }
            
            // Find the next box in the set
            if let current = self.activeBoxNumber {
                let sortedBoxes = self.boxes.sorted()
                if let currentIndex = sortedBoxes.firstIndex(of: current) {
                    let nextIndex = (currentIndex + 1) % sortedBoxes.count
                    self.activeBoxNumber = sortedBoxes[nextIndex]
                } else {
                    self.activeBoxNumber = sortedBoxes.first
                }
            } else {
                self.activeBoxNumber = self.boxes.first
            }
        }
    }
    
    private func stopRotation() {
        timer?.invalidate()
        timer = nil
        activeBoxNumber = nil
    }
} 