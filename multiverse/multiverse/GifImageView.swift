import SwiftUI
import WebKit

struct GifImageView: UIViewRepresentable {
    let gifName: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let gifURL = Bundle.main.url(forResource: gifName, withExtension: "gif") {
            let request = URLRequest(url: gifURL)
            uiView.load(request)
        }
    }
} 