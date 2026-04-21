import Vision
import CoreGraphics
import Foundation

/// Extracts text from a CGImage using Apple Vision.
/// Runs entirely in-memory — screenshots are never saved to disk.
struct OCRProcessor {

    private let maxChars = 3_500   // cap tokens sent to AI

    func extractText(from image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            let req = VNRecognizeTextRequest { req, err in
                if let err { cont.resume(throwing: err); return }

                let lines = (req.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { obs -> String? in
                        guard let top = obs.topCandidates(1).first,
                              top.confidence > 0.38 else { return nil }
                        let s = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        return s.isEmpty ? nil : s
                    }

                // Deduplicate adjacent identical lines
                var seen = Set<String>()
                let deduped = lines.filter { seen.insert($0).inserted }

                var joined = deduped.joined(separator: "\n")
                if joined.count > maxChars {
                    joined = String(joined.prefix(maxChars)) + "\n…[truncated]"
                }

                cont.resume(returning: joined)
            }

            req.recognitionLevel         = .accurate
            req.usesLanguageCorrection   = true
            req.automaticallyDetectsLanguage = true

            do {
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([req])
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}
