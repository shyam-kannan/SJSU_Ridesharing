import SwiftUI
import UIKit
import Vision
import AVFoundation

struct IDVerificationView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var capturedImage: UIImage?
    @State private var detectedText: [String] = []
    @State private var isUploading = false
    @State private var uploadSuccess = false
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var cameraPermissionDenied = false
    @State private var showValidationFailAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {

                    if uploadSuccess {
                        // ── Success State ──
                        successView
                    } else if let image = capturedImage {
                        // ── Preview + Submit State ──
                        previewView(image: image)
                    } else {
                        // ── Initial State ──
                        instructionsView
                    }
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Verify SJSU ID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Text("Skip for now")
                            .font(.system(size: 15))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePickerView(image: $capturedImage, sourceType: .camera) { image in
                    if let img = image { extractText(from: img) }
                }
            }
            .alert("Camera Access Required", isPresented: $cameraPermissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please allow camera access in Settings to scan your SJSU ID.")
            }
            .alert("Invalid ID", isPresented: $showValidationFailAlert) {
                Button("Retake Photo") {
                    withAnimation { capturedImage = nil; detectedText = [] }
                    checkCameraPermission()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This doesn't look like an SJSU Student ID. Please scan a valid SJSU Tower Card or ID card.")
            }
        }
    }

    // MARK: - Debug Test Helpers

    #if DEBUG
    private func useTestID() {
        let testImage = makeTestSJSUIDImage()
        capturedImage = testImage
        extractText(from: testImage)
    }

    /// Draws a fake-but-realistic SJSU ID card at runtime — no real PNG needed.
    private func makeTestSJSUIDImage() -> UIImage {
        let size = CGSize(width: 480, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // Card background (dark blue)
            UIColor(red: 0.00, green: 0.21, blue: 0.42, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 16).fill()

            // Gold stripe at top
            UIColor(red: 0.93, green: 0.79, blue: 0.36, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: size.width, height: 14)).fill()

            // White content area
            UIColor.white.setFill()
            UIBezierPath(roundedRect: CGRect(x: 16, y: 24, width: size.width - 32, height: size.height - 40), cornerRadius: 10).fill()

            let center = NSMutableParagraphStyle()
            center.alignment = .center

            func attrs(_ size: CGFloat, bold: Bool = false, color: UIColor = .black) -> [NSAttributedString.Key: Any] {
                [.font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size),
                 .foregroundColor: color, .paragraphStyle: center]
            }

            let contentX: CGFloat = 16
            let contentW = size.width - 32

            ("SAN JOSE STATE UNIVERSITY" as NSString)
                .draw(in: CGRect(x: contentX, y: 34, width: contentW, height: 24),
                      withAttributes: attrs(15, bold: true, color: UIColor(red: 0.00, green: 0.21, blue: 0.42, alpha: 1)))

            ("SJSU" as NSString)
                .draw(in: CGRect(x: contentX, y: 58, width: contentW, height: 36),
                      withAttributes: attrs(28, bold: true, color: UIColor(red: 0.00, green: 0.21, blue: 0.42, alpha: 1)))

            // Separator line
            cgCtx.setStrokeColor(UIColor.lightGray.cgColor)
            cgCtx.setLineWidth(1)
            cgCtx.move(to: CGPoint(x: 32, y: 100))
            cgCtx.addLine(to: CGPoint(x: size.width - 32, y: 100))
            cgCtx.strokePath()

            ("TOWER CARD" as NSString)
                .draw(in: CGRect(x: contentX, y: 108, width: contentW, height: 20),
                      withAttributes: attrs(13, color: .gray))

            ("Student" as NSString)
                .draw(in: CGRect(x: contentX, y: 136, width: contentW, height: 22),
                      withAttributes: attrs(14))

            ("Test User Name" as NSString)
                .draw(in: CGRect(x: contentX, y: 162, width: contentW, height: 22),
                      withAttributes: attrs(14, bold: true))

            ("Student ID: 012345678" as NSString)
                .draw(in: CGRect(x: contentX, y: 192, width: contentW, height: 22),
                      withAttributes: attrs(14, bold: true))

            ("Class of 2026" as NSString)
                .draw(in: CGRect(x: contentX, y: 220, width: contentW, height: 20),
                      withAttributes: attrs(12, color: .gray))
        }
    }
    #endif

    // MARK: - Instructions View

    private var instructionsView: some View {
        VStack(spacing: 28) {

            // Hero illustration
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.brand.opacity(0.08))
                    .frame(height: 200)

                VStack(spacing: 12) {
                    Image(systemName: "creditcard.viewfinder")
                        .font(.system(size: 64))
                        .foregroundColor(.brand)
                    Text("Scan your SJSU ID card")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.horizontal, AppConstants.pagePadding)
            .padding(.top, 32)

            // Steps
            VStack(alignment: .leading, spacing: 20) {
                Text("How it works")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, AppConstants.pagePadding)

                VerificationStep(number: 1, title: "Position your ID",
                    description: "Hold your SJSU ID card flat and in good lighting")
                VerificationStep(number: 2, title: "Capture",
                    description: "Tap the button to take a clear photo of your card")
                VerificationStep(number: 3, title: "Verify",
                    description: "We'll extract your ID number and submit for verification")
            }

            // Privacy note
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.brandGreen)
                Text("Your ID is encrypted and stored securely. We only verify your SJSU enrollment.")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
            }
            .padding()
            .background(Color.brandGreen.opacity(0.08))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.brandGreen.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, AppConstants.pagePadding)

            // ── Debug test shortcut (appears above camera button, DEBUG only) ──
            #if DEBUG
            Button(action: useTestID) {
                HStack(spacing: 10) {
                    Text("🧪")
                        .font(.system(size: 18))
                    Text("USE TEST ID (Debug Mode)")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.yellow.opacity(0.35))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.yellow, lineWidth: 1.5)
                )
            }
            .padding(.horizontal, AppConstants.pagePadding)
            #endif

            // Camera Button
            PrimaryButton(title: "Scan My SJSU ID", icon: "camera.fill") {
                checkCameraPermission()
            }
            .padding(.horizontal, AppConstants.pagePadding)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Preview View

    private func previewView(image: UIImage) -> some View {
        VStack(spacing: 24) {
            // Image preview
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                    .padding(.horizontal, AppConstants.pagePadding)
                    .padding(.top, 24)

                Button(action: {
                    withAnimation { capturedImage = nil; detectedText = [] }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                }
                .padding(.top, 28)
                .padding(.trailing, AppConstants.pagePadding + 8)
            }

            // Detected text
            if !detectedText.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.brandGreen)
                        Text("Information detected")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                    }
                    ForEach(detectedText.prefix(4), id: \.self) { text in
                        Text("• \(text)")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding()
                .background(Color.brandGreen.opacity(0.08))
                .cornerRadius(14)
                .padding(.horizontal, AppConstants.pagePadding)
            } else {
                ToastBanner(message: "No text detected. Try better lighting.", type: .warning)
                    .padding(.horizontal, AppConstants.pagePadding)
            }

            // Error
            if let err = errorMessage {
                ToastBanner(message: err, type: .error)
                    .padding(.horizontal, AppConstants.pagePadding)
            }

            // Buttons
            VStack(spacing: 12) {
                PrimaryButton(
                    title: "Submit for Verification",
                    icon: "checkmark",
                    isLoading: isUploading
                ) { uploadID() }

                SecondaryButton(title: "Retake Photo", icon: "camera") {
                    withAnimation { capturedImage = nil; detectedText = [] }
                    showCamera = true
                }
            }
            .padding(.horizontal, AppConstants.pagePadding)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 60)

            ZStack {
                Circle()
                    .fill(Color.brandGreen.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.brandGreen)
            }
            .scaleEffect(uploadSuccess ? 1 : 0.5)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: uploadSuccess)

            VStack(spacing: 10) {
                Text("ID Submitted!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.textPrimary)

                Text("Your SJSU ID is under review.\nYou can start using the app while we verify.")
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            ToastBanner(message: "Verification typically takes 1-2 business days", type: .info)
                .padding(.horizontal, AppConstants.pagePadding)

            PrimaryButton(title: "Start Using LessGo", icon: "arrow.right") {
                dismiss()
            }
            .padding(.horizontal, AppConstants.pagePadding)
        }
    }

    // MARK: - Actions

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showCamera = true } else { cameraPermissionDenied = true }
                }
            }
        default:
            cameraPermissionDenied = true
        }
    }

    private func extractText(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        let request = VNRecognizeTextRequest { req, _ in
            let observations = req.results as? [VNRecognizedTextObservation] ?? []
            let texts = observations.compactMap { $0.topCandidates(1).first?.string }
            DispatchQueue.main.async {
                detectedText = texts
                // Validate immediately after extraction
                if !texts.isEmpty && !validateSJSUID(texts: texts) {
                    showValidationFailAlert = true
                    capturedImage = nil
                    detectedText = []
                }
            }
        }
        request.recognitionLevel = .accurate

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([request])
    }

    /// Returns true only when the extracted texts contain the markers of a genuine SJSU ID.
    private func validateSJSUID(texts: [String]) -> Bool {
        let combined = texts.joined(separator: " ").lowercased()

        let hasSJSU = combined.contains("sjsu") ||
                      combined.contains("san jose state")

        let hasStudentKeyword = combined.contains("student") ||
                                combined.contains("tower card") ||
                                combined.contains("tower")

        // Accepts any 9-digit run of digits (SJSU student ID format)
        let hasStudentID: Bool = {
            guard let regex = try? NSRegularExpression(pattern: "\\b\\d{9}\\b") else { return false }
            let range = NSRange(combined.startIndex..., in: combined)
            return regex.firstMatch(in: combined, range: range) != nil
        }()

        return hasSJSU && (hasStudentKeyword || hasStudentID)
    }

    private func uploadID() {
        guard let image = capturedImage,
              let userId = authVM.currentUser?.id else { return }

        isUploading = true
        errorMessage = nil

        Task {
            do {
                _ = try await AuthService.shared.uploadSJSUID(image: image, userId: userId)

                #if DEBUG
                // In debug builds, instantly approve the test ID so the banner
                // disappears and the user can immediately browse/book trips.
                await authVM.autoVerifyForDebug()
                #else
                await authVM.refreshUser()
                #endif

                withAnimation { uploadSuccess = true }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = "Upload failed: \(error.localizedDescription)"
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            isUploading = false
        }
    }
}

// MARK: - Verification Step

private struct VerificationStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Color.brand).frame(width: 30, height: 30)
                Text("\(number)").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.textPrimary)
                Text(description).font(.system(size: 14)).foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, AppConstants.pagePadding)
    }
}

// MARK: - Image Picker Wrapper

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    var onImagePicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let img = info[.originalImage] as? UIImage
            parent.image = img
            parent.onImagePicked(img)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
