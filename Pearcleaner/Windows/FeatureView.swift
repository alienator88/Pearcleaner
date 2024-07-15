//
//  FeatureView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 5/5/24.
//

import SwiftUI
import AlinFoundation

struct FeatureView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @AppStorage("settings.general.features") private var features: String = ""

    var body: some View {
        VStack(spacing: 5) {
            HStack {

                Spacer()

                Text("New features for v\((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)!)!")                    .font(.title)
                    .bold()
//                    .padding(.bottom)

                Spacer()

            }

            Divider()
                .padding([.vertical])

            Text(features)
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding(.horizontal)

            Spacer()

            HStack(alignment: .center, spacing: 20) {
                Button(action: {
                    dismiss()
//                    NewWin.close()
                }) {
                    Text("Close")
                }
//                .buttonStyle(SimpleButtonBrightStyle(icon: "checkmark.circle", label: "Ok", help: "Ok", color: .primary))
            }
            .padding(.vertical)

        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.pickerColor)

//        .padding(EdgeInsets(top: -25, leading: 0, bottom: 25, trailing: 0))

    }

}


