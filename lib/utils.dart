import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';

const String MED_API_URL =
    'https://clinicaltables.nlm.nih.gov/api/rxterms/v3/search?terms=';

const List<String> PORTUGUESE_MEDS = [
  'Ben-u-ron',
  'Brufen',
  'Nolotil',
  'Buscopan',
  'Maxilase',
  'Guronsan',
  'Nimed',
  'Voltaren',
  'Aspirina',
  'Pantoprazol',
  'Omeprazol',
  'Fenistil',
  'Daflon',
  'Leponex',
  'Xanax',
  'Victan',
  'Stilnox',
  'Zyrtec',
  'Aerius',
  'Ventilan',
  'Clamoxyl',
  'Augmentin',
  'Zinnat',
  'Prioftal',
  'Lotesoft',
  'Vigamox',
  'Atarax',
  'Kwells',
  'Tussilene',
  'Bisolvon',
  'Strepsils',
  'Mebocaína',
  'Ilvico',
  'Cê-Gripe',
  'Antigriphine',
  'Griponal',
  'Melhoral',
  'Aspegic',
  'Cartilogen',
  'Voltaren Emulgel',
  'Fenistil Gel',
  'Bepanthene',
  'Halibut',
  'Lansoprazol',
  'Esomeprazol',
  'Simvastatina',
  'Atorvastatina',
  'Rosuvastatina',
  'Amlodipina',
  'Ramipril',
  'Losartan',
  'Valsartan',
  'Eutirox',
  'Metformina',
  'Januvia',
  'Victoza',
  'Ozempic',
  'Trulicity',
  'Jardiance',
  'Forxiga',
];

String hashPassword(String password) {
  final bytes = utf8.encode(password); // converte para bytes
  final digest = sha256.convert(bytes); // gera hash SHA-256
  return digest.toString(); // retorna como string hexadecimal
}

/// Traduz erros do Supabase Auth e RLS para mensagens em português
String translateSupabaseError(dynamic e) {
  final msg = e.toString().toLowerCase();

  // Erros de Auth
  if (msg.contains('rate limit') || msg.contains('over_email_send_rate_limit')) {
    return 'Demasiadas tentativas. Aguarde alguns minutos antes de tentar novamente.';
  }
  if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
    return 'Email ou password incorretos.';
  }
  if (msg.contains('user already registered') || msg.contains('already been registered')) {
    return 'Este email já está registado. Tente fazer login.';
  }
  if (msg.contains('email not confirmed')) {
    return 'Por favor confirme o seu email antes de fazer login.';
  }
  if (msg.contains('password') && msg.contains('short')) {
    return 'A password é demasiado curta. Use pelo menos 6 caracteres.';
  }
  if (msg.contains('signup is disabled') || msg.contains('email_provider_disabled')) {
    return 'O registo com email está desativado no Supabase. Ative o fornecedor de Email.';
  }

  // Erros de RLS / Permissões
  if (msg.contains('permission denied') || msg.contains('row-level security')) {
    return 'Sem permissão para esta operação. Verifique se está autenticado.';
  }
  if (msg.contains('jwt expired') || msg.contains('token is expired')) {
    return 'Sessão expirada. Por favor faça login novamente.';
  }
  if (msg.contains('not authenticated') || msg.contains('no user found')) {
    return 'Utilizador não autenticado. Faça login novamente.';
  }
  if (msg.contains('new row violates') || msg.contains('violates row-level security')) {
    return 'Sem permissão para inserir estes dados. Verifique a sua conta.';
  }

  // Erros de rede
  if (msg.contains('socketexception') || msg.contains('connection refused')) {
    return 'Erro de ligação à internet. Verifique a sua conexão.';
  }

  // Fallback
  return 'Ocorreu um erro: $e';
}

/// Helper to build a label with a red asterisk for required fields
Widget buildRequiredLabel(String text) {
  return Text.rich(
    TextSpan(
      text: text,
      children: const [
        TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
      ],
    ),
  );
}
/// Helper to return the correct term for 'Idoso' based on gender and plurality
String formatIdoso(String? sexo, {bool plural = false, bool capitalize = true}) {
  String termo;
  if (plural) {
    termo = "idosos/as";
  } else if (sexo == 'F') {
    termo = "idosa";
  } else if (sexo == 'M') {
    termo = "idoso";
  } else {
    termo = "idoso/a";
  }

  if (capitalize && termo.isNotEmpty) {
    return termo[0].toUpperCase() + termo.substring(1);
  }
  return termo;
}
