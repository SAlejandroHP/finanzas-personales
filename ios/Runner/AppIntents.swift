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
        
        let apiKey = userDefaults.string(forKey: "groq_api_key") ?? ""
        let sbUrl = userDefaults.string(forKey: "supabase_url") ?? ""
        let sbAnon = userDefaults.string(forKey: "supabase_anon_key") ?? ""
        let sbToken = userDefaults.string(forKey: "supabase_access_token") ?? ""
        let userId = userDefaults.string(forKey: "user_id") ?? ""
        let aiContext = userDefaults.string(forKey: "ai_context") ?? "{}"
        
        if apiKey.isEmpty || sbToken.isEmpty {
            return .result(dialog: "Abre la app primero para sincronizar tu cuenta.")
        }
        
        // 1. LLAMAR A GROQ
        let systemPrompt = """
        Eres un asistente financiero. El usuario dictará un movimiento.
        Extrae y devuelve ÚNICAMENTE un JSON válido con estas llaves:
        - tipo: "ingreso" o "gasto"
        - monto: número (float)
        - descripcion: un resumen corto
        - cuentaOrigenId: busca el UUID de la cuenta que mencione o la que suene más parecida de aquí: \(aiContext)
        - categoriaId: busca el UUID de la categoría que mejor encaje de aquí: \(aiContext)
        No agregues texto extra, solo el JSON.
        """
        
        guard let groqUrl = URL(string: "https://api.groq.com/openai/v1/chat/completions") else { return .result(dialog: "Error interno en la URL.") }
        var groqReq = URLRequest(url: groqUrl)
        groqReq.httpMethod = "POST"
        groqReq.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        groqReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let groqBody: [String: Any] = [
            "model": "llama3-8b-8192",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": descripcion]
            ],
            "response_format": ["type": "json_object"]
        ]
        groqReq.httpBody = try? JSONSerialization.data(withJSONObject: groqBody)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: groqReq)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String,
               let contentData = content.data(using: .utf8),
               var txData = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
                
                // 2. INSERTAR EN SUPABASE
                txData["id"] = UUID().uuidString
                txData["user_id"] = userId
                txData["estado"] = "completa"
                
                let df = ISO8601DateFormatter()
                txData["fecha"] = df.string(from: Date())
                txData["created_at"] = df.string(from: Date())
                
                guard let sbReqUrl = URL(string: "\(sbUrl)/rest/v1/transactions") else { return .result(dialog: "Error en la URL de Supabase.") }
                var sbReq = URLRequest(url: sbReqUrl)
                sbReq.httpMethod = "POST"
                sbReq.setValue("Bearer \(sbToken)", forHTTPHeaderField: "Authorization")
                sbReq.setValue(sbAnon, forHTTPHeaderField: "apikey")
                sbReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                sbReq.setValue("return=minimal", forHTTPHeaderField: "Prefer")
                
                sbReq.httpBody = try? JSONSerialization.data(withJSONObject: txData)
                
                let (_, response) = try await URLSession.shared.data(for: sbReq)
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 201 || httpRes.statusCode == 200 || httpRes.statusCode == 204 {
                    // Éxito
                }
            }
        } catch {
            return .result(dialog: "Error al procesar con IA.")
        }
        
        return .result(dialog: "¡Registrado correctamente!")
    }
}
