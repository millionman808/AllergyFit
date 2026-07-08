import SwiftUI

/// Kitchen tab — meal plan + recipe discovery in one place.
struct KitchenView: View {
    @State private var segment = UserDefaults.standard.integer(forKey: "kitchenSegment")
    @StateObject private var planStore = PlanStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("Section", selection: $segment) {
                        Text("Meal plan").tag(0)
                        Text("Recipes").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.bottom, 8)

                    if segment == 0 {
                        PlanView(onBrowseRecipes: { segment = 1 })
                    } else {
                        RecipesView()
                    }
                }
            }
            .navigationTitle("Kitchen")
        }
        .environmentObject(planStore)
    }
}
