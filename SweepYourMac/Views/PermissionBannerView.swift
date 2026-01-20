import SwiftUI

/// Banner that warns users when Full Disk Access is not granted
struct PermissionBannerView: View {
    @ObservedObject var permissionManager: PermissionManager
    @State private var isDismissed = false

    var body: some View {
        if !permissionManager.hasFullDiskAccess && !isDismissed {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(.orange)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Full Disk Access Required")
                        .fontWeight(.semibold)
                    Text("Grant permission to scan all system caches and protected files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Open Settings") {
                    permissionManager.openSystemPreferences()
                }
                .buttonStyle(.borderedProminent)

                Button(action: { isDismissed = true }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

#Preview {
    VStack {
        PermissionBannerView(permissionManager: PermissionManager())
        Spacer()
    }
    .padding()
    .frame(width: 600, height: 200)
}
