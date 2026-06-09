import 'dart:convert';
import 'package:http/http.dart' as http;

abstract class Part {}

class TextPart extends Part {
  final String text;
  TextPart(this.text);
}

class DataPart extends Part {
  final String mimeType;
  final List<int> bytes;
  DataPart(this.mimeType, this.bytes);
}

class Content {
  final List<Part> parts;
  Content(this.parts);

  static Content text(String text) {
    return Content([TextPart(text)]);
  }

  static Content multi(List<Part> parts) {
    return Content(parts);
  }

  static Content system(String text) {
    return Content([TextPart(text)]);
  }
}

class GenerateContentResponse {
  final String? text;
  GenerateContentResponse({this.text});
}

class ChatSession {
  final String apiKey;
  final String model;
  final String systemInstruction;
  final List<Map<String, dynamic>> _history = [];

  ChatSession({
    required this.apiKey,
    required this.model,
    required this.systemInstruction,
  }) {
    if (systemInstruction.isNotEmpty) {
      _history.add({'role': 'system', 'content': systemInstruction});
    }
  }

  Future<GenerateContentResponse> sendMessage(Content content, {String? responseMimeType}) async {
    // Construir el mensaje de usuario
    List<dynamic> messageContent = [];
    String textOnly = '';
    bool hasImage = false;

    for (var part in content.parts) {
      if (part is TextPart) {
        messageContent.add({
          "type": "text",
          "text": part.text,
        });
        textOnly += part.text + " ";
      } else if (part is DataPart) {
        final base64Image = base64Encode(part.bytes);
        messageContent.add({
          "type": "image_url",
          "image_url": {
            "url": "data:${part.mimeType};base64,$base64Image"
          }
        });
        hasImage = true;
      }
    }

    if (hasImage) {
      _history.add({
        'role': 'user',
        'content': messageContent,
      });
    } else {
      _history.add({
        'role': 'user',
        'content': textOnly.trim(),
      });
    }

    // El modelo a usar. Si tiene imagen usamos uno de vision, de lo contrario usamos el seleccionado
    String actualModel = model;
    if (hasImage) {
      actualModel = 'meta-llama/llama-4-scout-17b-16e-instruct';
    }

    final Map<String, dynamic> body = {
      'model': actualModel,
      'messages': _history,
      'temperature': 0.1,
    };

    if (responseMimeType == 'application/json') {
      body['response_format'] = {"type": "json_object"};
    }

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final reply = jsonResponse['choices'][0]['message']['content'] as String;
      _history.add({'role': 'assistant', 'content': reply});
      return GenerateContentResponse(text: reply);
    } else {
      throw Exception('Groq API Error: ${response.statusCode} - ${response.body}');
    }
  }
}

class GenerativeModel {
  final String model;
  final String apiKey;
  final Content? systemInstruction;
  final GenerationConfig? generationConfig;

  GenerativeModel({
    required this.model,
    required this.apiKey,
    this.systemInstruction,
    this.generationConfig,
  });

  ChatSession startChat({List<Content>? history}) {
    String systemText = '';
    if (systemInstruction != null && systemInstruction!.parts.isNotEmpty) {
      final part = systemInstruction!.parts.first;
      if (part is TextPart) systemText = part.text;
    }
    return ChatSession(
      apiKey: apiKey,
      model: model,
      systemInstruction: systemText,
    );
  }

  Future<GenerateContentResponse> generateContent(List<Content> contents) async {
    final session = startChat();
    final mimeType = generationConfig?.responseMimeType;
    // Enviar cada contenido excepto el último al historial, y el último mandarlo
    for (int i = 0; i < contents.length - 1; i++) {
      await session.sendMessage(contents[i], responseMimeType: mimeType);
    }
    return await session.sendMessage(contents.last, responseMimeType: mimeType);
  }
}

class GenerationConfig {
  final String? responseMimeType;
  GenerationConfig({this.responseMimeType});
}
