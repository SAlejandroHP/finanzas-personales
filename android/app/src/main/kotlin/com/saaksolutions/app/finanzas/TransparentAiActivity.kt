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
                var apiKey = prefs.getString("groq_api_key", "") ?: ""
                if (apiKey.isEmpty()) {
                    val defaultPrefs = getSharedPreferences(packageName + "_preferences", Context.MODE_PRIVATE)
                    apiKey = defaultPrefs.getString("groq_api_key", "") ?: ""
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
                - cuentaOrigenId: UUID de la cuenta que mencione de aquí: $aiContext
                - categoriaId: UUID de la categoría que encaje de aquí: $aiContext
                """.trimIndent()
                
                // Call Groq
                val groqUrl = URL("https://api.groq.com/openai/v1/chat/completions")
                val groqConn = groqUrl.openConnection() as HttpURLConnection
                groqConn.requestMethod = "POST"
                groqConn.setRequestProperty("Authorization", "Bearer $apiKey")
                groqConn.setRequestProperty("Content-Type", "application/json")
                groqConn.doOutput = true
                
                val groqPayload = JSONObject().apply {
                    put("model", "llama3-8b-8192")
                    put("response_format", JSONObject().put("type", "json_object"))
                    val messages = org.json.JSONArray()
                    messages.put(JSONObject().put("role", "system").put("content", systemPrompt))
                    messages.put(JSONObject().put("role", "user").put("content", input))
                    put("messages", messages)
                }
                
                OutputStreamWriter(groqConn.outputStream).use { it.write(groqPayload.toString()) }
                
                val responseStr = groqConn.inputStream.bufferedReader().use { it.readText() }
                val jsonResponse = JSONObject(responseStr)
                val content = jsonResponse.getJSONArray("choices").getJSONObject(0).getJSONObject("message").getString("content")
                val resultJson = JSONObject(content)
                
                // Prepare Supabase Payload
                resultJson.put("id", UUID.randomUUID().toString())
                resultJson.put("user_id", userId)
                resultJson.put("estado", "completada")
                
                val df = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
                val nowStr = df.format(Date())
                resultJson.put("fecha", nowStr)
                resultJson.put("created_at", nowStr)
                
                if (!resultJson.has("tipo") || resultJson.isNull("tipo")) resultJson.put("tipo", "gasto")
                if (!resultJson.has("descripcion") || resultJson.isNull("descripcion")) resultJson.put("descripcion", "Registro desde Atajo")
                
                // Call Supabase
                val sbEndpoint = URL("$sbUrl/rest/v1/transactions")
                val sbConn = sbEndpoint.openConnection() as HttpURLConnection
                sbConn.requestMethod = "POST"
                sbConn.setRequestProperty("Authorization", "Bearer $sbToken")
                sbConn.setRequestProperty("apikey", sbAnon)
                sbConn.setRequestProperty("Content-Type", "application/json")
                sbConn.setRequestProperty("Prefer", "return=minimal")
                sbConn.doOutput = true
                
                OutputStreamWriter(sbConn.outputStream).use { it.write(resultJson.toString()) }
                
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
