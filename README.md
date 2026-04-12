# Carenion

Gestão de Cuidados de Saúde e Bem-estar para Seniores de forma simples e organizada.

## ✨ Funcionalidades

- **👨‍👩‍👧‍👦 Gestão de Idosos e Famílias**: Registo centralizado para múltiplos seniores agrupados por família.
- **📅 Agenda & Calendário**: Planeamento de consultas, exames e atividades com lembretes visuais (utilizando `table_calendar`).
- **📍 Mapas & Localização**:
  - Seleção interativa de locais via **OpenStreetMap** interno.
  - Pesquisa inteligente de moradas, hospitais e clínicas via **API Nominatim**.
  - Lançamento nativo da aplicação de mapas (Google Maps) para obter direções automáticas.
- **💊 Gestão de Medicação**:
  - Controlo de stock em tempo real.
  - Planeamento semanal de tomas (com visualização expansível por família).
  - Pesquisa híbrida inteligente de medicamentos: Combina marcas portuguesas comuns com a API RxTerms (NIH).

## 📁 Arquitetura do Projeto

O código está organizado de forma modular para fácil manutenção:
- `lib/main.dart`: Ponto de entrada e configuração do tema.
- `lib/pages/`:
  - `auth_pages.dart`: Fluxos de Login e Registo.
  - `home_page.dart`: Dashboard e navegação principal.
  - `idosos_page.dart`: Gestão de perfis e famílias.
  - `medication_page.dart`: Gestão de medicamentos e tomas.
  - `agenda_page.dart`: Calendário, eventos e integração de mapas.
- `lib/utils.dart`: Constantes e funções utilitárias partilhadas.

## 🛠 Atribuições e APIs

- **Supabase**: Backend-as-a-Service para base de dados e autenticação.
- **Flutter Map (Leaflet)**: Visualização de mapas sem necessidade de chaves de API restritivas.
- **Nominatim API**: Geocoding e pesquisa de locais (OpenStreetMap).
- **NIH RxTerms API**: Pesquisa de dosagens e termos clínicos internacionais.

---

## 🚀 Como Começar

1. Clone o repositório.
2. Crie um ficheiro `.env` na raiz do projeto com as seguintes chaves (conforme `example.env` ou fornecidas pelo administrador):
   ```env
   SUPABASE_URL=as_tua_url
   SUPABASE_ANON_KEY=a_tua_chave
   ```
3. Garanta que tem o Flutter instalado e configurado.
4. Execute:
   ```bash
   flutter pub get
   flutter run
   ```

---
*Carenion - Cuidar melhor, juntos.*
