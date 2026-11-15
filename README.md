# Parlor

Chat com IA 100% offline. Modelo local (GGUF), personagens locais, zero servidor, zero conta, zero ads. Feature-set equivalente ao tier premium de apps de chat com IA: chats e personas ilimitados, criação e edição de personas, memória por persona, exportação de transcrição.

## Requisitos

- macOS com Xcode 15+
- Homebrew (o script instala o xcodegen sozinho se faltar)

## Build

    ./scripts/build_ipa.sh

Primeira execução compila o llama.cpp via SPM — demora vários minutos; normal.

## Instalação

**Apple ID gratuito (recomendado):** deixe `teamID` como `YOUR_TEAM_ID`. O script gera `build/Parlor-unsigned.ipa`; instale com Sideloadly ou AltStore (certificado de 7 dias, re-sign na expiração).

**Conta de desenvolvedor:** coloque seu `teamID` em `exportOptions.plist` e o script gera `build/export/Parlor.ipa` já assinado.

## Modelo

No primeiro launch: Settings → Download model (~1 GB; Qwen2.5-1.5B-Instruct Q4_K_M por padrão). Depois disso o app é totalmente offline.

Sem download no app: pelo app Arquivos, coloque um GGUF renomeado para `parlor-model.gguf` em `On My iPhone/Parlor/models/`.

Para trocar o modelo: qualquer GGUF instruct pequeno (1–3B) funciona — ajuste a URL em Settings (persistida) ou o default em `Sources/LLMEngine.swift` (`ParlorModel.defaultURL`).

## Estrutura

- `Sources/ParlorApp.swift`, `ContentView.swift` — entrada, tabs
- `Sources/LLMEngine.swift` — wrapper llama.cpp (load, tokenize, sampling, stop)
- `Sources/ChatStore.swift`, `PersonaStore.swift`, `ChatPrompts.swift` — persistência em JSON no Documents e montagem de prompt
- `Sources/ChatView.swift`, `ChatListView.swift`, `PersonaListView.swift`, `PersonaEditorView.swift`, `SettingsView.swift` — UI SwiftUI
- `Sources/Support.swift` — Color(hex), ShareSheet
- `Resources/personas.json` — 5 personas originais de exemplo (editáveis/deletáveis no app)
- `Resources/Assets.xcassets` — ícone e cor de acento (originais, desenhados para o Parlor)

## Notas de engenharia

- Inferência na CPU; Qwen2.5-1.5B Q4_K_M roda aproximadamente 8–15 tok/s em A15 ou melhor.
- KV cache não é reutilizado entre turnos (cada turno re-decoda o histórico — correto e barato em modelo pequeno).
- Contexto de 4096 tokens; conversas longas usam as últimas 40 mensagens no prompt.
- llama.cpp vem do SPM no branch `master`. Depois do primeiro build que compilar, fixe o package no commit usado para builds reproduzíveis.
