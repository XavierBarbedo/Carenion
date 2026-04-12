import 'dart:convert';
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
