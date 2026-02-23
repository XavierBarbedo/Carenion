# Carenion

Gestão de Cuidados de Saúde e Bem-estar para Seniores.

## Funcionalidades
- Registo de Idosos e Famílias.
- Gestão de Medicação com controlo de stock.
- Planeamento semanal de tomas.
- Pesquisa de medicamentos via API externa.

## Atribuições e APIs
- **Supabase**: Backend para persistência de dados.
- **Pesquisa Híbrida de Medicamentos**: Combina uma base de dados local de marcas portuguesas (ex: Ben-u-ron, Brufen) com a API científica do NIH para resultados abrangentes.
- **NIH RxTerms API**: Utilizada para pesquisa de nomes clínicos e dosagens internacionais.
- **Dataset Local**: Lista curada das medicações mais comuns em Portugal para uma experiência de utilizador otimizada.

---

## Como Começar

1. Clone o repositório.
2. Configure as credenciais do Supabase no `main.dart`.
3. Execute `flutter run`.
