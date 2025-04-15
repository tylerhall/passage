//
//  Prompt.swift
//  Passage
//
//  Created by Tyler Hall on 2/14/25.
//

import Foundation
import Yams

struct Prompt: Codable {
    var name: String?
    var apiBaseURL: String?
    var apiToken: String?
    var model: String?
    var outputs: [Output]
    var text: String = ""
    
    enum CodingKeys: String, CodingKey {
        case name
        case model
        case outputs
    }

    enum OutputType: String, Codable {
        case stdout
        case variable
        case file
    }
    
    enum OutputMethod: String, Codable {
        case replace
        case append
        case prepend
    }

    struct Output: Codable {
        var type: OutputType
        var name: String?
        var method: OutputMethod?
    }
    
    init?(fileURL: URL) {
        do {
            let str = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = str.components(separatedBy: .newlines)

            var parsingHeader = true
            var headerArr = [String]()
            var textArr = [String]()

            for line in lines {
                if parsingHeader {
                    if line.hasPrefix("---") {
                        parsingHeader = false
                    } else {
                        headerArr.append(line)
                    }
                } else {
                    textArr.append(line)
                }
            }

            guard let yamlData = headerArr.joined(separator: "\n").data(using: .utf8) else { return nil }
            let yaml = try YAMLDecoder().decode(Prompt.self, from: yamlData)
            self = yaml

            text = textArr.joined(separator: "\n")
        } catch {
            print(error)
            return nil
        }
    }
}
