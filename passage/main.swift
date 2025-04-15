//
//  main.swift
//  Passage
//
//  Created by Tyler Hall on 2/14/25.
//

import Foundation
import ArgumentParser

struct Passage: ParsableCommand {

    @Argument(help: "Path to the folder of text prompts")
    var promptsFolder: String

    @Option(name: .shortAndLong, help: "Path to initial text input")
    var inputFile: String?

    @Option(name: .shortAndLong, help: "Path to output folder")
    var outputFolder: String?

    func run() throws {
        var initialInput: String
        if let inputFile = inputFile {
            guard let str = try? String(contentsOfFile: inputFile, encoding: .utf8) else {
                print("Could not read input file at", inputFile)
                Passage.exit()
            }
            initialInput = str
        } else {
            let stdin = FileHandle.standardInput.readDataToEndOfFile()
            guard let str = String(data: stdin, encoding: .utf8) else {
                print("Could not read stdin")
                Passage.exit()
            }
            initialInput = str
        }
        
        var prompts = [Prompt]()
        let urls = try textFiles(in: promptsFolder)
        for url in urls {
            if let prompt = Prompt(fileURL: url) {
                prompts.append(prompt)
            }
        }

        let executor = PromptExecutor(initialInput: initialInput, prompts: prompts, ouputFolder: outputFolder)
        executor.runPrompts()
    }

    private func textFiles(in folderPath: String) throws -> [URL] {
        let textFileExtensions = ["txt", "md", "mdown", "markdown", "yml", "yaml"]
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(atPath: folderPath)
        var urls: [URL] = []

        while let element = enumerator?.nextObject() as? String {
            let url = URL(fileURLWithPath: folderPath).appendingPathComponent(element)
            let ext = url.pathExtension.lowercased()
            if textFileExtensions.contains(ext) {
                urls.append(url)
            }
        }

        return urls.sorted { $0.path < $1.path }
    }
}

Passage.main()
