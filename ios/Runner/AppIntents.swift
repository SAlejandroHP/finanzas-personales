import AppIntents
import UIKit
import SwiftUI

@available(iOS 16.0, *)
struct RegistrarGastoIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar Movimiento"
    static var description = IntentDescription("Registra rápidamente un gasto o ingreso dictándole a la IA.")
    
    @Parameter(title: "¿En qué lo gastaste?")
    var descripcion: String
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let appGroupId = "group.com.saaksolutions.app.finanzas"
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
            return .result(dialog: "Error de configuración interna.")
        }
        
        let apiKey = userDefaults.string(forKey: "gemini_api_key") ?? ""
        let sbUrl = userDefaults.string(forKey: "supabase_url") ?? ""
        let sbAnon = userDefaults.string(forKey: "supabase_anon_key") ?? ""
        let sbToken = userDefaults.string(forKey: "supabase_access_token") ?? ""
        let userId = userDefaults.string(forKey: "user_id") ?? ""
        let aiContext = userDefaults.string(forKey: "ai_context") ?? "{}"
        
        if apiKey.isEmpty || sbToken.isEmpty {
            return .result(dialog: "Abre la app primero para sincronizar tu cuenta.")
        }
        
        // 1. LLAMAR A GEMINI
        let systemPrompt = """
        Eres un asistente financiero. El usuario dictará un movimiento.
        Extrae y devuelve ÚNICAMENTE un JSON válido con estas llaves:
        - tipo: "ingreso" o "gasto"
        - monto: número (float)
        - descripcion: un resumen corto
        - cuenta_origen_id: busca el UUID de la cuenta que mencione de aquí: \(aiContext). Si no menciona ninguna, omite la llave o devuelve null.
        - categoria_id: busca el UUID de la categoría que mejor encaje de aquí: \(aiContext)
        No agregues texto extra, solo el JSON puro sin bloques markdown.
        """
        
        guard let geminiUrl = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)") else { return .result(dialog: "Error interno en la URL.") }
        var geminiReq = URLRequest(url: geminiUrl)
        geminiReq.httpMethod = "POST"
        geminiReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let geminiBody: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": descripcion]]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]
        geminiReq.httpBody = try? JSONSerialization.data(withJSONObject: geminiBody)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: geminiReq)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let rawText = parts.first?["text"] as? String {
                
                // Limpiar posibles bloques de markdown que Gemini pueda devolver
                var cleanText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanText.hasPrefix("```json") {
                    cleanText = String(cleanText.dropFirst(7))
                } else if cleanText.hasPrefix("```") {
                    cleanText = String(cleanText.dropFirst(3))
                }
                if cleanText.hasSuffix("```") {
                    cleanText = String(cleanText.dropLast(3))
                }
                
                guard let contentData = cleanText.data(using: .utf8),
                      var txData = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
                    return .result(dialog: "La IA devolvió un formato no válido.")
                }
                if txData["monto"] == nil || txData["monto"] is NSNull {
                    return .result(dialog: "No detecté ningún monto. Por favor incluye la cantidad (ej. 'Gasté 500 en cena').")
                }
                
                // Forzar monto a Double (por si Gemini lo mandó como String)
                if let montoStr = txData["monto"] as? String, let montoDouble = Double(montoStr) {
                    txData["monto"] = montoDouble
                }
                
                // 2. INSERTAR EN SUPABASE
                txData["id"] = UUID().uuidString
                txData["user_id"] = userId
                txData["estado"] = "completa"
                
                let df = ISO8601DateFormatter()
                txData["fecha"] = df.string(from: Date())
                txData["created_at"] = df.string(from: Date())
                
                // Fallback para cuenta_origen_id y categoria_id si vienen vacíos
                if let contextData = aiContext.data(using: .utf8),
                   let contextJson = try? JSONSerialization.jsonObject(with: contextData) as? [String: Any] {
                    
                    if txData["cuenta_origen_id"] == nil || txData["cuenta_origen_id"] is NSNull {
                        if let accounts = contextJson["accounts"] as? [[String: Any]],
                           let firstAccount = accounts.first,
                           let accountId = firstAccount["id"] as? String {
                            txData["cuenta_origen_id"] = accountId
                        }
                    }
                    
                    if txData["categoria_id"] == nil || txData["categoria_id"] is NSNull {
                        if let categories = contextJson["categories"] as? [[String: Any]],
                           let firstCat = categories.first,
                           let catId = firstCat["id"] as? String {
                            txData["categoria_id"] = catId
                        }
                    }
                }
                
                if txData["tipo"] == nil || txData["tipo"] is NSNull {
                    txData["tipo"] = "gasto"
                }
                
                // Construir payload seguro (solo columnas que sabemos que existen en la BD)
                var safePayload: [String: Any] = [
                    "id": UUID().uuidString,
                    "user_id": userId,
                    "estado": "completa",
                    "fecha": df.string(from: Date()),
                    "created_at": df.string(from: Date()),
                    "tipo": txData["tipo"] as? String ?? "gasto",
                    "descripcion": txData["descripcion"] as? String ?? "Registro desde Atajo"
                ]
                
                if let montoDouble = txData["monto"] as? Double {
                    safePayload["monto"] = montoDouble
                }
                if let cOrigenId = txData["cuenta_origen_id"] as? String {
                    safePayload["cuenta_origen_id"] = cOrigenId
                }
                if let catId = txData["categoria_id"] as? String {
                    safePayload["categoria_id"] = catId
                }
                
                guard let sbReqUrl = URL(string: "\(sbUrl)/rest/v1/transacciones") else { return .result(dialog: "Error en la URL de Supabase.") }
                var sbReq = URLRequest(url: sbReqUrl)
                sbReq.httpMethod = "POST"
                sbReq.setValue("Bearer \(sbToken)", forHTTPHeaderField: "Authorization")
                sbReq.setValue(sbAnon, forHTTPHeaderField: "apikey")
                sbReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                sbReq.setValue("return=minimal", forHTTPHeaderField: "Prefer")
                
                sbReq.httpBody = try? JSONSerialization.data(withJSONObject: safePayload)
                
                let (_, response) = try await URLSession.shared.data(for: sbReq)
                if let httpRes = response as? HTTPURLResponse {
                    if httpRes.statusCode == 201 || httpRes.statusCode == 200 || httpRes.statusCode == 204 {
                        return .result(dialog: "¡Registrado correctamente!")
                    } else {
                        return .result(dialog: "Error de servidor: \(httpRes.statusCode)")
                    }
                }
            }
        } catch {
            return .result(dialog: "Error de conexión o procesamiento.")
        }
        
        return .result(dialog: "No se pudo procesar la respuesta.")
    }
}
