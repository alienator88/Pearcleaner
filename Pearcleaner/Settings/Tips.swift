//
//  Tips.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 7/2/24.
//


import SwiftUI
import Foundation
import AlinFoundation

struct TipsSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("settings.general.glass") private var glass: Bool = false

    var body: some View {
        VStack {

            PearGroupBox(header: { Text("Tips And Tricks").font(.title2) }, content: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("1. Clicking an app will perform a search for files and folders, which will be displayed in the Files view")
                        Text("2. The Files view will show app details and the found files along with a toolbar above the file list which shows related badges for the app, allows checking/unchecking all files and sorting alphabetically or by size")
                        Text("3. Clicking the Trash button on the Files view will remove the selected files and folders only")
                        Text("4. After deletion, you can hit CMD + Z to undo while Pearcleaner or Finder is focused")
                        Text("5. While on the Files view for an app, you can open the Condition Builder with CMD + B or from the Tools menubar item Instructions on using Condition Builder are available on the popup sheet")
                        Text("6. On the Files view again, you can hit CMD + E to export a list of the found files or from the Tools menubar item")
                        Text("7. CMD + U will check for updates manually")
                        Text("8. CMD + R will refresh the app list. This can also be done from the refresh button in the search bar")
                        Text("9. In the search bar menu button, you will also find Orphaned Files which will find files leftover by previously uninstalled applications")
                        Text("10. You can enable a menubar icon from Settings")
                        Text("11. You can enable mini mode version of the UI from Settings")
                        Text("12. You can enable a Finder extension from Settings which allows you to uninstall apps by right clicking them in Finder")
                        Text("13. You can enable Homebrew cleanup from Settings")
                        Text("14. You can change the app theme colors from Settings")
                        Text("15. When there's new features available, an announcement badge will show at the top of the app list. Same for app app updates or missing permissions")
                        Text("16. You can disable animations in the Settings Interface tab plus a few more other options like confirmation dialog when removing files")
                    }
                    .padding()
                }
                .scrollIndicators(.visible)
                .frame(height: 530)
                .frame(maxWidth: .infinity)
            })

        }

    }

}

