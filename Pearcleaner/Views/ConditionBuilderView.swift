//
//  ConditionBuilderView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 6/14/24.
//

import Foundation
import SwiftUI
import AlinFoundation

struct ConditionBuilderView: View {
    @Binding var showAlert:Bool
    @State private var include = ""
    @State private var exclude = ""
    @State private var paths = ""
    @State private var pathsEx = ""
    @State var bundle: String
    @State private var conditionExists = false


    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Text("Condition Builder")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    showAlert = false
                }
                .buttonStyle(SimpleButtonStyle(icon: "x.circle", iconFlip: "x.circle.fill", help: "Close"))
            }

            Divider()
            Spacer()
            InfoButton(text: "Some files/folders are not similar to the app name or bundle id, causing Pearcleaner to either not find them or find unrelated files. \nTo combat this, you may create a custom condition for each application bundle using keywords or direct paths. \n\n- Can add file/folder keywords that you want to either include or exclude in fuzzy searches. \n\n- Can explicitly add or remove a full Finder path to search results if you want a direct search.", label: "Instructions", edge: .bottom)
            Spacer()

            VStack {
                HStack {
                    Text("Include Keywords:").font(.callout)
                    Spacer()
                }
                HStack {
                    TextField("keyword-1, keyword-2", text: $include)
                        .textFieldStyle(RoundedTextFieldStyle())
                    Button("Clear") {
                        include = ""
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "xmark.circle.fill", help: "Clear", size: 15))
                }

                HStack {
                    Text("Exclude Keywords:").font(.callout)
                    Spacer()
                }
                HStack {
                    TextField("keyword-1, keyword-2", text: $exclude)
                        .textFieldStyle(RoundedTextFieldStyle())
                    Button("Clear") {
                        exclude = ""
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "xmark.circle.fill", help: "Clear", size: 15))
                }

                HStack {
                    Text("Add Direct Paths:").font(.callout)
                    Spacer()
                }
                HStack {
                    TextField("/Full/Path/example-1.txt, /Full/Path/example-2.txt", text: $paths)
                        .textFieldStyle(RoundedTextFieldStyle())
                    Button("Clear") {
                        paths = ""
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "xmark.circle.fill", help: "Clear", size: 15))
                }
                HStack {
                    Text("Remove Direct Paths:").font(.callout)
                    Spacer()
                }
                HStack {
                    TextField("/Full/Path/example-1.txt, /Full/Path/example-2.txt", text: $pathsEx)
                        .textFieldStyle(RoundedTextFieldStyle())
                    Button("Clear") {
                        pathsEx = ""
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "xmark.circle.fill", help: "Clear", size: 15))
                }
            }
            .padding(.horizontal)

            Spacer()

            HStack {

                Spacer()

                Button("Add/Save") {
                    showAlert = false
                    let newCondition = Condition(bundle_id: bundle, include: include.toConditionFormat(), exclude: exclude.toConditionFormat(), includeForce: paths.toConditionFormat(), excludeForce: pathsEx.toConditionFormat())
                    ConditionManager.shared.saveCondition(newCondition)
                }
                .buttonStyle(SimpleButtonStyle(icon: "plus.square.fill", label: conditionExists ? "Save" : "Add", help: "Save the condition for this application"))

                Spacer()

                Button("Remove") {
                    showAlert = false
                    include = ""
                    exclude = ""
                    paths = ""
                    pathsEx = ""
                    ConditionManager.shared.deleteCondition(bundle_id: bundle)
                }
                .buttonStyle(SimpleButtonStyle(icon: "minus.square.fill", label: "Remove", help: "Remove the condition from this application"))
                .disabled(!conditionExists)

                Spacer()

            }

            Spacer()
        }
        .padding(15)
        .frame(width: 500, height: 500)
        .background(GlassEffect(material: .hudWindow, blendingMode: .behindWindow))
        .onAppear {
            loadCondition()
        }
    }

    private func loadCondition() {
        let defaults = UserDefaults.standard
        let decoder = JSONDecoder()

        let key = "Condition-\(bundle.pearFormat())"
        if let savedCondition = defaults.object(forKey: key) as? Data {
            if let loadedCondition = try? decoder.decode(Condition.self, from: savedCondition) {
                include = loadedCondition.include.joined(separator: ", ")
                exclude = loadedCondition.exclude.joined(separator: ", ")
                if let includeForce = loadedCondition.includeForce {
                    paths = includeForce.map { $0.absoluteString }.joined(separator: ", ")
                }
                if let excludeForce = loadedCondition.excludeForce {
                    pathsEx = excludeForce.map { $0.absoluteString }.joined(separator: ", ")
                }
                conditionExists = true
            }
        }
    }
}


