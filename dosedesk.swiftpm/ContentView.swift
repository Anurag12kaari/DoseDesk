import SwiftUI
import UserNotifications
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker
        
        init(parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

struct ContentView: View {
    @State private var showAddMedicineSheet = false
    @State private var showEditMedicineSheet = false
    @AppStorage("medicines") private var storedMedicinesData: Data = Data()
    @State private var medicines: [Medicine] = []
    @State private var selectedMedicine: Medicine?
    @State private var medicineToDelete: Medicine?
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                if medicines.isEmpty {
                    Text("No medicines added yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List {
                        ForEach(medicines, id: \.id) { medicine in
                            HStack {
                                if let uiImage = medicine.image {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .padding(.trailing, 8)
                                } else {
                                    Image(systemName: "pills.fill")
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 8)
                                }
                                VStack(alignment: .leading) {
                                    Text(medicine.name)
                                        .font(.headline)
                                    Text("Time: \(medicine.timeString)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .onTapGesture {
                                selectedMedicine = medicine
                                showEditMedicineSheet = true
                            }
                            .onLongPressGesture {
                                medicineToDelete = medicine
                                showDeleteAlert = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Medicine Reminder")
            .toolbar {
                Button(action: {
                    showAddMedicineSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            }
            .sheet(isPresented: $showAddMedicineSheet) {
                AddMedicineView(medicines: $medicines)
            }
            .sheet(item: $selectedMedicine) { medicine in
                EditMedicineView(medicine: medicine, medicines: $medicines)
            }
            .alert("Delete Medicine", isPresented: $showDeleteAlert, presenting: medicineToDelete) { medicine in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteMedicine(medicine)
                }
            } message: { medicine in
                Text("Are you sure you want to delete \"\(medicine.name)\"?")
            }
            .onAppear {
                loadMedicines()
                requestNotificationPermission()
            }
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }

    func loadMedicines() {
        if let decoded = try? JSONDecoder().decode([Medicine].self, from: storedMedicinesData) {
            medicines = decoded
        }
    }

    func deleteMedicine(_ medicine: Medicine) {
        if let index = medicines.firstIndex(where: { $0.id == medicine.id }) {
            medicines.remove(at: index)
            saveMedicines()
        }
    }

    func saveMedicines() {
        if let encoded = try? JSONEncoder().encode(medicines) {
            storedMedicinesData = encoded
        }
    }
}

// MARK: - AddMedicineView
struct AddMedicineView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var medicines: [Medicine]
    
    @State private var medicineName: String = ""
    @State private var selectedTime: Date = Date()
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Medicine Name", text: $medicineName)
                DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Button(action: {
                        showImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo")
                            Text("Upload Image")
                        }
                    }
                    Button(action: {
                        showCamera = true
                    }) {
                        HStack {
                            Image(systemName: "camera")
                            Text("Take Photo")
                        }
                    }
                }
            }
            .navigationTitle("Add Medicine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addMedicine()
                        dismiss()
                    }
                    .disabled(medicineName.isEmpty)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
            }
        }
    }
    
    func addMedicine() {
        let newMedicine = Medicine(name: medicineName, time: selectedTime, image: selectedImage)
        medicines.append(newMedicine)
        saveMedicines()
    }
    
    func saveMedicines() {
        if let encoded = try? JSONEncoder().encode(medicines) {
            UserDefaults.standard.set(encoded, forKey: "medicines")
        }
    }
}

// MARK: - EditMedicineView
struct EditMedicineView: View {
    let medicine: Medicine
    @Binding var medicines: [Medicine]
    @Environment(\.dismiss) var dismiss
    
    @State private var updatedName: String
    @State private var updatedTime: Date
    @State private var updatedImage: UIImage?
    @State private var showImagePicker = false
    
    init(medicine: Medicine, medicines: Binding<[Medicine]>) {
        self.medicine = medicine
        self._medicines = medicines
        self._updatedName = State(initialValue: medicine.name)
        self._updatedTime = State(initialValue: medicine.time)
        self._updatedImage = State(initialValue: medicine.image)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Medicine Name", text: $updatedName)
                DatePicker("Select Time", selection: $updatedTime, displayedComponents: .hourAndMinute)
                if let image = updatedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Button("Upload Image") {
                        showImagePicker = true
                    }
                }
            }
            .navigationTitle("Edit Medicine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateMedicine()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $updatedImage)
            }
        }
    }
    
    func updateMedicine() {
        if let index = medicines.firstIndex(where: { $0.id == medicine.id }) {
            medicines[index].name = updatedName
            medicines[index].time = updatedTime
            medicines[index].imageData = updatedImage?.jpegData(compressionQuality: 0.8)
            saveMedicines()
        }
    }
    
    func saveMedicines() {
        if let encoded = try? JSONEncoder().encode(medicines) {
            UserDefaults.standard.set(encoded, forKey: "medicines")
        }
    }
}

// MARK: - Medicine Model
struct Medicine: Identifiable, Codable {
    let id = UUID()
    var name: String
    var time: Date
    var imageData: Data?
    
    init(name: String, time: Date, image: UIImage?) {
        self.name = name
        self.time = time
        self.imageData = image?.jpegData(compressionQuality: 0.8)
    }
    
    var image: UIImage? {
        guard let imageData = imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
}
#Preview {
    ContentView()
}

