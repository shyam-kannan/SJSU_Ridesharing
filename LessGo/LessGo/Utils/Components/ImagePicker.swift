import SwiftUI
import PhotosUI
import UIKit

// MARK: - Image Picker (Using PHPickerViewController)

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    let sourceType: SourceType

    enum SourceType {
        case camera
        case photoLibrary
    }

    func makeUIViewController(context: Context) -> UIViewController {
        if sourceType == .photoLibrary {
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1

            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = context.coordinator
            picker.allowsEditing = true
            return picker
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        // PHPickerViewController delegate (for photo library)
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }

        // UIImagePickerController delegate (for camera)
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }

            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Profile Image Picker with Action Sheet

struct ProfileImagePickerView: View {
    @Binding var selectedImage: UIImage?
    @Binding var showPicker: Bool
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showActionSheet = false

    var onRemovePhoto: (() -> Void)?

    var body: some View {
        EmptyView()
            .confirmationDialog("Change Profile Photo", isPresented: $showActionSheet, titleVisibility: .visible) {
                Button("Take Photo") {
                    showCamera = true
                }
                Button("Choose from Library") {
                    showPhotoLibrary = true
                }
                if onRemovePhoto != nil {
                    Button("Remove Photo", role: .destructive) {
                        onRemovePhoto?()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
            .sheet(isPresented: $showPhotoLibrary) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
            .onChange(of: showPicker) { newValue in
                if newValue {
                    showActionSheet = true
                    showPicker = false
                }
            }
    }
}
