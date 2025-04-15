//
//  PromptExecutor.swift
//  Passage
//
//  Created by Tyler Hall on 2/14/25.
//

import Foundation

class PromptExecutor {

    private let defaultAPIBaseURLStr = "http://127.0.0.1:1234/v1"
    private let defaultAPIKey = "12345"

    private var initialInput: String
    private var prompts: [Prompt]
    private var memory: [String: String] = [:]
    private var outputFolder: String?

    init(initialInput: String, prompts: [Prompt], ouputFolder: String? = nil) {
        self.initialInput = initialInput
        self.prompts = prompts
        self.outputFolder = ouputFolder
    }

    func runPrompts() {
        for prompt in prompts {
            var message = prompt.text.replacingOccurrences(of: "{{input}}", with: initialInput)
            for (key, val) in memory {
                let needle = "{{\(key)}}"
                message = message.replacingOccurrences(of: needle, with: val)
            }

            var response: String
            if let model = prompt.model {
                response = synchronousLLMRequest(message: message, prompt: prompt, model: model)
            } else { // If no model, passthrough
                response = message
            }

            for output in prompt.outputs {
                switch output.type {
                case .stdout:
                    print(response)
                case .variable:
                    if let name = output.name, let method = output.method {
                        switch method {
                        case .replace:
                            memory[name] = response
                        case .append:
                            memory[name] = (memory[name] == nil) ? response : (memory[name]! + "\n" + response)
                        case .prepend:
                            memory[name] = (memory[name] == nil) ? response : (response + "\n" + memory[name]!)
                        }
                    }
                case .file:
                    if let filename = output.name, let method = output.method {
                        switch method {
                        case .replace:
                            writeToFile(filename: filename, content: response)
                        case .append:
                            appendToFile(filename: filename, content: response)
                        case .prepend:
                            prependToFile(filename: filename, content: response)
                        }
                    }
                }
            }
        }
    }
    
    private func synchronousLLMRequest(message: String, prompt: Prompt, model: String) -> String {
        let apiBaseURLStr = prompt.apiBaseURL ?? defaultAPIBaseURLStr
        let apiKey = prompt.apiToken ?? defaultAPIKey

        guard let url = URL(string: "\(apiBaseURLStr)/chat/completions") else {
            print("Invalid apiBaseURL: \(apiBaseURLStr)")
            exit(EXIT_FAILURE)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": message]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            print("Failed to parse JSON response", error)
            exit(EXIT_FAILURE)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result = ""

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval.infinity
        config.timeoutIntervalForResource = TimeInterval.infinity
        let session = URLSession(configuration: config)

        let task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("Request error:", error)
                exit(EXIT_FAILURE)
            }
            
            guard let data = data else {
                print("No response data")
                exit(EXIT_FAILURE)
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                        result = content.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    print("Unexpected response format",  error ?? "")
                    exit(EXIT_FAILURE)
                }
            } catch {
                print("Failed to parse response:", error)
                exit(EXIT_FAILURE)
            }
        }

        task.resume()
        semaphore.wait()

        return result
    }

    private func writeToFile(filename: String, content: String) {
        let folderPath = outputFolder ?? FileManager.default.currentDirectoryPath
        let fileURL = URL(filePath: folderPath).appending(path: filename, directoryHint: .notDirectory)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write output to", fileURL.path)
            exit(EXIT_FAILURE)
        }
    }

    private func appendToFile(filename: String, content: String) {
        let folderPath = outputFolder ?? FileManager.default.currentDirectoryPath
        let fileURL = URL(filePath: folderPath).appending(path: filename, directoryHint: .notDirectory)

        var newContents: String
        if let existingFileContents = try? String(contentsOf: fileURL, encoding: .utf8) {
            newContents = existingFileContents + "\n" + content
        } else {
            newContents = content
        }
        writeToFile(filename: filename, content: newContents)
    }

    private func prependToFile(filename: String, content: String) {
        let folderPath = outputFolder ?? FileManager.default.currentDirectoryPath
        let fileURL = URL(filePath: folderPath).appending(path: filename, directoryHint: .notDirectory)

        var newContents: String
        if let existingFileContents = try? String(contentsOf: fileURL, encoding: .utf8) {
            newContents = content + "\n" + existingFileContents
        } else {
            newContents = content
        }
        writeToFile(filename: filename, content: newContents)
    }
}
