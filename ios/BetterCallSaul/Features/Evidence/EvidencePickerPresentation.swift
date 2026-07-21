struct EvidencePickerPresentation: Equatable {
    private(set) var isPhotoPickerPresented = false
    private(set) var isFileImporterPresented = false

    mutating func presentPhotoPicker() {
        isFileImporterPresented = false
        isPhotoPickerPresented = true
    }

    mutating func presentFileImporter() {
        isPhotoPickerPresented = false
        isFileImporterPresented = true
    }

    mutating func setPhotoPickerPresented(_ isPresented: Bool) {
        isPhotoPickerPresented = isPresented
    }

    mutating func setFileImporterPresented(_ isPresented: Bool) {
        isFileImporterPresented = isPresented
    }
}
