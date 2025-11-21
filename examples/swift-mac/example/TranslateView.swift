//
//  TranslateView.swift
//  example (macOS)
//

import SwiftUI

struct TranslateView: View {
    @State private var inputText: String = ""
    @State private var selectedLanguage: Language = .englishUS
    @State private var isTranslating = false
    @State private var translationResult: String = ""
    @State private var statusMessage: String = ""
    @State private var errorMessage: String = ""
    
    private let token = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyXzgzZTk5Y2YyIiwiZXhwIjoxNzY1MzU5Mjc4Ljk0ODk5fQ.JVL2o7u2IC-LhqFvSAmfE9oGVmnL7R4vfnxm_JA0V5k"
    
    private var api: TranscribeApi {
        TranscribeApi(token: token)
    }
    
    private let languages: [(Language, String)] = [
        (.chineseSimplified, "中文简体"),
        (.englishUS, "English"),
        (.japanese, "日本語"),
        (.korean, "한국어"),
        (.french, "Français"),
        (.german, "Deutsch")
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("翻译接口测试")
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 12)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("输入文本")
                    .font(.headline)
                TextEditor(text: $inputText)
                    .frame(minHeight: 140)
                    .border(Color.gray.opacity(0.3), width: 1)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("目标语言")
                    .font(.headline)
                Picker("目标语言", selection: $selectedLanguage) {
                    ForEach(languages, id: \.0) { lang, title in
                        Text(title).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Button(action: translate) {
                HStack {
                    if isTranslating {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    Text(isTranslating ? "翻译中..." : "翻译")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isTranslating ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isTranslating || inputText.isEmpty)
            
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if !translationResult.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("翻译结果")
                        .font(.headline)
                    ScrollView {
                        Text(translationResult)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(minHeight: 140)
                }
            }
            
            Spacer()
        }
        .padding(24)
    }
    
    private func translate() {
        guard !inputText.isEmpty else { return }
        isTranslating = true
        statusMessage = "正在翻译..."
        errorMessage = ""
        translationResult = ""
        
        Task {
            do {
                let result = try await api.translateText(
                    text: inputText,
                    targetLang: selectedLanguage
                )
                
                await MainActor.run {
                    isTranslating = false
                    statusMessage = "状态: \(result.status)"
                    translationResult = result.data
                }
            } catch {
                await MainActor.run {
                    isTranslating = false
                    statusMessage = ""
                    errorMessage = "翻译失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    TranslateView()
}

