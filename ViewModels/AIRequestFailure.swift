import Foundation

struct AIRequestFailure: Equatable {
    let title: String
    let message: String
    let canRetry: Bool

    init(error: Error, fallbackTitle: String) {
        if let networkError = error as? NetworkManagerError {
            title = networkError.alertTitle
            message = networkError.localizedDescription
            canRetry = networkError.canRetry
        } else if error is CancellationError {
            title = fallbackTitle
            message = "The AI request was cancelled."
            canRetry = true
        } else {
            title = fallbackTitle
            message = error.localizedDescription
            canRetry = true
        }
    }

    init(title: String, message: String, canRetry: Bool = false) {
        self.title = title
        self.message = message
        self.canRetry = canRetry
    }
}
