import SwiftUI
import UIKit

// MARK: - Project Wizard Input Rows (Edge-to-Edge) - NaN-SAFE VERSION
struct WizardInputRow: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField(placeholder, text: $text)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.vertical, 8)
                        .overlay(
                            Rectangle()
                                .frame(height: clampFinite(1, min: 1, fallback: 1))
                                .foregroundColor(.white.opacity(0.3)),
                            alignment: .bottom
                        )
                }
                
                Spacer()
            }
            .padding()
            .background(
                SafeRoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemIndigo).opacity(0.15))
                    .overlay(
                        SafeRoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: clampFinite(6, fallback: 6), x: 0, y: 4)
        }
    }
}

struct WizardPickerRow<SelectionValue: Hashable>: View {
    var title: String
    var selection: Binding<SelectionValue>
    var options: [(SelectionValue, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Picker(title, selection: selection) {
                        ForEach(options, id: \.0) { option in
                            Text(option.1).tag(option.0)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                }
                
                Spacer()
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding()
            .background(
                SafeRoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemIndigo).opacity(0.15))
                    .overlay(
                        SafeRoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: clampFinite(6, fallback: 6), x: 0, y: 4)
        }
        .simultaneousGesture(TapGesture().onEnded {
            dismissKeyboard()
        })
    }
}

struct WizardNumberPickerRow: View {
    var title: String
    var subtitle: String?
    @Binding var number: Int
    var range: ClosedRange<Int>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Picker(title, selection: $number) {
                        ForEach(range, id: \.self) { sceneCount in
                            if sceneCount == 1 {
                                Text("1 Scene").tag(sceneCount)
                            } else {
                                Text("\(sceneCount) Scenes").tag(sceneCount)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "number")
                        .font(.title3)
                        .foregroundColor(.blue.opacity(0.8))
                    
                    Text("\(number)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                SafeRoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemIndigo).opacity(0.15))
                    .overlay(
                        SafeRoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: clampFinite(6, fallback: 6), x: 0, y: 4)
        }
        .simultaneousGesture(TapGesture().onEnded {
            dismissKeyboard()
        })
    }
}

struct WizardDateRow: View {
    var title: String
    @Binding var date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(.white)
                        .colorScheme(.dark)
                }
                
                Spacer()
            }
            .padding()
            .background(
                SafeRoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemIndigo).opacity(0.15))
                    .overlay(
                        SafeRoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: clampFinite(6, fallback: 6), x: 0, y: 4)
        }
        .simultaneousGesture(TapGesture().onEnded {
            dismissKeyboard()
        })
    }
}

struct WizardFileImportRow: View {
    var title: String
    var subtitle: String
    var fileName: String?
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Text(fileName ?? subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if fileName != nil {
                        Text("📎")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    
                    Image(systemName: "doc.badge.plus")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .padding()
            .background(
                SafeRoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemIndigo).opacity(0.15))
                    .overlay(
                        SafeRoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: clampFinite(6, fallback: 6), x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct WizardDisplayRow: View {
    var title: String
    var value: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding()
        .background(
            SafeRoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemIndigo).opacity(0.15))
                .overlay(
                    SafeRoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: clampFinite(6, fallback: 6), x: 0, y: 4)
    }
}

#Preview {
    VStack(spacing: 12) {
        WizardInputRow(title: "Project Title", placeholder: "Enter project name", text: .constant("Silver Lake Pilot"))
        
        WizardPickerRow(
            title: "Project Type",
            selection: .constant("Feature"),
            options: [
                ("Feature", "Feature"),
                ("Television", "Television"),
                ("Commercial", "Commercial")
            ]
        )
        
        WizardNumberPickerRow(
            title: "Number of Scenes",
            subtitle: "How many scenes will you be working on?",
            number: .constant(3),
            range: 1...10
        )
        
        WizardDateRow(title: "Shoot Date", date: .constant(Date()))
        
        WizardFileImportRow(
            title: "Import Sides",
            subtitle: "Upload PDF or TXT file",
            fileName: "Sides.pdf"
        ) {}
        
        WizardDisplayRow(title: "Casting Director", value: "Jamie Rivera")
    }
    .padding()
    .background(BrandBackground())
}
