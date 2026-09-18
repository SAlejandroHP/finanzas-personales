//
//  SaakWidgetBundle.swift
//  SaakWidget
//
//  Created by Alejandro Hdz on 12/06/26.
//

import WidgetKit
import SwiftUI

@main
struct SaakWidgetBundle: WidgetBundle {
    var body: some Widget {
        SaakWidget()
        SaakWidgetControl()
        SaakWidgetLiveActivity()
    }
}
