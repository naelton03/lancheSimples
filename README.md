# LancheSimples

Aplicativo mobile em Flutter para Android e iOS com backend Firebase, criado para operação rápida de lanchonetes em modelo multi-tenant.

## Stack inicial

- Flutter com Material 3
- Firebase Core (configuração dummy inicial)
- Shared Preferences para onboarding local do dispositivo

## Estrutura inicial

- `lib/main.dart`: bootstrap do app e inicialização do Firebase
- `lib/firebase_options.dart`: opções dummy do Firebase
- `lib/models`: modelos `Tenant`, `Item` e `Comanda`
- `lib/screens`: fluxo inicial de `Login`, `Onboarding`, `Master Admin Panel` e `Home`
- `lib/widgets`: componentes reutilizáveis como `ItemCard`
- `lib/services`: persistência local e mock de dados para o MVP inicial
- `docs/DOCUMENTACAO_MASTER.md`: documentação funcional e de produto

## Como começar

1. Instale o Flutter SDK.
2. Execute `flutter pub get`.
3. Substitua os valores dummy de `lib/firebase_options.dart` pelos dados reais do projeto Firebase.
4. Rode `flutter run` em Android ou iOS.

## Observações

- O acesso Master Admin é acionado por toque repetido ou long press no logo da tela inicial.
- O código secreto atual de desenvolvimento é `13356436481`.
- O fluxo usa dados mockados até a integração completa com Firestore, Auth e Functions.
