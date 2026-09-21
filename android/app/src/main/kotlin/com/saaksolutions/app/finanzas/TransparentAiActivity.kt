package com.saaksolutions.app.finanzas

import android.app.Activity
import android.app.AlertDialog
import android.os.Bundle
import android.widget.EditText
import android.widget.Toast
import android.content.Context
import android.content.SharedPreferences
import android.view.Window
import android.view.WindowManager
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class TransparentAiActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        
        val editText = EditText(this)
        editText.hint = "Ej. Gasté \$500 en despensa con Nu"
        
        val dialog = AlertDialog.Builder(this)
            .setTitle("Registro con IA")
            .setView(editText)
            .setPositiveButton("Registrar") { _, _ ->
                val input = editText.text.toString()
                if (input.isNotEmpty()) {
                    processWithAI(input)
                } else {
                    finish()
                }
            }
            .setNegativeButton("Cancelar") { _, _ ->
                finish()
            }
            .setOnCancelListener {
                finish()
            }
            .create()
            
        dialog.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE)
        dialog.show()
    }

    private fun processWithAI(input: String) {
        Toast.makeText(this, "Procesando con IA...", Toast.LENGTH_SHORT).show()
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // HomeWidget plugin en Flutter guarda las preferencias en las preferencias compartidas nativas con prefijo "HomeWidgetPreferences"
                // O usa default preferences. Vamos a revisar ambos.
                val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                var apiKey = prefs.getString("gemini_api_key", "") ?: ""
                if (apiKey.isEmpty()) {
                    val defaultPrefs = getSharedPreferences(packageName + "_preferences", Context.MODE_PRIVATE)
                    apiKey = defaultPrefs.getString("gemini_api_key", "") ?: ""
                }
                
                val sbUrl = prefs.getString("supabase_url", "") ?: ""
                val sbAnon = prefs.getString("supabase_anon_key", "") ?: ""
                val sbToken = prefs.getString("supabase_access_token", "") ?: ""
                val userId = prefs.getString("user_id", "") ?: ""
                
                if (apiKey.isEmpty() || sbToken.isEmpty()) {
                    withContext(Dispatchers.Main) {
                        Toast.makeText(this@TransparentAiActivity, "Abre la app primero para sincronizar", Toast.LENGTH_LONG).show()
                        finish()
                    }
                    return@launch
                }
                
                val aiContext = prefs.getString("ai_context", "{}") ?: "{}"
                
                val systemPrompt = """
                Eres un asistente financiero rápido. El usuario te dará un comando de texto para registrar un movimiento.
                Extrae la información y devuelve ÚNICAMENTE un JSON válido con las siguientes llaves:
                - tipo: "ingreso" o "gasto"
                - monto: número
                - descripcion: un resumen corto
                - cuenta_origen_id: UUID de la cuenta que mencione de aquí: $aiContext
                - categoria_id: UUID de la categoría que encaje de aquí: $aiContext
                No agregues formato markdown. Solo JSON puro.
                """.trimIndent()
                
                // Call Gemini
                val geminiUrl = URL("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey")
                val geminiConn = geminiUrl.openConnection() as HttpURLConnection
                geminiConn.requestMethod = "POST"
                geminiConn.setRequestProperty("Content-Type", "application/json")
                geminiConn.doOutput = true
                
                val geminiPayload = JSONObject().apply {
                    val sysInstruction = JSONObject().put("parts", org.json.JSONArray().put(JSONObject().put("text", systemPrompt)))
                    put("systemInstruction", sysInstruction)
                    
                    val contents = org.json.JSONArray()
                    val userRole = JSONObject().put("role", "user")
                    userRole.put("parts", org.json.JSONArray().put(JSONObject().put("text", input)))
                    contents.put(userRole)
                    put("contents", contents)
                    
                    put("generationConfig", JSONObject().put("responseMimeType", "application/json"))
                }
                
                OutputStreamWriter(geminiConn.outputStream).use { it.write(geminiPayload.toString()) }
                
                val responseStr = geminiConn.inputStream.bufferedReader().use { it.readText() }
                val jsonResponse = JSONObject(responseStr)
                val candidates = jsonResponse.getJSONArray("candidates")
                val content = candidates.getJSONObject(0).getJSONObject("content")
                var text = content.getJSONArray("parts").getJSONObject(0).getString("text").trim()
                
                if (text.startsWith("```json")) {
                    text = text.substring(7)
                } else if (text.startsWith("```")) {
                    text = text.substring(3)
                }
                if (text.endsWith("```")) {
                    text = text.substring(0, text.length - 3)
                }
                text = text.trim()
                
                val resultJson = JSONObject(text)
                // Validate monto
                if (!resultJson.has("monto") || resultJson.isNull("monto")) {
                    runOnUiThread {
                        Toast.makeText(this@TransparentAiActivity, "No detecté ningún monto. Por favor incluye la cantidad.", Toast.LENGTH_LONG).show()
                    }
                    return@launch
                }
                
                // Forzar a double
                try {
                    val montoDouble = resultJson.getString("monto").toDouble()
                    resultJson.put("monto", montoDouble)
                } catch (e: Exception) {}
                
                // Construir payload seguro
                val safePayload = JSONObject()
                safePayload.put("id", UUID.randomUUID().toString())
                safePayload.put("user_id", userId)
                safePayload.put("estado", "completa")
                val df = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
                val nowStr = df.format(Date())
                safePayload.put("fecha", nowStr)
                safePayload.put("created_at", nowStr)
                
                safePayload.put("tipo", if (!resultJson.has("tipo") || resultJson.isNull("tipo")) "gasto" else resultJson.getString("tipo"))
                safePayload.put("descripcion", if (!resultJson.has("descripcion") || resultJson.isNull("descripcion")) "Registro desde Atajo" else resultJson.getString("descripcion"))
                
                // Fallback de cuenta_origen_id y categoria_id si vienen vacíos
                try {
                    val contextJson = JSONObject(aiContext)
                    
                    if (!resultJson.has("cuenta_origen_id") || resultJson.isNull("cuenta_origen_id")) {
                        val accounts = contextJson.getJSONArray("accounts")
                        if (accounts.length() > 0) {
                            resultJson.put("cuenta_origen_id", accounts.getJSONObject(0).getString("id"))
                        }
                    }
                    if (!resultJson.has("categoria_id") || resultJson.isNull("categoria_id")) {
                        val categories = contextJson.getJSONArray("categories")
                        if (categories.length() > 0) {
                            resultJson.put("categoria_id", categories.getJSONObject(0).getString("id"))
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }

                if (resultJson.has("monto") && !resultJson.isNull("monto")) {
                    safePayload.put("monto", resultJson.getDouble("monto"))
                }
                if (resultJson.has("cuenta_origen_id") && !resultJson.isNull("cuenta_origen_id")) {
                    safePayload.put("cuenta_origen_id", resultJson.getString("cuenta_origen_id"))
                }
                if (resultJson.has("categoria_id") && !resultJson.isNull("categoria_id")) {
                    safePayload.put("categoria_id", resultJson.getString("categoria_id"))
                }
                
                // Call Supabase
                val sbEndpoint = URL("$sbUrl/rest/v1/transacciones")
                val sbConn = sbEndpoint.openConnection() as HttpURLConnection
                sbConn.requestMethod = "POST"
                sbConn.setRequestProperty("Authorization", "Bearer $sbToken")
                sbConn.setRequestProperty("apikey", sbAnon)
                sbConn.setRequestProperty("Content-Type", "application/json")
                sbConn.setRequestProperty("Prefer", "return=minimal")
                sbConn.doOutput = true
                
                OutputStreamWriter(sbConn.outputStream).use { it.write(safePayload.toString()) }
                
                val responseCode = sbConn.responseCode
                withContext(Dispatchers.Main) {
                    if (responseCode in 200..204) {
                        Toast.makeText(this@TransparentAiActivity, "✅ Registrado correctamente", Toast.LENGTH_SHORT).show()
                    } else {
                        Toast.makeText(this@TransparentAiActivity, "❌ Error al guardar en Supabase", Toast.LENGTH_SHORT).show()
                    }
                    finish()
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@TransparentAiActivity, "❌ Error: ${e.message}", Toast.LENGTH_LONG).show()
                    finish()
                }
            }
        }
    }
}
