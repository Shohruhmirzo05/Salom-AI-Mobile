//
//  String+.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 30/11/25.
//

import SwiftUI

extension String {
    func toDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: self)
    }
    
    func ToDatePlaceHolder() -> String {
        let placeholder = "kk.oo.yyyy"
        if placeholder.count - self.count >= 0 {
            return self + placeholder.suffix(placeholder.count - self.count)
        } else {
            return self
        }
    }
    func FromDatePlaceHolder() -> String {
        let placeholder = "kk.oo.yyyy"
        if placeholder.count - self.count >= 0 {
            return self + placeholder.suffix(placeholder.count - self.count)
        } else {
            return self
        }
    }
    
    var formattedAsDate: String {
        let digits = self.filter { $0.isWholeNumber }
        
        var formattedDate = ""
        var index = digits.startIndex
        
        if digits.count > 2 {
            formattedDate.append(contentsOf: digits.prefix(2))
            formattedDate.append(".")
            index = digits.index(index, offsetBy: 2)
        } else if digits.count > 0 {
            formattedDate.append(contentsOf: digits)
            index = digits.endIndex
        }
        
        if digits.count > 4 {
            formattedDate.append(contentsOf: digits[index..<digits.index(index, offsetBy: 2)])
            formattedDate.append(".")
            index = digits.index(index, offsetBy: 2)
        } else if digits.count > 2 {
            formattedDate.append(contentsOf: digits[index..<digits.endIndex])
            index = digits.endIndex
        }
        
        if index < digits.endIndex {
            formattedDate.append(contentsOf: digits[index..<digits.endIndex])
        }
        
        return formattedDate
    }
    
    var toInt: Int? {
        return Int(self)
    }
}

func DateFrmatWithTimeStamp(_ iso8601String: String) -> String {
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    guard let date = isoFormatter.date(from: iso8601String) else {
        return "qo'yilgan vaqt noma'lum"
    }
    
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy"
    formatter.locale = Locale(identifier: "en_US")
    formatter.timeZone = TimeZone.current
    
    return formatter.string(from: date)
}

func ParseProductDescription(_ description: String) -> [String: String] {
    var parsedData: [String: String] = [:]
    
    let lines = description.split(separator: "\n")
    
    for line in lines {
        let components = line.split(separator: "\t")
        
        if components.count > 1 {
            let key = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            parsedData[String(key)] = String(value)
        }
    }
    
    return parsedData
}

