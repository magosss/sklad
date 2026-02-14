//
//  MainTabView.swift
//  sklad
//

import SwiftUI

struct MainTabView: View {

    var body: some View {
        TabView {
            AddMovementView()
                .tabItem {
                    Label("Добавить", systemImage: "plus.circle")
                }

            StockView()
                .tabItem {
                    Label("Склад", systemImage: "cube.box")
                }

            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environment(DataStore())
}
