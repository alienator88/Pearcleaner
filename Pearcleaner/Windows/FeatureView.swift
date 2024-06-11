//
//  FeatureView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 5/5/24.
//

import SwiftUI


struct FeatureView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("settings.general.features") private var features: String = ""

    var body: some View {
        VStack(spacing: 5) {
            HStack {

                Spacer()

                Text("New features for v\((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)!)!")                    .font(.title)
                    .bold()
                    .padding(.vertical)

                Spacer()

            }

            Divider()
                .padding([.horizontal])

            Text(features)
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding()

            Spacer()

            HStack(alignment: .center, spacing: 20) {
                Button(action: {
                    NewWin.close()
                }) {
                    Text("Okay")
                }
                .buttonStyle(SimpleButtonBrightStyle(icon: "checkmark.circle", label: "Ok", help: "Ok", color: Color("mode")))
            }
            .padding(.bottom)

        }
        .padding(EdgeInsets(top: -25, leading: 0, bottom: 25, trailing: 0))

    }

}


