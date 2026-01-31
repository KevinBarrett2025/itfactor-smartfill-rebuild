import SwiftUI

public struct RepsFormView: View {
    @State private var vm = RepsViewModel()
    @State private var selectedCategory = "Film/TV Agent"
    @State private var showingRepForm = false
    @AppStorage("STSThemeID") private var storedThemeID: String = STSThemeID.studioLobbyV1.rawValue
    @Environment(\.dismiss) private var dismiss
    
    private var currentTheme: STSTheme {
        let id = STSThemeID(rawValue: storedThemeID) ?? .studioLobbyV1
        return STSThemeLibrary.theme(for: id)
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                currentTheme.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("My Reps")
                            .font(Theme.Font.title)
                            .foregroundStyle(currentTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Manage your professional representation team. This information will be available when creating new projects.")
                            .font(Theme.Font.body)
                            .foregroundStyle(currentTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // Simplified Add Rep Section
                    VStack(spacing: 16) {
                        HStack {
                            Text("Add New Rep")
                                .font(Theme.Font.headline)
                                .foregroundStyle(currentTheme.textPrimary)
                            
                            Spacer()
                            
                            Menu {
                                ForEach(RepsViewModel.categories, id: \.self) { category in
                                    Button(category) {
                                        selectedCategory = category
                                        showingRepForm = true
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(currentTheme.primaryAccent)
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(currentTheme.primaryAccent)
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
                    .padding(.horizontal, 24)
                    
                    // Existing Reps List
                    if !vm.reps.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your Team")
                                .font(Theme.Font.headline)
                                .foregroundStyle(currentTheme.textPrimary)
                                .padding(.horizontal, 24)
                            
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(vm.reps) { rep in
                                        RepRowCard(rep: rep, vm: vm)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    } else {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Image(systemName: "person.2.badge.gearshape")
                                .font(.system(size: 64))
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Text("No representation added yet")
                                .font(Theme.Font.body)
                                .foregroundStyle(.gray)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(currentTheme.textPrimary)
                }
            }
        }
        .sheet(isPresented: $showingRepForm) {
            RepFormSheet(
                category: selectedCategory,
                vm: vm
            )
        }
    }
}

private struct RepRowCard: View {
    let rep: RepInfo
    let vm: RepsViewModel
    @State private var showingEditForm = false
    
    var body: some View {
        BrandedRowCard(
            title: rep.name,
            subtitle: rep.category,
            roles: buildContactInfo(),
            onTap: {
                showingEditForm = true
            }
        )
        .sheet(isPresented: $showingEditForm) {
            RepEditSheet(rep: rep, vm: vm)
        }
    }
    
    private func buildContactInfo() -> String {
        var parts: [String] = []
        
        if let company = rep.companyName, !company.isEmpty {
            parts.append(company)
        }
        
        if let address = rep.companyAddress, !address.isEmpty {
            parts.append(address)
        }
        
        if let email = rep.email, !email.isEmpty {
            parts.append(email)
        }
        
        if let phone = rep.phone, !phone.isEmpty {
            parts.append(phone)
        }
        
        return parts.joined(separator: " • ")
    }
}

private struct RepFormSheet: View {
    let category: String
    let vm: RepsViewModel
    
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
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(repTheme.primaryAccent)
                        
                        Text(category)
                            .font(Theme.Font.title)
                            .foregroundStyle(repTheme.textPrimary)
                        
                        Text("Add your \(category.lowercased()) details")
                            .font(Theme.Font.body)
                            .foregroundStyle(repTheme.textPrimary.opacity(0.75))
                    }
                    .padding(.top, 20)
                    
                    // Form Fields
                    VStack(spacing: 16) {
                        WizardInputRow(
                            title: "Name",
                            placeholder: "e.g. Sarah Johnson - CAA",
                            text: $name
                        )
                        
                        WizardInputRow(
                            title: "Email",
                            placeholder: "email@agency.com (optional)",
                            text: $email
                        )
                        
                        WizardInputRow(
                            title: "Phone",
                            placeholder: "(310) 555-0123 (optional)",
                            text: $phone
                        )
                        
                        WizardInputRow(
                            title: "Company Name",
                            placeholder: "Agency / Management Company",
                            text: $companyName
                        )
                        
                        WizardInputRow(
                            title: "Company Address",
                            placeholder: "123 Studio St, Los Angeles, CA",
                            text: $companyAddress
                        )
                    }
                    
                    Spacer()
                    
                    // Buttons
                    VStack(spacing: 16) {
                        BrandedPrimaryButton(
                            label: "Save \(category)",
                            icon: "checkmark.circle.fill"
                        ) {
                            vm.addRep(
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
            .navigationTitle("Add Rep")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .onAppear {
            // Auto-fill based on category if needed
            if category == "Film/TV Agent" && name.isEmpty {
                name = ""
            }
        }
    }
}

private struct RepEditSheet: View {
    let rep: RepInfo
    let vm: RepsViewModel
    
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var companyName: String
    @State private var companyAddress: String
    @AppStorage("STSThemeID") private var storedThemeID: String = STSThemeID.studioLobbyV1.rawValue
    @Environment(\.dismiss) private var dismiss
    
    private var repTheme: STSTheme {
        let id = STSThemeID(rawValue: storedThemeID) ?? .studioLobbyV1
        return STSThemeLibrary.theme(for: id)
    }
    
    init(rep: RepInfo, vm: RepsViewModel) {
        self.rep = rep
        self.vm = vm
        _name = State(initialValue: rep.name)
        _email = State(initialValue: rep.email ?? "")
        _phone = State(initialValue: rep.phone ?? "")
        _companyName = State(initialValue: rep.companyName ?? "")
        _companyAddress = State(initialValue: rep.companyAddress ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                repTheme.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 60))
                            .foregroundStyle(repTheme.primaryAccent)
                        
                        Text("Edit Rep")
                            .font(Theme.Font.title)
                            .foregroundStyle(repTheme.textPrimary)
                        
                        Text(rep.category)
                            .font(Theme.Font.headline)
                            .foregroundStyle(repTheme.textPrimary.opacity(0.75))
                    }
                    .padding(.top, 20)
                    
                    // Form Fields
                    VStack(spacing: 16) {
                        WizardInputRow(
                            title: "Name",
                            placeholder: "e.g. Sarah Johnson - CAA",
                            text: $name
                        )
                        
                        WizardInputRow(
                            title: "Email",
                            placeholder: "email@agency.com (optional)",
                            text: $email
                        )
                        
                        WizardInputRow(
                            title: "Phone",
                            placeholder: "(310) 555-0123 (optional)",
                            text: $phone
                        )
                        
                        WizardInputRow(
                            title: "Company Name",
                            placeholder: "Agency / Management Company",
                            text: $companyName
                        )
                        
                        WizardInputRow(
                            title: "Company Address",
                            placeholder: "123 Studio St, Los Angeles, CA",
                            text: $companyAddress
                        )
                    }
                    
                    Spacer()
                    
                    // Buttons
                    VStack(spacing: 16) {
                        BrandedPrimaryButton(
                            label: "Save \(rep.category)",
                            icon: "checkmark.circle.fill"
                        ) {
                            var updatedRep = rep
                            updatedRep.name = name
                            updatedRep.email = email.isEmpty ? nil : email
                            updatedRep.phone = phone.isEmpty ? nil : phone
                            updatedRep.companyName = companyName.isEmpty ? nil : companyName
                            updatedRep.companyAddress = companyAddress.isEmpty ? nil : companyAddress
                            vm.updateRep(updatedRep)
                            dismiss()
                        }
                        .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                        
                        Button {
                            vm.deleteRep(rep)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Remove \(rep.category)")
                                    .fontWeight(.semibold)
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.red,
                                        Color.red.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal)
                        
                        BrandedSecondaryButton(label: "Cancel") {
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
            .navigationTitle("Edit Rep")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    RepsFormView()
}
