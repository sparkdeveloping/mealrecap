import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

struct PhotoLogSheet: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var previewData: Data?
    @State private var isWorking = false
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var showCameraDeniedAlert = false
    @State private var photoLoadError: String?
    @State private var pendingMeal: PendingPhotoMeal?
    @State private var selectedPortion: Double = 1
    @State private var isAdding = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let horizontalPadding: CGFloat = 22
            let contentWidth = max(0, width - horizontalPadding * 2)

            ZStack {
                AmbientBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Capsule()
                            .fill(MRColor.line)
                            .frame(width: 42, height: 5)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)

                        header

                        if let pendingMeal, let previewImage {
                            reviewCard(pending: pendingMeal, image: previewImage)
                        } else if let previewImage, let previewData {
                            previewCard(image: previewImage, data: previewData)
                        } else {
                            sourcePickerCard
                        }

                        if let photoLoadError {
                            Text(photoLoadError)
                                .font(.mrSmall)
                                .foregroundStyle(MRColor.danger)
                                .padding(.horizontal, 4)
                                .accessibilityLabel(photoLoadError)
                        }

                        Spacer(minLength: max(24, proxy.safeAreaInsets.bottom + 16))
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .frame(width: width)
                    .padding(.bottom, 12)
                }
                .frame(width: width)
                .ignoresSafeArea(.container, edges: [.top, .bottom])
                .contentMargins(.top, 0, for: .scrollContent)
                .contentMargins(.bottom, 0, for: .scrollContent)
            }
            .frame(width: width, height: proxy.size.height)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .photosPicker(isPresented: $showLibraryPicker, selection: $selectedPhoto, matching: .images)
        .sheet(isPresented: $showCamera) {
            CameraPicker { data in
                setPreview(data)
            }
            .ignoresSafeArea()
        }
        .alert("Camera access is needed to take a meal photo.", isPresented: $showCameraDeniedAlert) {
            Button("Choose Library") { showLibraryPicker = true }
            Button("Open Settings") { openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can still choose a photo from your library.")
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task { await loadPhoto(newValue) }
        }
        .interactiveDismissDisabled(isWorking)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headerTitle)
                .font(.mrTitle)
                .foregroundStyle(MRColor.text)
            Text(headerSubtitle)
                .font(.mrBody)
                .foregroundStyle(MRColor.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var headerTitle: String {
        if pendingMeal != nil { return "Review meal" }
        return previewImage == nil ? "Add a meal photo" : "Use this photo?"
    }

    private var headerSubtitle: String {
        if pendingMeal != nil { return "Adjust the portion, inspect ingredients, then add it to today." }
        return previewImage == nil
            ? "Take a fresh photo or choose one from your library. MealRecap estimates portions, calories, and macros."
            : "MealRecap will estimate calories, macros, ingredients, and details from this image."
    }

    private var sourcePickerCard: some View {
        VStack(spacing: 12) {
            sourceButton(title: "Take Photo", subtitle: "Use the camera", systemImage: "camera.fill") {
                requestCamera()
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                PhotoSourceButtonLabel(title: "Choose from Library", subtitle: "Pick an existing meal photo", systemImage: "photo.on.rectangle.angled")
            }
            .buttonStyle(PressablePolish())
            .disabled(isWorking)
            .accessibilityLabel("Choose from photo library")
        }
        .padding(14)
        .glassRounded(cornerRadius: 30, tint: MRColor.backgroundTop.opacity(0.10), strokeOpacity: 0.56, shadowOpacity: 0.08)
    }

    private func sourceButton(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PhotoSourceButtonLabel(title: title, subtitle: subtitle, systemImage: systemImage)
        }
        .buttonStyle(PressablePolish())
        .disabled(isWorking)
        .accessibilityLabel(title)
    }

    private func previewCard(image: UIImage, data: Data) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white.opacity(0.58), lineWidth: 1))
                .clipped()
                .accessibilityLabel("Selected meal photo preview")

            if isWorking {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(MRColor.accentDeep)
                    Text("Analyzing meal...")
                        .font(.mrBody.weight(.semibold))
                        .foregroundStyle(MRColor.secondaryText)
                    Spacer()
                }
                .padding(16)
                .glassRounded(cornerRadius: 22, tint: MRColor.accentSoft.opacity(0.18), strokeOpacity: 0.36, shadowOpacity: 0.02)
            }

            Button {
                Task { await analyze(data) }
            } label: {
                Label("Analyze meal", systemImage: "sparkles")
                    .font(.mrBody.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .glassCapsule(tint: MRColor.accentDeep.opacity(isWorking ? 0.28 : 0.62), strokeOpacity: 0.42, shadowOpacity: 0.08)
                    .contentShape(Capsule())
            }
            .buttonStyle(PressablePolish())
            .disabled(isWorking)
            .accessibilityLabel("Analyze meal photo")

            HStack(spacing: 10) {
                Button {
                    clearPreview()
                } label: {
                    Text("Choose another")
                        .font(.mrSmall.weight(.bold))
                        .foregroundStyle(MRColor.text)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .glassCapsule(tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.36, shadowOpacity: 0.02)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressablePolish())
                .disabled(isWorking)
                .accessibilityLabel("Retake or choose another photo")

                Button(role: .cancel) {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.mrSmall.weight(.bold))
                        .foregroundStyle(MRColor.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .glassCapsule(tint: MRColor.backgroundTop.opacity(0.06), strokeOpacity: 0.30, shadowOpacity: 0.01)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressablePolish())
                .disabled(isWorking)
                .accessibilityLabel("Cancel photo logging")
            }
        }
        .padding(14)
        .glassRounded(cornerRadius: 34, tint: MRColor.backgroundTop.opacity(0.10), strokeOpacity: 0.58, shadowOpacity: 0.10)
    }

    private func reviewCard(pending: PendingPhotoMeal, image: UIImage) -> some View {
        let result = pending.result.scaled(by: selectedPortion)
        let ingredients = displayItems(result.items)

        return VStack(alignment: .leading, spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white.opacity(0.58), lineWidth: 1))
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text(result.title)
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .foregroundStyle(MRColor.text)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                Text(reviewSubtitle(result))
                    .font(.mrSmall.weight(.semibold))
                    .foregroundStyle(MRColor.secondaryText)
                    .lineLimit(2)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(result.totalCalories)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(MRColor.text)
                Text("cal")
                    .font(.mrBody.weight(.bold))
                    .foregroundStyle(MRColor.secondaryText)
                Spacer(minLength: 8)
            }

            HStack(spacing: 9) {
                MacroChip(label: "P", value: result.macros.protein)
                MacroChip(label: "C", value: result.macros.carbs)
                MacroChip(label: "F", value: result.macros.fat)
            }

            portionSelector

            if !ingredients.isEmpty {
                ingredientsCard(ingredients)
            }

            if let details = result.nutritionDetails, details.hasAdvancedNutrients {
                PhotoNutritionDetailsCard(details: details)
            }

            Button {
                Task { await addPendingMeal(pending) }
            } label: {
                HStack {
                    if isAdding { ProgressView().tint(.white) }
                    Text(isAdding ? "Adding..." : "Add to today")
                }
                .font(.mrBody.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .glassCapsule(tint: MRColor.accentDeep.opacity(isAdding ? 0.30 : 0.62), strokeOpacity: 0.42, shadowOpacity: 0.08)
                .contentShape(Capsule())
            }
            .buttonStyle(PressablePolish())
            .disabled(isAdding)
            .accessibilityLabel("Add reviewed meal to today")

            HStack(spacing: 10) {
                secondaryReviewButton("Edit photo") { clearReview() }
                secondaryReviewButton("Cancel") { dismiss() }
            }
        }
        .padding(14)
        .glassRounded(cornerRadius: 34, tint: MRColor.backgroundTop.opacity(0.10), strokeOpacity: 0.58, shadowOpacity: 0.10)
    }

    private var portionSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How much did you eat?")
                .font(.mrHeadline)
                .foregroundStyle(MRColor.text)
            HStack(spacing: 8) {
                portionButton(title: "1/4", value: 0.25)
                portionButton(title: "1/2", value: 0.5)
                portionButton(title: "3/4", value: 0.75)
                portionButton(title: "All", value: 1)
            }
        }
        .padding(14)
        .glassRounded(cornerRadius: 24, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.36, shadowOpacity: 0.02)
    }

    private func portionButton(title: String, value: Double) -> some View {
        Button {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) { selectedPortion = value }
        } label: {
            Text(title)
                .font(.mrSmall.weight(.bold))
                .foregroundStyle(selectedPortion == value ? .white : MRColor.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selectedPortion == value ? MRColor.accentDeep : MRColor.card.opacity(0.46))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.48), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(PressablePolish())
        .accessibilityLabel("\(title) portion")
    }

    private func ingredientsCard(_ items: [FoodItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingredients")
                .font(.mrHeadline)
                .foregroundStyle(MRColor.text)
            ForEach(items) { item in
                PhotoIngredientRow(item: item)
                if item.id != items.last?.id {
                    Divider().background(MRColor.line.opacity(0.35))
                }
            }
        }
        .padding(16)
        .glassRounded(cornerRadius: 24, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.36, shadowOpacity: 0.02)
    }

    private func secondaryReviewButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.mrSmall.weight(.bold))
                .foregroundStyle(MRColor.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 46)
                .glassCapsule(tint: MRColor.backgroundTop.opacity(0.06), strokeOpacity: 0.30, shadowOpacity: 0.01)
                .contentShape(Capsule())
        }
        .buttonStyle(PressablePolish())
        .disabled(isAdding)
    }

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem) async {
        photoLoadError = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                photoLoadError = "MealRecap could not load that photo. Try another image."
                return
            }
            setPreview(data)
        } catch {
            photoLoadError = "MealRecap could not load that photo. Try another image."
        }
    }

    @MainActor
    private func setPreview(_ data: Data) {
        guard let image = UIImage(data: data) else {
            photoLoadError = "MealRecap could not read that image. Try another photo."
            return
        }
        previewData = data
        previewImage = image
        photoLoadError = nil
    }

    @MainActor
    private func clearPreview() {
        selectedPhoto = nil
        previewData = nil
        previewImage = nil
        photoLoadError = nil
        pendingMeal = nil
        selectedPortion = 1
    }

    @MainActor
    private func clearReview() {
        pendingMeal = nil
        selectedPortion = 1
    }

    private func requestCamera() {
        photoLoadError = nil
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            photoLoadError = "Camera is unavailable on this device. You can still choose a photo from your library."
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        showCamera = true
                    } else {
                        showCameraDeniedAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraDeniedAlert = true
        @unknown default:
            showCameraDeniedAlert = true
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func analyze(_ data: Data) async {
        isWorking = true
        defer { isWorking = false }
        guard let pending = await app.analyzePhotoForReview(data) else { return }
        await MainActor.run {
            pendingMeal = pending
            selectedPortion = 1
        }
    }

    private func addPendingMeal(_ pending: PendingPhotoMeal) async {
        isAdding = true
        let didAdd = await app.addReviewedPhotoMeal(pending, portionFactor: selectedPortion)
        await MainActor.run {
            isAdding = false
            if didAdd { dismiss() }
        }
    }

    private func displayItems(_ items: [FoodItem]) -> [FoodItem] {
        let filtered = items.filter { $0.hasDisplayableIngredientName }
        if filtered.isEmpty, items.count == 1, items.first?.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "food item" {
            return items
        }
        return filtered
    }

    private func reviewSubtitle(_ result: MealAnalysisResult) -> String {
        let category = result.foodCategory?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let category, !category.isEmpty { return "\(category) · \(result.mealType.title)" }
        return result.mealType.title
    }
}

private struct PhotoSourceButtonLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MRColor.accentDeep)
                .frame(width: 44, height: 44)
                .glassCircle(tint: MRColor.accentSoft.opacity(0.32), strokeOpacity: 0.42, shadowOpacity: 0.02)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.mrBody.weight(.bold))
                    .foregroundStyle(MRColor.text)
                Text(subtitle)
                    .font(.mrSmall)
                    .foregroundStyle(MRColor.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MRColor.tertiaryText)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .glassRounded(cornerRadius: 22, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.36, shadowOpacity: 0.02)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct PhotoIngredientRow: View {
    let item: FoodItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.mrBody.weight(.semibold))
                    .foregroundStyle(MRColor.text)
                    .lineLimit(2)
                if let serving = item.servingDescription, !serving.isEmpty {
                    Text(serving)
                        .font(.mrSmall)
                        .foregroundStyle(MRColor.secondaryText)
                        .lineLimit(2)
                }
                if let macroText = item.macroSummaryText {
                    Text(macroText)
                        .font(.mrMicro)
                        .tracking(1.1)
                        .foregroundStyle(MRColor.tertiaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(item.calories) cal")
                .font(.mrSmall.weight(.bold))
                .foregroundStyle(MRColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(minWidth: 62, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }
}

private struct PhotoNutritionDetailsCard: View {
    let details: NutritionDetails

    private var rows: [(String, String)] {
        NutritionDisplay.rows(for: details)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("More nutrition")
                .font(.mrHeadline)
                .foregroundStyle(MRColor.text)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(rows, id: \.0) { row in
                    HStack {
                        Text(row.0)
                            .font(.mrSmall)
                            .foregroundStyle(MRColor.secondaryText)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(row.1)
                            .font(.mrSmall.weight(.bold))
                            .foregroundStyle(MRColor.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 38)
                    .background(.white.opacity(0.26), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(16)
        .glassRounded(cornerRadius: 24, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.36, shadowOpacity: 0.02)
    }
}
