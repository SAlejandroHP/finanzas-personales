//
//  SaakWidgetControl.swift
//  SaakWidget
//
//  Created by Alejandro Hdz on 12/06/26.
//

import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct SaakWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.saaksolutions.app.finanzas.SaakWidgetControl"
        ) {
            ControlWidgetButton(action: RegistrarGastoIntent()) {
                Label("Registrar", systemImage: "sparkles")
            }
        }
        .displayName("Registrar IA")
        .description("Registra un movimiento usando Inteligencia Artificial.")
    }
}
