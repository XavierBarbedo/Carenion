import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils.dart';

class EmergencyPdfService {
  static Future<void> generateAndPrintEmergencyCard({
    required material.BuildContext context,
    required Map<String, dynamic> idosoData,
    required String emergencyContactName,
    required String emergencyContactPhone,
  }) async {
    // 1. Mostrar diálogo de loading
    material.showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const material.Center(
        child: material.CircularProgressIndicator(color: material.Colors.amber),
      ),
    );

    try {
      final supabase = Supabase.instance.client;

      // Carregar ícone da aplicação
      final imageBytes = await rootBundle.load('images/carenion_Icon-removebg-preview.png');
      final appIconImage = pw.MemoryImage(imageBytes.buffer.asUint8List());

      // 2. Procurar medicações
      final List<dynamic> medsRes = await supabase
          .from('medicacoes')
          .select()
          .eq('idoso_id', idosoData['id'])
          .order('nome');

      // 3. Procurar medições (últimas 10)
      final List<dynamic> medicoesRes = await supabase
          .from('medicoes')
          .select()
          .eq('idoso_id', idosoData['id'])
          .order('data_medicao', ascending: false)
          .limit(10);

      // Fechar o diálogo de loading
      if (context.mounted) {
        material.Navigator.pop(context);
      }

      // 4. Gerar o documento PDF
      final pdf = pw.Document();

      // Estilos do PDF
      final titleStyle = pw.TextStyle(
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.red900,
      );
      final sectionTitleStyle = pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blueGrey800,
      );
      final labelStyle = pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.grey800,
      );
      final valueStyle = pw.TextStyle(
        fontSize: 9,
        color: PdfColors.black,
      );
      final tableHeaderStyle = pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      );
      final tableBodyStyle = pw.TextStyle(
        fontSize: 8.5,
        color: PdfColors.black,
      );

      // Calcular idade
      String idadeStr = 'Desconhecida';
      final rawNasc = idosoData['data_nascimento'];
      if (rawNasc != null && rawNasc.toString().isNotEmpty) {
        try {
          final nascimento = DateTime.tryParse(rawNasc.toString());
          if (nascimento != null) {
            final hoje = DateTime.now();
            int anos = hoje.year - nascimento.year;
            if (hoje.month < nascimento.month ||
                (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
              anos--;
            }
            idadeStr = '$anos anos';
          }
        } catch (_) {}
      }

      // Data de nascimento formatada
      String dataNascStr = 'Não indicada';
      if (rawNasc != null && rawNasc.toString().isNotEmpty) {
        try {
          final parsed = DateTime.tryParse(rawNasc.toString());
          if (parsed != null) {
            dataNascStr = DateFormat('dd/MM/yyyy').format(parsed);
          }
        } catch (_) {
          dataNascStr = rawNasc.toString();
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Cabeçalho da Ficha
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.red900,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                padding: pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: pw.EdgeInsets.only(bottom: 16),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Título do documento (esquerda)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('FICHA CLÍNICA DE EMERGÊNCIA',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            )),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Assistência médica hospitalar / urgência',
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.red100),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                          style: pw.TextStyle(fontSize: 7, color: PdfColors.red200),
                        ),
                      ],
                    ),
                    // Logo Carenion (direita)
                    pw.Container(
                      padding: pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Image(appIconImage, width: 28, height: 28),
                          pw.SizedBox(width: 6),
                          pw.Text(
                            'CARENION',
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.amber800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),


              // Dados Pessoais e de Emergência lado-a-lado
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Dados Pessoais
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('1. DADOS PESSOAIS', style: sectionTitleStyle),
                        pw.SizedBox(height: 6),
                        _buildPdfDetail('Nome:', idosoData['nome'] ?? 'Não indicado', labelStyle, valueStyle),
                        _buildPdfDetail('Data Nasc.:', '$dataNascStr ($idadeStr)', labelStyle, valueStyle),
                        _buildPdfDetail('CC / BI:', idosoData['cc_bi'] ?? 'Não indicado', labelStyle, valueStyle),
                        _buildPdfDetail('NIF:', idosoData['nif'] ?? 'Não indicado', labelStyle, valueStyle),
                        _buildPdfDetail('Utente SNS:', idosoData['sns_numero'] ?? 'Não indicado', labelStyle, valueStyle),
                        if (idosoData['seguro_saude'] != null && idosoData['seguro_saude'].toString().isNotEmpty)
                          _buildPdfDetail('Seguro:', '${idosoData['seguro_saude']} (${idosoData['seguro_numero'] ?? 'N/D'})', labelStyle, valueStyle),
                        _buildPdfDetail('Morada:', idosoData['morada'] ?? 'Não indicada', labelStyle, valueStyle),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  // Contactos de Emergência e Histórico Clínico
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('2. CONTACTOS DE EMERGÊNCIA', style: sectionTitleStyle),
                        pw.SizedBox(height: 6),
                        _buildPdfDetail('Contacto Principal:', emergencyContactName, labelStyle, valueStyle),
                        _buildPdfDetail('Telefone Contacto:', emergencyContactPhone, labelStyle, valueStyle),
                        if (idosoData['telefone'] != null && idosoData['telefone'].toString().isNotEmpty)
                          _buildPdfDetail('Telefone Idoso/a:', idosoData['telefone'], labelStyle, valueStyle),
                        
                        pw.SizedBox(height: 12),
                        pw.Text('3. INFORMAÇÃO CLÍNICA', style: sectionTitleStyle),
                        pw.SizedBox(height: 6),
                        _buildPdfDetail('Patologias:', idosoData['patologias'] ?? 'Nenhuma registada', labelStyle, valueStyle),
                        _buildPdfDetail('Observações/Alergias:', idosoData['observacoes'] ?? 'Nenhuma observação', labelStyle, valueStyle),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Medicação Atual
              pw.Text('4. MEDICAÇÃO ATUAL', style: sectionTitleStyle),
              pw.SizedBox(height: 6),
              medsRes.isEmpty
                  ? pw.Text('Nenhum medicamento registado.', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic))
                  : pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3), // Nome
                        1: const pw.FlexColumnWidth(1.5), // Dosagem
                        2: const pw.FlexColumnWidth(3), // Frequência/Instruções
                        3: const pw.FlexColumnWidth(1.2), // Tipo
                        4: const pw.FlexColumnWidth(3), // Observações
                      },
                      children: [
                        // Cabeçalho da Tabela
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColors.red900),
                          children: [
                            pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text('Medicamento', style: tableHeaderStyle)),
                            pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text('Dosagem', style: tableHeaderStyle)),
                            pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text('Frequência', style: tableHeaderStyle)),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Tipo', style: tableHeaderStyle)),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Observações', style: tableHeaderStyle)),
                          ],
                        ),
                        // Linhas da Tabela
                        ...medsRes.map((med) {
                          final String tipoLabel = med['tipo'] == 'sos' ? 'SOS' : 'Normal';
                          final String freq = med['tipo'] == 'sos' 
                              ? (med['instrucoes_sos'] ?? 'Em caso de SOS') 
                              : (med['regularidade'] ?? 'Não indicada');

                          return pw.TableRow(
                            children: [
                              pw.Padding(padding: pw.EdgeInsets.all(4), child: pw.Text(med['nome'] ?? '', style: tableBodyStyle)),
                              pw.Padding(padding: pw.EdgeInsets.all(4), child: pw.Text(med['quantidade'] ?? '', style: tableBodyStyle)),
                              pw.Padding(padding: pw.EdgeInsets.all(4), child: pw.Text(freq, style: tableBodyStyle)),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(tipoLabel, style: tableBodyStyle)),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(med['observacoes'] ?? '', style: tableBodyStyle)),
                            ],
                          );
                        }),
                      ],
                    ),
              pw.SizedBox(height: 20),

              // Medições Recentes
              pw.Text('5. ÚLTIMAS MEDIÇÕES REGISTADAS', style: sectionTitleStyle),
              pw.SizedBox(height: 6),
              medicoesRes.isEmpty
                  ? pw.Text('Nenhuma medição registada recentemente.', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic))
                  : pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2), // Data
                        1: const pw.FlexColumnWidth(2.5), // Tipo
                        2: const pw.FlexColumnWidth(2), // Valor
                        3: const pw.FlexColumnWidth(4.5), // Notas
                      },
                      children: [
                        // Cabeçalho da Tabela
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
                          children: [
                            pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text('Data/Hora', style: tableHeaderStyle)),
                            pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text('Tipo', style: tableHeaderStyle)),
                            pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text('Valor', style: tableHeaderStyle)),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Observações', style: tableHeaderStyle)),
                          ],
                        ),
                        // Linhas da Tabela
                        ...medicoesRes.map((m) {
                          final date = DateTime.tryParse(m['data_medicao'] ?? '');
                          final dateStr = date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : '';
                          
                          String unidade = '';
                          final tipoLower = m['tipo'].toString().toLowerCase();
                          if (tipoLower == 'tensão arterial') {
                            unidade = ' mmHg';
                          } else if (tipoLower == 'diabetes') {
                            unidade = ' mg/dL';
                          }

                          return pw.TableRow(
                            children: [
                              pw.Padding(padding: pw.EdgeInsets.all(4), child: pw.Text(dateStr, style: tableBodyStyle)),
                              pw.Padding(padding: pw.EdgeInsets.all(4), child: pw.Text(m['tipo'] ?? '', style: tableBodyStyle)),
                              pw.Padding(padding: pw.EdgeInsets.all(4), child: pw.Text('${m['valor']}$unidade', style: tableBodyStyle)),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(m['observacoes'] ?? '', style: tableBodyStyle)),
                            ],
                          );
                        }),
                      ],
                    ),
            ];
          },
        ),
      );

      // 5. Mostrar Diálogo de Impressão nativo
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'ficha_emergencia_${idosoData['nome']?.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      // Fechar diálogo de loading se ainda estiver aberto
      if (context.mounted) {
        material.Navigator.pop(context);
        material.ScaffoldMessenger.of(context).showSnackBar(
          material.SnackBar(
            content: material.Text('Erro ao gerar ficha: ${translateSupabaseError(e)}'),
            backgroundColor: material.Colors.red,
          ),
        );
      }
    }
  }

  static pw.Widget _buildPdfDetail(String label, String value, pw.TextStyle labelStyle, pw.TextStyle valueStyle) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$label ', style: labelStyle),
          pw.Expanded(
            child: pw.Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }
}
