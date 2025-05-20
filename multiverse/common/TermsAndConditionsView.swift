import SwiftUI

struct TermsAndConditionsView: View {
    @State private var termsText: String = ""
    @State private var attributedTerms: AttributedString = AttributedString("")
    @State private var isLoading: Bool = true
    @State private var scrollOffset: CGFloat = 0
    @State private var hasReachedBottom: Bool = false
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Terms and Conditions")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text(attributedTerms)
                                .padding(.horizontal)
                        }
                        .id("termsContent")
                        
                        // Invisible marker at the bottom to detect when user has scrolled to bottom
                        Text("")
                            .frame(height: 1)
                            .id("bottomMarker")
                            .onAppear {
                                withAnimation {
                                    hasReachedBottom = true
                                }
                            }
                    }
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, 
                                           value: geo.frame(in: .global).minY)
                        }
                    )
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                    }
                }
            }
            
            VStack(spacing: 15) {
                Button(action: {
                    // Save acceptance
                    UserManager.shared.acceptTerms()
                    isPresented = false
                }) {
                    Text("I Accept")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hasReachedBottom ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!hasReachedBottom)
                
                if !hasReachedBottom {
                    Text("Please scroll to the bottom to continue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            loadTermsText()
        }
    }
    
    private func loadTermsText() {
        isLoading = true
        if let fileURL = Bundle.main.url(forResource: "terms_and_conditions", withExtension: "md") {
            do {
                termsText = try String(contentsOf: fileURL, encoding: .utf8)
                
                // Convert Markdown to AttributedString
                do {
                    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                    attributedTerms = try AttributedString(markdown: termsText, options: options)
                } catch {
                    print("Error parsing markdown: \(error)")
                    attributedTerms = AttributedString(termsText)
                }
                
                isLoading = false
            } catch {
                termsText = "Error loading terms and conditions: \(error.localizedDescription)"
                attributedTerms = AttributedString(termsText)
                isLoading = false
            }
        } else {
            termsText = "Terms and conditions file not found."
            attributedTerms = AttributedString(termsText)
            isLoading = false
        }
    }
}

// Preference key to track scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    TermsAndConditionsView(isPresented: .constant(true))
} 