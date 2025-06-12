import Foundation

func parseDate(val: String) -> Date {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    return dateFormatter.date(from:val)!
}

func randomSdkKey() -> String {
    return "\(randomLetters(len: 22))/\(randomLetters(len: 22))"
}

func randomLetters(len: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<len).map{ _ in letters.randomElement()! })
}

func loadResource(path: String) -> String {
    let url = Bundle.module.url(forResource: path, withExtension: nil)
    let data = try! Data(contentsOf: url!)
    let content = String(bytes: data, encoding: .utf8)
    return content!
}
