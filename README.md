# FireSwiftData 🔥📦

**FireSwiftData** is a lightweight Swift package that simplifies reading, writing, and deleting strongly-typed models in Firebase Firestore. It supports both async/await and completion handler APIs. It also includes a PDF report generator using `PDFKit`.

---

## 📦 Features

- 🔄 Read, write, delete Firestore documents (async/await or completion)
- 🧵 Thread-safe operations using `DispatchQueue`
- 📄 PDF report generation for Firestore data
- 👤 Works with any model conforming to `FireSwiftDataRepresentable`

---

## 🧰 Requirements

- iOS 13.0+
- Xcode 13+
- Swift 5.5+
- Firebase Firestore SDK

---

## 🚀 Installation

### ➕ Swift Package Manager (SPM)

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/FireSwiftData.git", from: "1.0.0")
]
```

### 📦 CocoaPods

First, make sure you have [CocoaPods](https://cocoapods.org) installed. Then:

1. Add this to your `Podfile`:
```ruby
pod 'FireSwiftData'
```

2. Run:
```bash
pod install
```

---

## 🧑‍💻 Usage

### Your Model

```swift
struct Task: FireSwiftDataRepresentable {
    let id: String
    let title: String
    static let collectionName = "tasks"
}
```

### Write (Completion)

```swift
FireSwiftData.shared.write(item: task) { result in
    switch result {
    case .success(): print("Saved!")
    case .failure(let error): print("Error: \(error)")
    }
}
```

### Write (Async/Await)

```swift
try await FireSwiftData.shared.write(item: task)
```
