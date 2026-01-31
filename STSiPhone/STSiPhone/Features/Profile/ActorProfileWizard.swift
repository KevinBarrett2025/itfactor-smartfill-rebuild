import SwiftUI
import UIKit
import PhotosUI

struct ActorProfileWizard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var profileManager: ActorProfileManager
    @State private var repsVM: RepsViewModel
    @State private var currentStep: Int
    private let totalSteps = 5
    
    // Basic Info
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var sagStatus: SAGStatus
    @State private var sagNumber: String
    @State private var ageRangeMin: Int
    @State private var ageRangeMax: Int
    @State private var sex: ActorSex
    @State private var primaryLocation: String
    @State private var localHireMarket: String
    
    // Appearance/Stats
    @State private var heightFeet: Int
    @State private var heightInches: Int
    @State private var weight: String
    @State private var hairColor: String
    @State private var eyeColor: String
    @State private var shirtSize: String
    @State private var pantSize: String
    @State private var shoeSize: String
    
    // Detailed Measurements
    @State private var waist: String
    @State private var inseam: String
    @State private var glove: String
    @State private var hat: String
    
    @State private var chest: String
    @State private var neck: String
    @State private var sleeve: String
    @State private var coat: String
    @State private var mensTShirt: String
    @State private var mensShoe: String
    @State private var mensShoeWidth: String
    
    @State private var dress: String
    @State private var bust: String
    @State private var underbust: String
    @State private var cup: String
    @State private var hip: String
    @State private var womensTShirt: String
    @State private var womensPants: String
    @State private var womensShoe: String
    @State private var womensShoeWidth: String
    
    @State private var boysSize: String
    @State private var girlsSize: String
    @State private var toddlersSize: String
    @State private var infantsSize: String
    @State private var kidsShoe: String
    @State private var kidsSpecial: String
    
    // Uploads
    @State private var headshots: [String]
    @State private var sizeCards: [String]
    @State private var resumes: [String]
    @State private var sizeCardConfig: SizeCardConfig
    
    // Social
    @State private var instagramHandle: String
    @State private var facebookHandle: String
    @State private var tiktokHandle: String
    @State private var imdbPath: String
    @State private var showAdvancedMeasurements = false
    
    // File import state
    @State private var showFileImporter = false
    @State private var currentUploadType: UploadType = .headshot
    @State private var showingSizeCardDesigner = false
    @State private var isAddingAlternateLook = false
    @State private var showingHeadshotSource = false
    @State private var headshotDeleteCandidate: HeadshotAsset?
    @State private var showingHeadshotPhotoPicker = false
    @State private var showingHeadshotFileImporter = false
    @State private var headshotPhotoItem: PhotosPickerItem?
    @State private var isImportingHeadshot = false
    @State private var showingHeadshotOverlay = false
    
    // Rep management
    @State private var showingRepForm = false
    @State private var selectedRepCategory = "Film/TV Agent"
    
    let onComplete: () -> Void
    
    private var theme: STSTheme { themeManager.current }
    private let themeOptions: [(id: STSThemeID, title: String, subtitle: String)] = [
        (.studioLobbyV1, "Cinematic Studio", "Teal / Navy"),
        (.studioLobbyNeon, "Pop Culture", "Magenta Glow"),
        (.takeReviewClassic, "Classic Paper", "Monochrome")
    ]
    
    private var accentGlow: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                theme.primaryAccent.opacity(theme.id == .studioLobbyV1 ? 0.18 : 0.24),
                Color.clear
            ]),
            center: .center,
            startRadius: 0,
            endRadius: 480
        )
        .blendMode(.screen)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    init(
        startingProfile: ActorProfile? = nil,
        profileManager: ActorProfileManager = ActorProfileManager(),
        repsViewModel: RepsViewModel = RepsViewModel(),
        onComplete: @escaping () -> Void
    ) {
        self.onComplete = onComplete
        _profileManager = State(initialValue: profileManager)
        _repsVM = State(initialValue: repsViewModel)
        _currentStep = State(initialValue: 1)
        
        let resolvedProfile = startingProfile ?? profileManager.profile
        
        _name = State(initialValue: resolvedProfile.name)
        _email = State(initialValue: resolvedProfile.email)
        _phone = State(initialValue: resolvedProfile.phone)
        _sagStatus = State(initialValue: resolvedProfile.sagStatus)
        _sagNumber = State(initialValue: resolvedProfile.sagNumber)
        let parsedRange = ActorProfileWizard.ageBounds(from: resolvedProfile.ageRange)
        _ageRangeMin = State(initialValue: parsedRange.min)
        _ageRangeMax = State(initialValue: parsedRange.max)
        _sex = State(initialValue: resolvedProfile.sex)
        _primaryLocation = State(initialValue: resolvedProfile.primaryLocation)
        _localHireMarket = State(initialValue: resolvedProfile.localHireMarket)
        
        let heightComponents = ActorProfileWizard.heightComponents(from: resolvedProfile.height)
        _heightFeet = State(initialValue: heightComponents.feet)
        _heightInches = State(initialValue: heightComponents.inches)
        _weight = State(initialValue: resolvedProfile.weight)
        _hairColor = State(initialValue: resolvedProfile.hairColor)
        _eyeColor = State(initialValue: resolvedProfile.eyeColor)
        _shirtSize = State(initialValue: resolvedProfile.shirtSize)
        _pantSize = State(initialValue: resolvedProfile.pantSize)
        _shoeSize = State(initialValue: resolvedProfile.shoeSize)
        
        let measurements = resolvedProfile.measurements
        _waist = State(initialValue: measurements.waist)
        _inseam = State(initialValue: measurements.inseam)
        _glove = State(initialValue: measurements.glove)
        _hat = State(initialValue: measurements.hat)
        _chest = State(initialValue: measurements.chest)
        _neck = State(initialValue: measurements.neck)
        _sleeve = State(initialValue: measurements.sleeve)
        _coat = State(initialValue: measurements.coat)
        _mensTShirt = State(initialValue: measurements.mensTShirt)
        _mensShoe = State(initialValue: measurements.mensShoe)
        _mensShoeWidth = State(initialValue: measurements.mensShoeWidth)
        _dress = State(initialValue: measurements.dress)
        _bust = State(initialValue: measurements.bust)
        _underbust = State(initialValue: measurements.underbust)
        _cup = State(initialValue: measurements.cup)
        _hip = State(initialValue: measurements.hip)
        _womensTShirt = State(initialValue: measurements.womensTShirt)
        _womensPants = State(initialValue: measurements.womensPants)
        _womensShoe = State(initialValue: measurements.womensShoe)
        _womensShoeWidth = State(initialValue: measurements.womensShoeWidth)
        _boysSize = State(initialValue: measurements.boys)
        _girlsSize = State(initialValue: measurements.girls)
        _toddlersSize = State(initialValue: measurements.toddlers)
        _infantsSize = State(initialValue: measurements.infants)
        _kidsShoe = State(initialValue: measurements.kidsShoe)
        _kidsSpecial = State(initialValue: measurements.kidsSpecial)
        
        let socials = resolvedProfile.socialLinks
        _instagramHandle = State(initialValue: ActorProfileWizard.extractHandle(socials.instagram, removingPrefix: "@"))
        _facebookHandle = State(initialValue: ActorProfileWizard.extractHandle(socials.facebook, removingPrefix: "facebook.com/"))
        _tiktokHandle = State(initialValue: ActorProfileWizard.extractHandle(socials.tiktok, removingPrefix: "@"))
        _imdbPath = State(initialValue: ActorProfileWizard.extractIMDbPath(socials.imdb))
        
        _headshots = State(initialValue: resolvedProfile.headshots.map { $0.fileName })
        _sizeCards = State(initialValue: resolvedProfile.sizeCards)
        _resumes = State(initialValue: resolvedProfile.resumes)
        _sizeCardConfig = State(initialValue: resolvedProfile.sizeCardConfig)
    }
    
    enum UploadType {
        case headshot
        case sizeCard
        case resume
    }

    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient
                    .ignoresSafeArea()
                accentGlow
                
                VStack(spacing: 0) {
                    heroHeader
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    
                    TabView(selection: $currentStep) {
                        ForEach(1...totalSteps, id: \.self) { step in
                            ScrollView {
                                VStack(spacing: 20) {
                                    stepContent(for: step)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 32)
                            }
                            .scrollDismissesKeyboard(.interactively)
                            .tag(step)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    navigationButton
                }
            }
            .navigationBarHidden(true)
            .overlay(alignment: .center) {
                headshotOverlayLayer
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: {
                switch currentUploadType {
                case .headshot:
                    return [.jpeg, .png]
                case .sizeCard:
                    return [.pdf, .jpeg, .png]
                case .resume:
                    return [.pdf]
                }
            }(),
            allowsMultipleSelection: currentUploadType == .headshot || currentUploadType == .resume
        ) { result in
            handleFileImport(result: result)
        }
        .photosPicker(isPresented: $showingHeadshotPhotoPicker, selection: $headshotPhotoItem, matching: .images)
        .onChange(of: headshotPhotoItem, initial: false) { _, item in
            Task { await handleHeadshotPhotoSelection(item: item) }
        }
        .fileImporter(isPresented: $showingHeadshotFileImporter, allowedContentTypes: [.jpeg, .png], allowsMultipleSelection: true) { result in
            handleHeadshotFileImport(result: result)
        }
        .confirmationDialog("Add Headshot", isPresented: $showingHeadshotSource, titleVisibility: .visible) {
            Button("Choose from Photos") {
                showingHeadshotPhotoPicker = true
            }
            .disabled(isImportingHeadshot)
            Button("Choose from Files") {
                showingHeadshotFileImporter = true
            }
            .disabled(isImportingHeadshot)
            Button("Cancel", role: .cancel) { showingHeadshotSource = false }
        }
        .sheet(isPresented: $showingRepForm) {
            // Use a simple form for adding reps within the wizard
            WizardRepForm(category: selectedRepCategory, repsVM: repsVM)
        }
        .sheet(isPresented: $showingSizeCardDesigner) {
            LayoutDesignerView(
                profile: composedProfile(previewOnly: true),
                reps: repsVM.reps,
                config: $sizeCardConfig
            ) {
                showingSizeCardDesigner = false
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                KeyboardDonePill {
                    hideKeyboard()
                }
            }
        }
        .onChange(of: showFileImporter, initial: false) { _, newValue in
            print("📄 showFileImporter changed -> \(newValue) (uploadType=\(currentUploadType))")
        }
        .onChange(of: ageRangeMin, initial: false) { _, newValue in
            if newValue > ageRangeMax {
                ageRangeMax = newValue
            }
        }
        .onChange(of: ageRangeMax, initial: false) { _, newValue in
            if newValue < ageRangeMin {
                ageRangeMin = newValue
            }
        }
        .onDisappear {
            saveProfile()
        }
        .stsPortraitOnly(label: "ActorProfileWizard")
    }
    
    // ... rest of the implementation stays the same until the rep management section ...
    
    // MARK: - Step 4: Representation (simplified)
private var representationStep: some View {
    VStack(spacing: 16) {
        // Add Rep Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Add Your Representation")
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("You can add your representation now or skip and add them later in Settings")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Text("Add New Rep")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.textPrimary)
                    
                    Spacer()
                    
                    Menu {
                        ForEach(RepsViewModel.categories, id: \.self) { category in
                            Button(category) {
                                selectedRepCategory = category
                                showingRepForm = true
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Theme.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.systemIndigo).opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 4)
            }
            
            // Existing Reps
            if !repsVM.reps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Team")
                        .font(Theme.Font.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(repsVM.reps) { rep in
                        BrandedRowCard(
                            title: rep.name,
                            subtitle: rep.category,
                            roles: [
                                rep.companyName,
                                rep.companyAddress,
                                rep.email,
                                rep.phone
                            ]
                            .compactMap { $0 }
                            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            .joined(separator: " • "),
                            isInteractive: false
                        )
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.badge.gearshape")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Text("No representation added yet")
                        .font(Theme.Font.body)
                        .foregroundStyle(.gray)
                    
                    Text("You can skip this step and add representation later")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)
            }
        }
    }
    
    // MARK: - Step 5: Social Links
    private var socialLinksStep: some View {
        VStack(spacing: 16) {
            Text("Share the public profiles you'd like casting to see. Handles or vanity URLs stay consistent across ActorKit.")
                .font(Theme.Font.body)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.leading)
            
            SocialHandleRow(
                title: "Instagram",
                prefix: "@",
                placeholder: "username",
                value: $instagramHandle,
                keyboardType: .twitter
            )
            
            SocialHandleRow(
                title: "Facebook",
                prefix: "facebook.com/",
                placeholder: "yourpage",
                value: $facebookHandle,
                keyboardType: .webSearch
            )
            
            SocialHandleRow(
                title: "TikTok",
                prefix: "@",
                placeholder: "username",
                value: $tiktokHandle,
                keyboardType: .twitter
            )
            
            SocialHandleRow(
                title: "IMDb",
                prefix: "www.imdb.com/",
                placeholder: "name/nm1234567",
                value: $imdbPath,
                keyboardType: .webSearch
            )
        }
    }
    
    // ... all other methods stay the same ...
    
    // Add all the missing methods from the previous implementation
    private var heroHeader: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.primary.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 18)
                    .opacity(0.4)
                
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 8)
                    .overlay(
                        ZStack {
                            if let headshot = headshotPreviewImage {
                                headshot
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 118, height: 118)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 118, height: 118)
                                    .overlay(
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 46, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.7))
                                    )
                            }
                        }
                    )
            }
            .frame(height: 140)
            
            VStack(spacing: 6) {
                Text("Setup your iTFactor Profile")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text("We’ll use this profile everywhere—ActorKit, Size Card Creator, and sessions.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            
            wizardProgressBar
        }
    }
    
    private var wizardProgressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text(stepTitle(for: currentStep))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("\(currentStep)/\(totalSteps)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            GeometryReader { proxy in
                let width = proxy.size.width * CGFloat(progressFraction)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.primary, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(18, width))
                }
            }
            .frame(height: 8)
        }
        .padding(.top, 10)
    }
    
    private var progressFraction: Double {
        Double(currentStep) / Double(totalSteps)
    }
    
    private func stepTitle(for step: Int) -> String {
        switch step {
        case 1: return "Stage Identity"
        case 2: return "Signature Look"
        case 3: return "Representation & Links"
        case 4: return "Toolkit & Assets"
        default: return "Profile"
        }
    }
    
    private var headshotPreviewImage: Image? {
        guard let first = headshots.first,
              let url = resolveHeadshotURL(named: first),
              let uiImage = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    
    private var spinnerHeadshotUIImage: UIImage? {
        guard let preferred = profileManager.profile.preferredHeadshot,
              let url = resolveHeadshotURL(named: preferred.fileName),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        return image
    }

    private func resolveHeadshotURL(named fileName: String) -> URL? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let actorProfileDir = docs.appendingPathComponent("ActorProfile", isDirectory: true)
        let candidate1 = actorProfileDir.appendingPathComponent(fileName)
        if fm.fileExists(atPath: candidate1.path) { return candidate1 }
        let candidate2 = docs.appendingPathComponent(fileName)
        if fm.fileExists(atPath: candidate2.path) { return candidate2 }
        return nil
    }
    
    private func sizeSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.Font.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var shouldShowMenSizes: Bool {
        sex == .male || sex == .undisclosed
    }
    
    private var shouldShowWomenSizes: Bool {
        sex == .female || sex == .undisclosed
    }
    
    private var shouldShowChildSizes: Bool {
        inferredYouthTalent
    }
    
    private var inferredYouthTalent: Bool {
        return ageRangeMax < 18
    }
    
    @ViewBuilder
    private func stepContent(for step: Int) -> some View {
        switch step {
        case 1:
            identityStep
        case 2:
            identityDetailsStep
        case 3:
            lookStep
        case 4:
            representationAndLinksStep
        case 5:
            toolkitStep
        default:
            EmptyView()
        }
    }
    
    // MARK: - Card Shell
    private struct WizardCard<Content: View>: View {
        let title: String
        let subtitle: String?
        let content: Content
        
        init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
            self.title = title
            self.subtitle = subtitle
            self.content = content()
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Theme.Font.headline)
                        .foregroundStyle(.white)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
        }
    }

    private struct ThemePreviewCard: View {
        let theme: STSTheme
        let title: String
        let subtitle: String
        let isSelected: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.backgroundGradient)
                    .frame(width: 160, height: 90)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(isSelected ? 0.8 : 0.2), lineWidth: isSelected ? 2 : 1)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(12)
            .frame(width: 180, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.12 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.4 : 0.12), lineWidth: 1)
            )
        }
    }
    
    private struct AgeRangePickerRow: View {
        @Binding var minAge: Int
        @Binding var maxAge: Int
        var range: ClosedRange<Int> = 5...90
        
        private var ageValues: [Int] { Array(range) }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Age Range")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("What ages do you regularly play on camera?")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                
                HStack(spacing: 12) {
                    pickerColumn(title: "Min", selection: $minAge)
                    
                    Divider()
                        .frame(height: 120)
                        .overlay(Color.white.opacity(0.2))
                    
                    pickerColumn(title: "Max", selection: $maxAge)
                }
                .frame(height: 150)
        }
        .padding()
        .background(
            SafeRoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemIndigo).opacity(0.2))
                    .overlay(
                        SafeRoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        .simultaneousGesture(TapGesture().onEnded {
            hideKeyboard()
        })
    }
        
        private func pickerColumn(title: String, selection: Binding<Int>) -> some View {
            VStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                
                Picker(title, selection: selection) {
                    ForEach(ageValues, id: \.self) { age in
                        Text("\(age)")
                            .tag(age)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
                .labelsHidden()
            }
        }
    }
    
    private struct HeightPickerRow: View {
        @Binding var feet: Int
        @Binding var inches: Int
        private let feetRange = Array(3...8)
        private let inchRange = Array(0...11)
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Height")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("Dial in your on-camera height. Feet max out at 8' for realism.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                
                HStack(spacing: 12) {
                    pickerColumn(title: "Feet", values: feetRange, selection: $feet, unit: "ft")
                    
                    Divider()
                        .frame(height: 120)
                        .overlay(Color.white.opacity(0.2))
                    
                    pickerColumn(title: "Inches", values: inchRange, selection: $inches, unit: "in")
                }
                .frame(height: 150)
            }
            .padding()
            .background(
                SafeRoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemIndigo).opacity(0.2))
                    .overlay(
                        SafeRoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            .simultaneousGesture(TapGesture().onEnded {
                hideKeyboard()
            })
        }
        
        private func pickerColumn(title: String, values: [Int], selection: Binding<Int>, unit: String) -> some View {
            VStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                
                Picker(title, selection: selection) {
                    ForEach(values, id: \.self) { value in
                        Text("\(value) \(unit)")
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
                .labelsHidden()
            }
        }
    }
    
    private struct SocialHandleRow: View {
        let title: String
        let prefix: String
        let placeholder: String
        @Binding var value: String
        var keyboardType: UIKeyboardType = .default
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                HStack(spacing: 10) {
                    Text(prefix)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                    
                    TextField(placeholder, text: $value)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundColor(.white)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    SafeRoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemIndigo).opacity(0.2))
                )
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Stage Identity
    private var identityStep: some View {
        VStack(spacing: 20) {
            WizardCard(title: "Stage Identity", subtitle: "Shared across ActorKit, Size Cards, and submissions.") {
                Button {
                    isAddingAlternateLook = false
                    showingHeadshotOverlay = true
                } label: {
                    headshotPreviewTile
                }
                .buttonStyle(.plain)

                WizardInputRow(title: "Full Name", placeholder: "e.g. Sarah Michelle Johnson", text: $name)
                WizardInputRow(title: "Email", placeholder: "your.email@gmail.com", text: $email, keyboardType: .emailAddress, textContentType: .emailAddress)
                WizardInputRow(title: "Phone", placeholder: "(555) 123-4567", text: $phone, keyboardType: .phonePad, textContentType: .telephoneNumber)
                WizardPickerRow(title: "SAG-AFTRA Status", selection: $sagStatus, options: SAGStatus.allCases.map { ($0, $0.displayName) })
                if sagStatus == .member {
                    WizardInputRow(title: "SAG Member Number", placeholder: "Enter your member number (optional)", text: $sagNumber, keyboardType: .numberPad)
                }
            }
            appearanceThemeCard
        }
    }

    private var identityDetailsStep: some View {
        VStack(spacing: 20) {
            identityAndAgeCard
            whereYouWorkCard
        }
    }

    private var identityAndAgeCard: some View {
        WizardCard(title: "Identity & Age Range", subtitle: "How casting should see you on camera.") {
            WizardPickerRow(title: "Identity", selection: $sex, options: ActorSex.allCases.map { ($0, $0.displayName) })
            AgeRangePickerRow(minAge: $ageRangeMin, maxAge: $ageRangeMax)
        }
    }

    private var whereYouWorkCard: some View {
        WizardCard(title: "Where You Work", subtitle: "These details power your slate, ActorKit, and local hire badges.") {
            WizardInputRow(title: "Primary Location", placeholder: "City, State", text: $primaryLocation)
            WizardInputRow(title: "Local Hire Market", placeholder: "Where can you work as a local?", text: $localHireMarket)
        }
    }

    private var appearanceThemeCard: some View {
        WizardCard(title: "Appearance Theme", subtitle: "Choose how your studio looks across the app.") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
            ForEach(themeOptions, id: \.id) { option in
                let optionTheme = STSThemeLibrary.theme(for: option.id)
                let isClassicPaper = option.id == .takeReviewClassic

                Button {
                    guard !isClassicPaper else { return }
                    themeManager.currentID = option.id
                } label: {
                    ThemePreviewCard(
                        theme: optionTheme,
                        title: option.title,
                        subtitle: isClassicPaper ? "Coming soon" : option.subtitle,
                        isSelected: themeManager.currentID == option.id
                    )
                    .overlay {
                        if isClassicPaper {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.35))
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isClassicPaper)
            }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Signature Look
    private var lookStep: some View {
        VStack(spacing: 20) {
            WizardCard(title: "Signature Headshot", subtitle: "Your hero look appears across the studio.") {
                headshotPreviewTile
                HStack(spacing: 12) {
            BrandedSecondaryButton(label: headshots.isEmpty ? "Import Headshot" : "Add more Headshots") {
                isAddingAlternateLook = true
                showingHeadshotOverlay = true
            }
                }
            }
            
            WizardCard(title: "Likeness Details", subtitle: "Top-line stats for casting and size cards.") {
                WizardInputRow(title: "Hair Color", placeholder: "e.g. Brown, Blonde, Black", text: $hairColor)
                WizardInputRow(title: "Eye Color", placeholder: "e.g. Blue, Brown, Green", text: $eyeColor)
                HeightPickerRow(feet: $heightFeet, inches: $heightInches)
                WizardInputRow(title: "Weight", placeholder: "e.g. 140 lbs", text: $weight, keyboardType: .decimalPad)
                WizardInputRow(title: "Waist", placeholder: "20 - 70 inches", text: $waist, keyboardType: .decimalPad)
                WizardInputRow(title: "Inseam", placeholder: "26 - 36 inches", text: $inseam, keyboardType: .decimalPad)
                WizardInputRow(title: "Glove", placeholder: "6 - 12 inches", text: $glove, keyboardType: .decimalPad)
                WizardInputRow(title: "Hat", placeholder: "19 - 25 inches", text: $hat, keyboardType: .decimalPad)
            }
            
            WizardCard(title: "Wardrobe Essentials", subtitle: "Quick-pick sizes casting expects on resumes.") {
                WizardPickerRow(title: "Shirt Size", selection: $shirtSize, options: wardrobeShirtOptions)
                WizardPickerRow(title: "Pant Size", selection: $pantSize, options: wardrobePantOptions)
                WizardPickerRow(title: "Shoe Size", selection: $shoeSize, options: wardrobeShoeOptions)
            }
            
            WizardCard(title: "Detailed Measurements", subtitle: "Optional, but Size Card Creator loves them.") {
                DisclosureGroup(isExpanded: $showAdvancedMeasurements) {
                    if shouldShowMenSizes {
                        sizeSection("Men's Sizes") {
                            WizardInputRow(title: "Chest", placeholder: "24 - 63 inches", text: $chest, keyboardType: .decimalPad)
                            WizardInputRow(title: "Neck", placeholder: "14 - 30 inches", text: $neck, keyboardType: .decimalPad)
                            WizardInputRow(title: "Sleeve", placeholder: "15 - 40 inches", text: $sleeve, keyboardType: .decimalPad)
                            WizardInputRow(title: "Coat", placeholder: "Short - Extra Long", text: $coat)
                            WizardInputRow(title: "T-Shirt", placeholder: "XXS - 10XL", text: $mensTShirt)
                            WizardInputRow(title: "Shoe Size", placeholder: "6 - 17.5", text: $mensShoe, keyboardType: .decimalPad)
                            WizardInputRow(title: "Shoe Width", placeholder: "Normal, Wide, Narrow", text: $mensShoeWidth)
                        }
                    }
                    if shouldShowWomenSizes {
                        sizeSection("Women's Sizes") {
                            WizardInputRow(title: "Dress", placeholder: "00 - 40", text: $dress, keyboardType: .decimalPad)
                            WizardInputRow(title: "Bust", placeholder: "19 - 66 inches", text: $bust, keyboardType: .decimalPad)
                            WizardInputRow(title: "Underbust", placeholder: "19 - 66 inches", text: $underbust, keyboardType: .decimalPad)
                            WizardInputRow(title: "Cup", placeholder: "A - L", text: $cup)
                            WizardInputRow(title: "Hip", placeholder: "15 - 70 inches", text: $hip, keyboardType: .decimalPad)
                            WizardInputRow(title: "T-Shirt", placeholder: "XXS - 8XL", text: $womensTShirt)
                            WizardInputRow(title: "Pants", placeholder: "00 - 40", text: $womensPants, keyboardType: .decimalPad)
                            WizardInputRow(title: "Shoe Size", placeholder: "4 - 17", text: $womensShoe, keyboardType: .decimalPad)
                            WizardInputRow(title: "Shoe Width", placeholder: "Normal, Wide, Narrow", text: $womensShoeWidth)
                        }
                    }
                    if shouldShowChildSizes {
                        sizeSection("Youth Sizes") {
                            WizardInputRow(title: "Boys", placeholder: "4 - 18", text: $boysSize)
                            WizardInputRow(title: "Girls", placeholder: "4 - 18", text: $girlsSize)
                            WizardInputRow(title: "Toddlers", placeholder: "2T - 5T", text: $toddlersSize)
                            WizardInputRow(title: "Infants", placeholder: "0 - 24 months", text: $infantsSize)
                        WizardInputRow(title: "Shoe Size", placeholder: "0 - Youth 5", text: $kidsShoe, keyboardType: .decimalPad)
                            WizardInputRow(title: "Special Sizing", placeholder: "Regular, Husky", text: $kidsSpecial)
                        }
                    }
                } label: {
                    Text(showAdvancedMeasurements ? "Hide Advanced Measurements" : "Show Advanced Measurements")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    // MARK: - Representation & Links
    private var representationAndLinksStep: some View {
        VStack(spacing: 20) {
            WizardCard(title: "Representation", subtitle: "Add or skip—You can always update in ActorKit.") {
                HStack {
                    Text("Add Representation")
                        .font(Theme.Font.body)
                        .foregroundStyle(.white)
                    Spacer()
                    Menu {
                        ForEach(RepsViewModel.categories, id: \.self) { category in
                            Button(category) {
                                selectedRepCategory = category
                                showingRepForm = true
                            }
                        }
                    } label: {
                        Label("New", systemImage: "plus.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(Theme.primary)
                    }
                }
                .padding(.bottom, 6)
                
                if repsVM.reps.isEmpty {
                    Text("No reps added yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    ForEach(repsVM.reps) { rep in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rep.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            if let company = rep.companyName, !company.isEmpty {
                                Text(company)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            if let address = rep.companyAddress, !address.isEmpty {
                                Text(address)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                            if let email = rep.email {
                                Text(email).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                            }
                            if let phone = rep.phone {
                                Text(phone).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
                    }
                }
            }
            
            WizardCard(title: "Showcase Links", subtitle: "Where should casting learn more about you?") {
                SocialHandleRow(
                    title: "Instagram",
                    prefix: "@",
                    placeholder: "username",
                    value: $instagramHandle,
                    keyboardType: .twitter
                )
                SocialHandleRow(
                    title: "Facebook",
                    prefix: "facebook.com/",
                    placeholder: "yourpage",
                    value: $facebookHandle,
                    keyboardType: .webSearch
                )
                SocialHandleRow(
                    title: "TikTok",
                    prefix: "@",
                    placeholder: "username",
                    value: $tiktokHandle,
                    keyboardType: .twitter
                )
                SocialHandleRow(
                    title: "IMDb",
                    prefix: "www.imdb.com/",
                    placeholder: "name/nm1234567",
                    value: $imdbPath,
                    keyboardType: .webSearch
                )
            }
        }
    }
    
    // MARK: - Upload Row Helper
private struct WizardUploadRow: View {
    let title: String
    let description: String
    let files: [String]
    let buttonTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.Font.headline)
                .foregroundStyle(.white)
            Text(description)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
            if files.isEmpty {
                Text("No files yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                ForEach(files, id: \.self) { file in
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(.white.opacity(0.7))
                        Text(file)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
            }
            BrandedSecondaryButton(label: buttonTitle, action: action)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}

// MARK: - Simple Rep Form for Wizard
private struct WizardRepForm: View {
    let category: String
    let repsVM: RepsViewModel
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var companyName: String = ""
    @State private var companyAddress: String = ""
    @AppStorage("STSThemeID") private var storedThemeID: String = STSThemeID.studioLobbyV1.rawValue
    @Environment(\.dismiss) private var dismiss
    
    private var repTheme: STSTheme {
        let id = STSThemeID(rawValue: storedThemeID) ?? .studioLobbyV1
        return STSThemeLibrary.theme(for: id)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                repTheme.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(repTheme.primaryAccent)
                        
                        Text(category)
                            .font(Theme.Font.title)
                            .foregroundStyle(repTheme.textPrimary)
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 16) {
                        WizardInputRow(title: "Name", placeholder: "e.g. Sarah Johnson - CAA", text: $name)
                        WizardInputRow(title: "Email", placeholder: "email@agency.com (optional)", text: $email, keyboardType: .emailAddress, textContentType: .emailAddress)
                        WizardInputRow(title: "Phone", placeholder: "(310) 555-0123 (optional)", text: $phone, keyboardType: .phonePad, textContentType: .telephoneNumber)
                        WizardInputRow(title: "Company Name", placeholder: "Agency / Management Company", text: $companyName)
                        WizardInputRow(title: "Company Address", placeholder: "123 Studio St, Los Angeles, CA", text: $companyAddress)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        BrandedPrimaryButton(
                            label: "Save \(category)",
                            icon: "checkmark.circle.fill"
                        ) {
                            repsVM.addRep(
                                category: category,
                                name: name,
                                email: email,
                                phone: phone,
                                companyName: companyName,
                                companyAddress: companyAddress
                            )
                            dismiss()
                        }
                        .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                        
                        BrandedSecondaryButton(label: "Cancel") {
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
            .navigationBarHidden(true)
        }
    }
}
// MARK: - Toolkit
private var toolkitStep: some View {
    VStack(spacing: 20) {
        WizardCard(
            title: "ActorKit Ready",
            subtitle: "Your all‑in‑one home base for your acting career."
        ) {
            VStack(spacing: 20) {
                SpinnerCoinView(
                    headshot: spinnerHeadshotUIImage,
                    transform: profileManager.profile.profileHeadshotTransform,
                    height: 220,
                    animationDisabled: false,
                    restAngleDegrees: 0,
                    preset: SpinnerCoinPreset.turnstile,
                    tuning: SpinnerCoinTuning.default,
                    yoYoConfig: SpinnerYoYoConfig.disabled
                ) {
                    // No action; this is a celebratory preview of ActorKit.
                }
                .frame(maxWidth: .infinity)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("You did it! You set up your ActorKit.")
                        .font(.system(size: 20, weight: .semibold))
                    
                    Text("From now on, tap the ActorKit coin anytime to open your all‑inclusive hub for your career — headshots, resumes, reps, resources, and everything else that keeps you working.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

    // MARK: - Lookup Helpers
    private var wardrobeShirtOptions: [(String, String)] {
        optionList(for: shirtSize, base: standardShirtSizes, placeholder: "Tap to select")
    }
    
    private var wardrobePantOptions: [(String, String)] {
        optionList(for: pantSize, base: standardPantSizes, placeholder: "Tap to select")
    }
    
    private var wardrobeShoeOptions: [(String, String)] {
        optionList(for: shoeSize, base: standardShoeSizes, placeholder: "Tap to select")
    }
    
    private var standardShirtSizes: [String] {
        ["", "XXS", "XS", "S", "M", "L", "XL", "XXL", "3XL", "4XL", "5XL", "6XL"]
    }
    
    private var standardPantSizes: [String] {
        [""] + ["00", "0"] + stride(from: 2, through: 40, by: 2).map { "\($0)" }
    }
    
    private var standardShoeSizes: [String] {
        var sizes: [String] = [""]
        var value: Double = 4
        while value <= 18 {
            let formatted: String
            if value.truncatingRemainder(dividingBy: 1).isZero {
                formatted = "\(Int(value))"
            } else {
                formatted = String(format: "%.1f", value)
            }
            sizes.append(formatted)
            value += 0.5
        }
        return sizes
    }
    
    private func optionList(for currentValue: String, base: [String], placeholder: String) -> [(String, String)] {
        var values = base
        if !currentValue.isEmpty && !values.contains(currentValue) {
            values.append(currentValue)
        }
        return values.map { value in
            (value, value.isEmpty ? placeholder : value)
        }
    }
    
    private var formattedAgeRange: String {
        "\(ageRangeMin)-\(ageRangeMax)"
    }
    
    private static func ageBounds(from value: String) -> (min: Int, max: Int) {
        let defaultRange = (min: 18, max: 35)
        let numbers = value
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        
        guard let first = numbers.first else {
            return defaultRange
        }
        
        let clampedMin = min(max(first, 5), 90)
        let fallbackMax = min(max(clampedMin + 5, 5), 90)
        let rawMax = numbers.dropFirst().first ?? fallbackMax
        let clampedMax = min(max(rawMax, clampedMin), 90)
        
        return (clampedMin, clampedMax)
    }

    private var navigationButton: some View {
        VStack {
            if currentStep < totalSteps {
                BrandedPrimaryButton(
                    label: nextButtonTitle,
                    icon: nextButtonIcon
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep += 1
                    }
                }
            } else {
                BrandedPrimaryButton(
                    label: "Finish Setup",
                    icon: "checkmark.circle.fill"
                ) {
                    saveProfile()
                    onComplete()
                }
                .opacity(name.isEmpty || email.isEmpty ? 0.6 : 1.0)
            }
        }
        .padding(.bottom, 34)
        .alert("Delete headshot?", isPresented: Binding(get: { headshotDeleteCandidate != nil }, set: { newValue in
            if !newValue { headshotDeleteCandidate = nil }
        })) {
            Button("Cancel", role: .cancel) {
                headshotDeleteCandidate = nil
            }
            Button("Delete", role: .destructive) {
                if let asset = headshotDeleteCandidate {
                    deleteHeadshot(asset)
                }
                headshotDeleteCandidate = nil
            }
        } message: {
            Text("This will remove \(headshotDeleteCandidate?.title ?? "this headshot") from your profile.")
        }
    }

    @ViewBuilder
    private var headshotOverlayLayer: some View {
        if showingHeadshotOverlay {
            ZStack {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            showingHeadshotOverlay = false
                        }
                    }

                HeadshotOverlayPanel(
                    title: "Headshots",
                    assets: profileManager.profile.headshots,
                    preferredID: profileManager.profile.preferredHeadshot?.id,
                    isImporting: isImportingHeadshot,
                    resolveImage: { asset in headshotImage(for: asset) },
                    onSelectPrimary: { asset in
                        profileManager.setPreferredHeadshot(named: asset.fileName)
                        headshots = [asset.fileName] + headshots.filter { $0 != asset.fileName }
                    },
                    onAdd: {
                        isAddingAlternateLook = true
                        showingHeadshotSource = true
                    },
                    onClose: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            showingHeadshotOverlay = false
                        }
                    },
                    onDelete: { asset in
                        headshotDeleteCandidate = asset
                    }
                )
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .zIndex(5)
        }
    }

    private func headshotImage(for asset: HeadshotAsset) -> Image? {
        guard let url = resolveHeadshotURL(named: asset.fileName),
              let uiImage = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    private func deleteHeadshot(_ asset: HeadshotAsset) {
        profileManager.removeHeadshot(id: asset.id)
        profileManager = ActorProfileManager()
        headshots.removeAll(where: { $0 == asset.fileName })
    }
    
    private var nextButtonTitle: String {
        switch currentStep {
        case 1: return "Next: Signature Look"
        case 2: return "Next: Representation"
        case 3: return "Next: Toolkit"
        default: return "Continue"
        }
    }
    
    private var nextButtonIcon: String {
        switch currentStep {
        case 1: return "wand.and.stars"
        case 2: return "person.2.fill"
        case 3: return "shippingbox.fill"
        default: return "chevron.right"
        }
    }
    
    private var headshotPreviewTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.05))
                .frame(maxWidth: .infinity, minHeight: 160)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            HStack(spacing: 14) {
                if let image = headshotPreviewImage {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 120, height: 140)
                        .overlay(
                            Image(systemName: "person.crop.square")
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.7))
                        )
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(headshots.isEmpty ? "Add a hero headshot" : "Primary look ready")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(headshots.isEmpty ? "This photo greets you in ActorKit and Size Cards." : "Tap \"Add more Headshots\" to layer in wardrobe or vibe changes.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
            }
            .padding(16)
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var fileNames: [String] = []
            for url in urls {
                do {
                    let imported = try SafeDocumentStore.importFromPicker(
                        url: url,
                        preferredName: url.lastPathComponent,
                        subfolder: "ActorProfile"
                    )
                    fileNames.append(imported.fileName)
                } catch {
                    print("❌ Failed to import file: \(error)")
                }
            }
            
            guard !fileNames.isEmpty else { return }
            
            switch currentUploadType {
            case .headshot:
                headshots.append(contentsOf: fileNames)
            case .sizeCard:
                if let first = fileNames.first {
                    sizeCards = [first]
                }
            case .resume:
                profileManager.addResumes(fileNames)
                profileManager = ActorProfileManager()
                for name in fileNames where !resumes.contains(name) {
                    resumes.append(name)
                }
            }
        case .failure(let error):
            print("File import failed: \(error)")
        }
    }
    
    private func composedProfile(previewOnly: Bool = false) -> ActorProfile {
        var profile = ActorProfile()
        profile.name = name
        profile.email = email
        profile.phone = phone
        profile.sagStatus = sagStatus
        profile.sagNumber = sagNumber
        profile.ageRange = formattedAgeRange
        profile.sex = sex
        profile.primaryLocation = primaryLocation
        profile.localHireMarket = localHireMarket
        profile.height = formattedHeight
        profile.weight = weight
        profile.hairColor = hairColor
        profile.eyeColor = eyeColor
        profile.shirtSize = shirtSize
        profile.pantSize = pantSize
        profile.shoeSize = shoeSize
        profile.measurements = ActorMeasurements(
            waist: waist,
            inseam: inseam,
            glove: glove,
            hat: hat,
            chest: chest,
            neck: neck,
            sleeve: sleeve,
            coat: coat,
            mensTShirt: mensTShirt,
            mensShoe: mensShoe,
            mensShoeWidth: mensShoeWidth,
            dress: dress,
            bust: bust,
            underbust: underbust,
            cup: cup,
            hip: hip,
            womensTShirt: womensTShirt,
            womensPants: womensPants,
            womensShoe: womensShoe,
            womensShoeWidth: womensShoeWidth,
            boys: boysSize,
            girls: girlsSize,
            toddlers: toddlersSize,
            infants: infantsSize,
            kidsShoe: kidsShoe,
            kidsSpecial: kidsSpecial
        )
        profile.headshots = headshots.enumerated().map { idx, file in
            HeadshotAsset(fileName: file, isProfilePhoto: idx == 0)
        }
        profile.sizeCards = sizeCards
        profile.resumes = resumes
        profile.sizeCardConfig = sizeCardConfig
        profile.socialLinks = SocialLinks(
            instagram: cleanLink(formattedHandle(prefix: "@", handle: instagramHandle)),
            facebook: cleanLink(formattedURL(base: "https://www.facebook.com/", handle: facebookHandle)),
            tiktok: cleanLink(formattedHandle(prefix: "@", handle: tiktokHandle)),
            imdb: cleanLink(formattedURL(base: "https://www.imdb.com/", handle: imdbPath))
        )
        return profile
    }

    private func handleHeadshotFileImport(result: Result<[URL], Error>) {
        Task {
            await MainActor.run { isImportingHeadshot = true }
            defer { Task { @MainActor in isImportingHeadshot = false } }
            switch result {
            case .success(let urls):
                do {
                    let importedFileNames = try urls.map {
                        let importResult = try SafeDocumentStore.importFromPicker(
                            url: $0,
                            preferredName: "Headshot-\($0.lastPathComponent)",
                            subfolder: "ActorProfile"
                        )
                        return importResult.fileName
                    }
                    await MainActor.run {
                        profileManager.addHeadshots(fileNames: importedFileNames)
                        if isAddingAlternateLook {
                            headshots.append(contentsOf: importedFileNames.filter { !headshots.contains($0) })
                        } else if let first = importedFileNames.first {
                            headshots = [first]
                        }
                    }
                } catch {
                    print("Headshot import failed: \(error)")
                }
            case .failure(let error):
                print("Headshot import failed: \(error)")
            }
        }
    }

    private func handleHeadshotPhotoSelection(item: PhotosPickerItem?) async {
        guard let item else { return }
        await MainActor.run { isImportingHeadshot = true }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let utType = item.supportedContentTypes.first else {
                await MainActor.run { isImportingHeadshot = false }
                return
            }
            let ext = utType.preferredFilenameExtension ?? "jpg"
            let fileName = "Headshot-\(UUID().uuidString.prefix(8)).\(ext)"
            let result = try SafeDocumentStore.save(data: data, preferredFileName: fileName, subfolder: "ActorProfile")
            await MainActor.run {
                profileManager.addHeadshot(fileName: result.fileName)
                if isAddingAlternateLook {
                    if !headshots.contains(result.fileName) {
                        headshots.append(result.fileName)
                    }
                } else {
                    headshots = [result.fileName]
                }
                isImportingHeadshot = false
            }
        } catch {
            await MainActor.run { isImportingHeadshot = false }
            print("Headshot photo selection failed: \(error)")
        }
    }
    
    private func saveProfile() {
        let profile = composedProfile()
        profileManager.saveProfile(profile)
        profileManager.markProfileComplete()
    }
    
    private var formattedHeight: String {
        let clampedFeet = min(max(heightFeet, 3), 8)
        let clampedInches = min(max(heightInches, 0), 11)
        return "\(clampedFeet)'\(clampedInches)\""
    }
    
    private func formattedHandle(prefix: String, handle: String) -> String {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let sanitized = trimmed.replacingOccurrences(of: "@", with: "")
        return prefix + sanitized
    }
    
    private func formattedURL(base: String, handle: String) -> String {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.lowercased().hasPrefix("http") {
            return trimmed
        }
        let sanitized = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return base + sanitized
    }
    
    private static func heightComponents(from value: String) -> (feet: Int, inches: Int) {
        let defaultValue = (feet: 5, inches: 6)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultValue }
        let lower = trimmed.lowercased()
        let numbers = lower.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
        
        var feet = defaultValue.feet
        var inches = defaultValue.inches
        
        if lower.contains("cm"), let cmValue = numbers.first {
            let totalInches = Double(cmValue) / 2.54
            let clamped = max(36, min(8 * 12 + 11, Int(round(totalInches))))
            feet = clamped / 12
            inches = clamped % 12
            return (feet, inches)
        }
        
        if lower.contains("'") || lower.contains("ft") {
            if let first = numbers.first {
                feet = clampFeet(first)
            }
            if numbers.count > 1 {
                inches = clampInches(numbers[1])
            } else {
                inches = 0
            }
            return (feet, inches)
        }
        
        if numbers.count >= 2 {
            feet = clampFeet(numbers[0])
            inches = clampInches(numbers[1])
            return (feet, inches)
        }
        
        if let only = numbers.first {
            let clamped = max(36, min(8 * 12 + 11, only))
            feet = clamped / 12
            inches = clamped % 12
        }
        
        return (feet, inches)
    }
    
    private static func clampFeet(_ value: Int) -> Int {
        return min(max(value, 3), 8)
    }
    
    private static func clampInches(_ value: Int) -> Int {
        return min(max(value, 0), 11)
    }
    
    private static func extractHandle(_ value: String, removingPrefix prefix: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if prefix == "@" {
            var handle = trimmed
            if handle.hasPrefix("@") {
                handle.removeFirst()
            }
            if let lastSlash = handle.lastIndex(of: "/") {
                handle = String(handle[handle.index(after: lastSlash)...])
            }
            return handle
        } else {
            var working = trimmed
            working = working.replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
            if working.hasPrefix("www.") {
                working = String(working.dropFirst(4))
            }
            let sanitizedPrefix = prefix
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .lowercased()
            if working.lowercased().hasPrefix(sanitizedPrefix) {
                let index = working.index(working.startIndex, offsetBy: sanitizedPrefix.count)
                return String(working[index...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
            if let lastSlash = working.lastIndex(of: "/") {
                return String(working[working.index(after: lastSlash)...])
            }
            return working
        }
    }
    
    private static func extractIMDbPath(_ value: String) -> String {
        let handle = extractHandle(value, removingPrefix: "imdb.com/")
        return handle
    }
    
    private func cleanLink(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// Reusable headshot picker (matches ActorKit sheet styling)
private struct SubmittedHeadshotPickerSheet: View {
    let headshots: [HeadshotAsset]
    let onSelect: (HeadshotAsset, UIImage?) -> Void
    let onCancel: () -> Void
    var customActions: AnyView? = nil
    
    var body: some View {
        NavigationStack {
            List {
                if let customActions { customActions }
                
                if headshots.isEmpty {
                    Text("No headshots available in Actor Kit.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(headshots) { asset in
                        Button {
                            onSelect(asset, Self.loadThumbnail(for: asset))
                        } label: {
                            HStack(spacing: 12) {
                                if let image = Self.loadThumbnail(for: asset) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 54, height: 54)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 54, height: 54)
                                        .overlay(
                                            Image(systemName: "person.crop.square")
                                                .foregroundColor(.secondary)
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(asset.title)
                                        .foregroundColor(.primary)
                                    if asset.isProfilePhoto {
                                        Text("Profile photo")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Choose Headshot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
    
    private static func loadThumbnail(for asset: HeadshotAsset) -> UIImage? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let actorProfileDir = docs.appendingPathComponent("ActorProfile", isDirectory: true)
        let candidate = actorProfileDir.appendingPathComponent(asset.fileName)
        if fm.fileExists(atPath: candidate.path) {
            return UIImage(contentsOfFile: candidate.path)
        }
        let fallback = docs.appendingPathComponent(asset.fileName)
        if fm.fileExists(atPath: fallback.path) {
            return UIImage(contentsOfFile: fallback.path)
        }
        return nil
    }
}

private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
