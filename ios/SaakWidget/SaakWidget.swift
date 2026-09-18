//
//  SaakWidget.swift
//  SaakWidget
//
//  Created by Alejandro Hdz on 12/06/26.
//

import WidgetKit
import SwiftUI

import WidgetKit
import SwiftUI
import AppIntents

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let timeline = Timeline(entries: [SimpleEntry(date: Date())], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct SaakWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundColor(.white)
            
            Text("Registrar Gasto")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            
            if #available(iOS 17.0, *) {
                // Esto vincula el botón a nuestra Intención (AppIntent)
                Button(intent: RegistrarGastoIntent()) {
                    Text("Dictar a IA")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.04, green: 0.44, blue: 0.46)) // Color primario de la app
    }
}

struct SaakWidget: Widget {
    let kind: String = "SaakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                SaakWidgetEntryView(entry: entry)
                    .containerBackground(Color(red: 0.04, green: 0.44, blue: 0.46), for: .widget)
            } else {
                SaakWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color(red: 0.04, green: 0.44, blue: 0.46))
            }
        }
        .configurationDisplayName("Asesor IA Finanzas")
        .description("Registra un gasto o ingreso rápidamente usando IA.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    SaakWidget()
} timeline: {
    SimpleEntry(date: .now)
}
