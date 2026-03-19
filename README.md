# LancheSimples

Aplicativo mobile em Flutter para Android e iOS com backend Firebase/Firestore, criado para operação rápida de lanchonetes em modelo multi-tenant.

## Status atual da integração Firebase

A configuração principal do Firebase já foi incorporada ao repositório para o projeto:

- **Project ID:** `lanchesimples-d101b`
- **Android package:** `com.example.lanche_simples`
- **iOS bundle id:** `com.example.lanchesimples`

Arquivos já integrados:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `firebase.json`
- `firestore.rules`
- `firestore.indexes.json`

## O que já está funcional nesta branch

- Fluxo completo de primeiro acesso com `tenant_id`, nome do operador e CPF opcional salvo localmente.
- Integração com Cloud Firestore para tenants, catálogo e comanda em aberto.
- Painel Master Admin oculto com criação de tenants e seed automático do catálogo remoto.
- Script inicial para popular o Firestore com os tenants e itens padrão do MVP.
- Pipeline de CI para gerar APK Android de release sem depender de arquivos binários versionados no PR.

## Stack

- Flutter com Material 3
- Firebase Core
- Cloud Firestore
- Shared Preferences para onboarding local do dispositivo
- Node.js script para seed inicial do Firestore
- Script Bash para regenerar o `gradle-wrapper.jar` localmente quando necessário

## Estrutura relevante

- `lib/main.dart`: bootstrap do app e inicialização segura do Firebase.
- `lib/services/app_data_service.dart`: camada de dados com integração Firestore e fallback local.
- `android/app/google-services.json`: configuração Android do Firebase.
- `ios/Runner/GoogleService-Info.plist`: configuração iOS do Firebase.
- `scripts/seed_firestore.js`: script inicial de seed do banco.
- `scripts/bootstrap_gradle_wrapper.sh`: script para gerar o `gradle-wrapper.jar` sem versionar o binário.
- `firestore.rules`: regras de acesso do MVP.
- `firestore.indexes.json`: índice inicial do catálogo.
- `.github/workflows/android.yml`: pipeline Android.

## Passo a passo para testar com Firebase real

### 1. Preparar o Firestore

1. Confirme que o projeto Firebase `lanchesimples-d101b` está selecionado no CLI.
2. Faça deploy das regras e índices:
   - `firebase deploy --only firestore:rules`
   - `firebase deploy --only firestore:indexes`

### 2. Rodar o seed inicial

1. Garanta que `GOOGLE_APPLICATION_CREDENTIALS` aponte para um service account com acesso ao projeto `lanchesimples-d101b`.
2. Execute `npm install`.
3. Rode `npm run seed:firestore`.
4. O script criará os tenants `TENANT-1001` e `TENANT-1002` com o catálogo inicial.

### 3. Preparar o projeto Flutter/Android

1. Instale o Flutter SDK estável.
2. Rode `flutter doctor` e garanta que o Android SDK esteja configurado.
3. Se o arquivo `android/gradle/wrapper/gradle-wrapper.jar` não existir localmente, execute `./scripts/bootstrap_gradle_wrapper.sh`.
4. Rode `flutter pub get`.

### 4. Executar o app Android

1. Conecte um dispositivo Android ou inicie um emulador.
2. Execute `flutter run -d android`.
3. A tela inicial deve exibir que o banco remoto está ativo.
4. Use `TENANT-1001` ou `TENANT-1002` para o primeiro onboarding.

### 5. Validar o fluxo principal

1. Finalize o onboarding com o nome do operador.
2. Na home, confirme a leitura do catálogo do Firestore.
3. Adicione itens e abra **Resumo**.
4. A comanda em aberto é persistida em `tenants/{tenantId}/comandas/{draft-operador}`.
5. Use **Limpar comanda atual** para apagar o rascunho.

### 6. Validar o Master Admin

1. Na tela inicial, toque 5 vezes no logo ou faça long press.
2. Informe o código secreto `13356436481`.
3. Crie uma nova lanchonete.
4. O tenant será salvo em `tenants/{tenantId}` e o catálogo padrão será semeado automaticamente.

### 7. Gerar APK localmente

1. Se necessário, execute `./scripts/bootstrap_gradle_wrapper.sh`.
2. Execute `flutter build apk --release`.
3. O APK ficará em `build/app/outputs/flutter-apk/app-release.apk`.

## Pipeline Android

O workflow `.github/workflows/android.yml` executa:

1. checkout do repositório;
2. Java 17;
3. Node 22;
4. Gradle;
5. validação sintática do script `scripts/seed_firestore.js`;
6. geração do `gradle-wrapper.jar` em tempo de execução;
7. Flutter estável;
8. `flutter pub get`;
9. `flutter analyze`;
10. `flutter test`;
11. `flutter build apk --release`;
12. upload do APK como artefato.
