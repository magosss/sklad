//
//  ContentView.swift
//  sklad
//
//  Created by Дом on 10.02.2026.
//

import SwiftUI

/// Обёртка для предварительного просмотра в Xcode.
struct ContentView: View {
    var body: some View {
        MainTabView()
            .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
    }
}

#Preview {
    ContentView()
}
