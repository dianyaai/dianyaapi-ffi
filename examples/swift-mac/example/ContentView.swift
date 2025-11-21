//
//  ContentView.swift
//  example
//
//  Created by Jesse on 2025/11/21.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TranslateView()
                .tabItem {
                    Label("翻译测试", systemImage: "character.book.closed")
                }
            
            TranscribeView()
                .tabItem {
                    Label("实时转写", systemImage: "mic.fill")
                }
        }
    }
}

#Preview {
    ContentView()
}
