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
        
        // Start with a random box
        if activeBoxNumber == nil || !boxes.contains(activeBoxNumber!) {
            let boxesArray = Array(boxes)
            let randomIndex = Int.random(in: 0..<boxesArray.count)
            activeBoxNumber = boxesArray[randomIndex]
        }
        
        // Create timer to rotate between boxes every 0.5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, !self.boxes.isEmpty else { return }
            
            // Randomly select a box from the set
            let boxesArray = Array(self.boxes)
            let randomIndex = Int.random(in: 0..<boxesArray.count)
            self.activeBoxNumber = boxesArray[randomIndex]
        }
    }
    
    private func stopRotation() {
        timer?.invalidate()
        timer = nil
        activeBoxNumber = nil
    }
} 