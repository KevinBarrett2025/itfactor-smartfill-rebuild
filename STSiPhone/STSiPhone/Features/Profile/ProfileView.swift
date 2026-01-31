import SwiftUI

struct ProfileView: View {
    @State private var profileManager = ActorProfileManager()
    @State private var isEditMode = false
    @State private var showingWizard = false
    @State private var selectedPhoto: String?
    @State private var showingPhotoViewer = false
    @State private var showingFileViewer = false
    @State private var selectedFileURL: URL?
    
    var body: some View {
        NavigationStack {
            ZStack {
                BrandBackground()
                    .ignoresSafeArea()
                
                if profileManager.isProfileComplete {
                    profileContent
                } else {
                    emptyState
                }
            }
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if profileManager.isProfileComplete {
                        Button(isEditMode ? "Done" : "Edit") {
                            if isEditMode {
                                // Save any changes
                                isEditMode = false
                            } else {
                                showingWizard = true
                            }
                        }
                        .foregroundStyle(Theme.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingWizard) {
            ActorProfileWizard(
                startingProfile: profileManager.profile,
                profileManager: profileManager,
                onComplete: {
                showingWizard = false
                profileManager = ActorProfileManager() // Reload profile
            })
        }
        .sheet(isPresented: $showingPhotoViewer) {
            if let selectedPhoto = selectedPhoto {
                PhotoViewerSheet(imageName: selectedPhoto)
            }
        }
        .sheet(isPresented: $showingFileViewer) {
            if let selectedFileURL = selectedFileURL {
                FileViewerSheet(fileURL: selectedFileURL)
            }
        }
    }
    
    // MARK: - Profile Content
    private var profileContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Profile Header
                profileHeader
                
                // Basic Information
                ProfileSection(title: "Basic Information", icon: "person.circle.fill") {
                    ProfileInfoGroup {
                        ProfileInfoRow(label: "Name", value: profileManager.profile.name)
                        ProfileInfoRow(label: "Email", value: profileManager.profile.email)
                        if !profileManager.profile.phone.isEmpty {
                            ProfileInfoRow(label: "Phone", value: profileManager.profile.phone)
                        }
                        ProfileInfoRow(label: "SAG Status", value: profileManager.profile.sagDisplayStatus)
                        if !profileManager.profile.ageRange.isEmpty {
                            ProfileInfoRow(label: "Age Range", value: profileManager.profile.ageRange)
                        }
                    }
                }
                
                // Physical Attributes
                if hasPhysicalAttributes {
                    ProfileSection(title: "Physical Attributes", icon: "figure.stand") {
                        ProfileInfoGroup {
                            if !profileManager.profile.height.isEmpty {
                                ProfileInfoRow(label: "Height", value: profileManager.profile.height)
                            }
                            if !profileManager.profile.weight.isEmpty {
                                ProfileInfoRow(label: "Weight", value: profileManager.profile.weight)
                            }
                            if !profileManager.profile.hairColor.isEmpty {
                                ProfileInfoRow(label: "Hair Color", value: profileManager.profile.hairColor)
                            }
                            if !profileManager.profile.eyeColor.isEmpty {
                                ProfileInfoRow(label: "Eye Color", value: profileManager.profile.eyeColor)
                            }
                        }
                    }
                }
                
                // Sizes
                if hasSizeInformation {
                    ProfileSection(title: "Sizes", icon: "ruler") {
                        ProfileInfoGroup {
                            if !profileManager.profile.shirtSize.isEmpty {
                                ProfileInfoRow(label: "Shirt", value: profileManager.profile.shirtSize)
                            }
                            if !profileManager.profile.pantSize.isEmpty {
                                ProfileInfoRow(label: "Pants", value: profileManager.profile.pantSize)
                            }
                            if !profileManager.profile.shoeSize.isEmpty {
                                ProfileInfoRow(label: "Shoes", value: profileManager.profile.shoeSize)
                            }
                        }
                    }
                }
                
                // Headshots Gallery
                if !profileManager.profile.headshots.isEmpty {
                    ProfileSection(title: "Headshots", icon: "camera.fill") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                            ForEach(profileManager.profile.headshots) { headshot in
                                HeadshotThumbnail(imageName: headshot.fileName) {
                                    selectedPhoto = headshot.fileName
                                    showingPhotoViewer = true
                                }
                            }
                        }
                    }
                }
                
                // Materials
                if hasUploadedMaterials {
                    ProfileSection(title: "Materials", icon: "doc.fill") {
                        ProfileInfoGroup {
                            ForEach(profileManager.profile.sizeCards, id: \.self) { sizeCard in
                                ProfileFileRow(
                                    filename: sizeCard,
                                    type: "Size Card",
                                    icon: "doc.text.fill"
                                ) {
                                    // Handle file viewing
                                    openFile(named: sizeCard)
                                }
                            }
                            
                            ForEach(profileManager.profile.resumes, id: \.self) { resume in
                                ProfileFileRow(
                                    filename: resume,
                                    type: "Resume",
                                    icon: "doc.text.fill"
                                ) {
                                    // Handle file viewing
                                    openFile(named: resume)
                                }
                            }
                        }
                    }
                }
                
                // Profile Actions
                ProfileSection(title: "Actions", icon: "gearshape.fill") {
                    VStack(spacing: 12) {
                        ProfileActionRow(
                            title: "Export Profile PDF",
                            subtitle: "Generate PDF for casting submissions",
                            icon: "square.and.arrow.up",
                            action: exportProfilePDF
                        )
                        
                        ProfileActionRow(
                            title: "Update Profile",
                            subtitle: "Edit your profile information",
                            icon: "pencil.circle.fill",
                            action: { showingWizard = true }
                        )
                        
                        ProfileActionRow(
                            title: "Reset Profile",
                            subtitle: "Clear all profile data",
                            icon: "trash.circle.fill",
                            isDestructive: true,
                            action: resetProfile
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Photo or Placeholder
            if let firstHeadshot = profileManager.profile.preferredHeadshot,
               let headshotURL = resolveHeadshotURL(named: firstHeadshot.fileName) {
                Button {
                    selectedPhoto = firstHeadshot.fileName
                    showingPhotoViewer = true
                } label: {
                    AsyncImage(url: headshotURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.gray)
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Theme.primary, lineWidth: 3)
                    )
                }
            } else {
                Circle()
                    .fill(Theme.surface)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                    )
            }
            
            // Name and Status
            VStack(spacing: 4) {
                Text(profileManager.profile.displayName)
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.textPrimary)
                
                Text(profileManager.profile.sagDisplayStatus)
                    .font(Theme.Font.body)
                    .foregroundStyle(.secondary)
            }
            
            // Quick Stats
            HStack(spacing: 24) {
                if !profileManager.profile.height.isEmpty {
                    ProfileStatBadge(label: "Height", value: profileManager.profile.height)
                }
                if !profileManager.profile.ageRange.isEmpty {
                    ProfileStatBadge(label: "Age Range", value: profileManager.profile.ageRange)
                }
                if !profileManager.profile.headshots.isEmpty {
                    ProfileStatBadge(label: "Headshots", value: "\(profileManager.profile.headshots.count)")
                }
            }
        }
        .padding(.vertical, 24)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 80))
                .foregroundStyle(Theme.primary)
            
            VStack(spacing: 12) {
                Text("No Profile Found")
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.textPrimary)
                
                Text("Create your actor profile to get started with professional project management.")
                    .font(Theme.Font.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            BrandedPrimaryButton(
                label: "Create Profile",
                icon: "plus.circle.fill"
            ) {
                showingWizard = true
            }
        }
    }
    
    // MARK: - Computed Properties
    private var hasPhysicalAttributes: Bool {
        !profileManager.profile.height.isEmpty ||
        !profileManager.profile.weight.isEmpty ||
        !profileManager.profile.hairColor.isEmpty ||
        !profileManager.profile.eyeColor.isEmpty
    }
    
    private var hasSizeInformation: Bool {
        !profileManager.profile.shirtSize.isEmpty ||
        !profileManager.profile.pantSize.isEmpty ||
        !profileManager.profile.shoeSize.isEmpty
    }
    
    private var hasUploadedMaterials: Bool {
        !profileManager.profile.sizeCards.isEmpty || !profileManager.profile.resumes.isEmpty
    }
    
    // MARK: - Actions
    private func exportProfilePDF() {
        // TODO: Implement PDF export
        print("Exporting profile to PDF...")
    }
    
    private func resetProfile() {
        profileManager.resetProfile()
    }
    
    private func openFile(named filename: String) {
        // TODO: Implement file viewing
        print("Opening file: \(filename)")
    }
}

// MARK: - Supporting Views

struct ProfileSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Theme.primary)
                
                Text(title)
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.textPrimary)
                
                Spacer()
            }
            
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.surface.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

struct ProfileInfoGroup<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 8) {
            content
        }
    }
}

struct ProfileInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(Theme.Font.body)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

struct ProfileStatBadge: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.Font.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textPrimary)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Theme.surface.opacity(0.8))
                .overlay(
                    Capsule()
                        .stroke(Theme.primary.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct HeadshotThumbnail: View {
    let imageName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            AsyncImage(url: resolveHeadshotURL(named: imageName)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.gray)
                    )
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProfileFileRow: View {
    let filename: String
    let type: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Theme.primary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(type)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.textPrimary)
                    
                    Text(filename)
                        .font(Theme.Font.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProfileActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isDestructive: Bool
    let action: () -> Void
    
    init(title: String, subtitle: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isDestructive ? .red : Theme.primary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Font.body)
                        .foregroundStyle(isDestructive ? .red : Theme.textPrimary)
                    
                    Text(subtitle)
                        .font(Theme.Font.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Sheets

struct PhotoViewerSheet: View {
    let imageName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                AsyncImage(url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("ActorProfile").appendingPathComponent(imageName)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

struct FileViewerSheet: View {
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            // TODO: Implement file viewer (PDF, etc.)
            Text("File Viewer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview {
    ProfileView()
}
