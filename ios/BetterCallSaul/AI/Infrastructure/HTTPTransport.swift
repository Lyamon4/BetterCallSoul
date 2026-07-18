import Foundation

protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionHTTPTransport: HTTPTransport {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw AIProviderError.transport("Ответ не является HTTP.")
            }
            return (data, response)
        } catch let error as AIProviderError {
            throw error
        } catch {
            throw AIProviderError.transport(error.localizedDescription)
        }
    }
}
