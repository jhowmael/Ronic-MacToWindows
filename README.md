<p align="center">
  <img src="branding/logo.png" alt="Ronic MacToWindows" width="160">
</p>

<h1 align="center">Ronic MacToWindows</h1>

<p align="center">
  <b>Use os atalhos do Windows no macOS, com a mesma memória muscular.</b><br>
  Ctrl+C/V, Home/End, Ctrl+←/→, Alt+Tab, Alt+F4, Win+L… · nativo em Swift · latência imperceptível · só na barra de menus
</p>

<p align="center">
  <a href="https://github.com/jhowmael/Ronic-MacToWindows/releases/latest/download/RonicMacToWindows-macOS.zip">
    <img src="https://img.shields.io/badge/Download-macOS-0078D4?style=for-the-badge&logo=apple&logoColor=white" alt="Download para macOS">
  </a>
</p>

<p align="center">
  <a href="https://github.com/jhowmael/Ronic-MacToWindows/releases">Todas as versões</a> ·
  <a href="#instalação">Instalação</a> ·
  <a href="#atalhos">Atalhos</a> ·
  <a href="#compilar-a-partir-do-código">Compilar</a>
</p>

---

## Download

| Sistema | Arquivo | Requisitos |
|---|---|---|
| **macOS** (Apple Silicon e Intel) | [`RonicMacToWindows-macOS.zip`](https://github.com/jhowmael/Ronic-MacToWindows/releases/latest/download/RonicMacToWindows-macOS.zip) | macOS 14 Sonoma ou mais recente |

* **Fica só na barra superior.** Não aparece no Dock nem no ⌘Tab.
* **Não inicia com o sistema.** Ele só roda quando você abre o app. Depois de ligar ou reiniciar o Mac, abra-o de novo quando quiser.
* **Leve.** Usa cerca de 0,1 µs por tecla e nenhuma CPU parado, sem timers nem polling.

## Instalação

1. Baixe e descompacte `RonicMacToWindows-macOS.zip`. Arraste **RonicMacToWindows.app** para **Aplicativos**.
2. Abra o app. Na primeira vez, o macOS pode bloquear: vá em **Ajustes do Sistema › Privacidade e Segurança** e clique em **Abrir Mesmo Assim**. Se preferir o Terminal: `xattr -dr com.apple.quarantine /Applications/RonicMacToWindows.app`.
3. Autorize a **Acessibilidade**: em **Ajustes do Sistema › Privacidade e Segurança › Acessibilidade**, ative **RonicMacToWindows**. O próprio app abre esse painel. A captura começa sozinha assim que você autoriza, sem precisar reabrir o app.
4. Pronto. O ícone **R** aparece na barra superior, no canto direito.

> **Atualizou o app e os atalhos pararam?** Cada versão é um binário novo, e o macOS passa a tratá-la como outro app. Em **Acessibilidade**, remova o RonicMacToWindows (botão **–**) e adicione de novo. Também dá para rodar `tccutil reset Accessibility io.github.jhowmael.ronicmactowindows` e abrir o app.

## Atalhos

Nesta tabela, **Alt = Option (⌥)** e **Win = Command (⌘)**. É assim que o macOS lê um teclado de PC.

### Edição (Ctrl → ⌘)

| Windows | Vira no Mac | Ação |
|---|---|---|
| Ctrl+C / Ctrl+X / Ctrl+V | ⌘C / ⌘X / ⌘V | Copiar / recortar / colar |
| Ctrl+Shift+V | ⌥⇧⌘V | Colar sem formatação (quando o app suporta) |
| Ctrl+Z / **Ctrl+Y** | ⌘Z / **⇧⌘Z** | Desfazer / refazer |
| Ctrl+A / Ctrl+S / Ctrl+F | ⌘A / ⌘S / ⌘F | Selecionar tudo / salvar / buscar |
| Ctrl+N / Ctrl+T / Ctrl+W | ⌘N / ⌘T / ⌘W | Nova janela / nova aba / fechar aba |
| Ctrl+P / Ctrl+L | ⌘P / ⌘L | Imprimir / barra de endereço |
| Ctrl+O / R / B / I / U / K | ⌘O / R / B / I / U / K | Abrir, recarregar, negrito, itálico, sublinhado, link |
| Ctrl+= / Ctrl+- / Ctrl+0 | ⌘= / ⌘- / ⌘0 | Zoom |
| Ctrl+Shift+T, Ctrl+Shift+N… | ⇧⌘T, ⇧⌘N… | O Shift é preservado |

### Navegação de texto

| Windows | Ação |
|---|---|
| Home / End | Início / fim da linha (com **Shift**, seleciona) |
| Ctrl+Home / Ctrl+End | Início / fim do texto |
| Ctrl+← / Ctrl+→ | Pular palavra (com **Shift**, seleciona) |
| Ctrl+Backspace / Ctrl+Delete | Apagar palavra à esquerda / à direita |

> Home/End usam ⌃A/⌃E (início/fim do parágrafo no Cocoa) em vez de ⌘←/⌘→. Assim, apertar Home numa página web não vira **Voltar** no navegador.

### Janelas e sistema

| Windows | Ação |
|---|---|
| **Alt+Tab** | Seletor de apps estilo Windows. Segure Alt e aperte Tab (Shift+Tab ou ←/→ para voltar). Solte Alt para trocar, ou aperte Esc para cancelar. Um toque rápido troca direto para o app anterior. |
| Alt+F4 | Encerra o app ativo (⌘Q, então o app ainda pergunta se quer salvar) |
| **Win+L** | Bloqueia a tela |
| **Win+D** | Mostra a área de trabalho (aperte de novo para voltar) |
| Print Screen | Abre a ferramenta de captura de tela (como ⇧⌘5) |
| Ctrl+Shift+Esc | Abre o Monitor de Atividade (o "Gerenciador de Tarefas") |

**Não é afetado:** a digitação de acentos e caracteres especiais (´ ~ ^ ` ç, Option+letra) e os seus atalhos ⌘ nativos. O ⌘C continua funcionando. As exceções são ⌘L e ⌘D, que viram Win+L e Win+D. Para usá-los como no Mac, desligue o grupo **Tecla Win** no menu.

## Menu na barra superior

| Item | O que faz |
|---|---|
| **Pausar / Ativar remapeamento** | Desliga a captura de teclado por completo (custo zero) e liga de novo. O ícone fica apagado quando pausado. |
| **Acessibilidade** | Mostra se a permissão foi concedida e tem um botão que abre os Ajustes. |
| **Atalhos** | Liga e desliga cada grupo: Edição, Navegação de texto, Janelas, Tecla Win. |
| **Apps ignorados** | **Ignorar "App atual"** com um clique, **Adicionar app…** escolhendo um .app, clique num item para remover, **Restaurar padrões**. |
| **Sair** | Encerra o app (⌘Q com o menu aberto). |

### Apps ignorados

Nos apps ignorados, o **Control original é preservado**, porque terminais precisam de Ctrl+C para interromper processos. Nesses apps, Edição e Navegação de texto ficam desligadas. Alt+Tab, Alt+F4, Win+L etc. continuam valendo.

Já vêm ignorados: Terminal, iTerm2, Warp, Ghostty, kitty, Alacritty, WezTerm, Windows App (Área de Trabalho Remota), Parallels, VMware Fusion e UTM.

## Dicas

* **Teclado do Mac na posição do PC.** No teclado do Mac, a ordem perto da barra de espaço é Control, Option, Command. No PC, é Ctrl, Win, Alt. Se quiser o **Alt colado na barra de espaço**, como no Windows, troque Option e Command em **Ajustes do Sistema › Teclado › Atalhos de Teclado › Teclas Modificadoras**.
* **Alt+F4 em teclados de Mac.** As teclas F1–F12 do Mac são de mídia por padrão. Use **fn+Alt+F4** ou ative "Usar F1, F2 etc. como teclas de função padrão" em **Ajustes › Teclado**.
* **Print Screen** em teclados de PC chega ao Mac como **F13**, e é essa tecla que o app escuta.
* **Ctrl+←/→** no macOS normalmente troca de Space (mesa). O app intercepta o atalho antes, então ele passa a pular palavras. Em apps ignorados, o comportamento do Mac volta.

---

## Como funciona

```
 teclado ──▶ CGEventTap (nível HID, thread própria) ──▶ macOS/atalhos globais ──▶ app ativo
                 │  lê 1 snapshot (lock de ~20 ns): ativo? app ignorado? grupos?
                 │  reescreve keyCode + flags do PRÓPRIO evento e devolve (sem criar eventos)
                 └─ Alt+Tab, Win+L, Win+D, PrtSc: só enfileira a ação na main thread
```

* **Swift nativo + Quartz.** Sem Electron, sem WebView. O binário tem cerca de 1,5 MB.
* **O callback faz só comparações de inteiros:** keyCode e flags. Não faz I/O, não grava log, não aloca memória nem mexe em UI. Custa cerca de 0,12 µs por tecla, medido.
* **Thread dedicada** (QoS *userInteractive*) com o próprio CFRunLoop. Se a interface estiver ocupada, a digitação não sofre atraso.
* **Tap no nível HID:** a reescrita acontece antes dos atalhos globais do macOS. É por isso que Ctrl+← vira ⌥← em vez de trocar de Space.
* **O keyUp segue o keyDown:** se você soltar o Ctrl antes da letra, a tecla não fica "presa" no app.
* **Reativação automática:** se o macOS desligar o tap por timeout, ele é religado na hora.
* **Cache do app ativo:** o app guarda o bundle ID atualizado por notificação do NSWorkspace. Não há polling.
* **Alt+Tab carregado sob demanda:** a lista de apps e os ícones são montados só quando você aperta Alt+Tab e descartados ao soltar.

## Estrutura do repositório

```
.
├── Package.swift                         Swift Package (macOS 14+)
├── Resources/
│   ├── Info.plist                        LSUIElement = true (sem Dock), bundle id, versão
│   └── AppIcon.icns                      gerado por branding/make-icons.sh
├── Sources/RonicMacToWindows/
│   ├── main.swift                        ponto de entrada (.accessory)
│   ├── App/
│   │   ├── AppDelegate.swift             instância única; sem Login Items
│   │   ├── AppController.swift           liga as peças; permissão; estado do tap
│   │   └── StatusMenuController.swift    ícone + menu da barra superior
│   ├── Core/
│   │   ├── RemapEngine.swift             CGEventTap + regras de remapeamento (caminho quente)
│   │   ├── KeyCodes.swift                keyCodes e máscaras de modificadores
│   │   ├── SharedState.swift             snapshot thread-safe lido pelo tap
│   │   └── Settings.swift                preferências (grupos, apps ignorados)
│   ├── Services/
│   │   ├── FrontmostAppTracker.swift     app ativo + ordem de uso (MRU)
│   │   ├── AccessibilityPermission.swift status/pedido da permissão
│   │   └── SystemActions.swift           bloquear tela, mostrar mesa, captura, Monitor de Atividade
│   └── Switcher/
│       ├── AppSwitcher.swift             lógica do Alt+Tab
│       └── SwitcherPanel.swift           painel flutuante com os ícones
├── branding/                             logo gerado por código + script de ícones
├── scripts/package-macos.sh              gera o .app e o .zip
└── .github/workflows/release.yml         publica o download ao criar uma tag
```

## Compilar a partir do código

Pré-requisito: **Xcode ou Command Line Tools** (Swift 5.9+), em macOS 14+.

```bash
git clone https://github.com/jhowmael/Ronic-MacToWindows.git
cd Ronic-MacToWindows

make app       # → dist/RonicMacToWindows.app + dist/RonicMacToWindows-macOS.zip
make install   # gera e copia para /Applications
make icons     # regenera o logo e o AppIcon.icns
```

### Testar

1. `make install`, depois abra **RonicMacToWindows** em Aplicativos (ou rode `open /Applications/RonicMacToWindows.app`).
2. Autorize a Acessibilidade. O ícone da barra deixa de mostrar o ⚠️.
3. No **TextEdit** ou nas **Notas**: digite um texto e teste Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+Z, Ctrl+Y, Home/End, Shift+Home, Ctrl+←/→ e Ctrl+Backspace.
4. Digite acentos (á, ã, ç, ê) e confira que nada mudou.
5. Teste Alt+Tab com 3 ou mais apps abertos, Win+D duas vezes e Ctrl+Shift+Esc.
6. No **Terminal**, rode `sleep 100` e aperte **Ctrl+C**. O processo deve ser interrompido, porque o Terminal é ignorado por padrão.
7. Pelo menu, teste **Pausar**, desligar um grupo, **Ignorar "app atual"** e **Sair**.

> **Recompilou?** Uma assinatura ad-hoc nova invalida a permissão anterior. Rode `make reset-permission` e autorize de novo. Para não precisar repetir isso a cada build, assine sempre com o mesmo certificado: `SIGN_IDENTITY="Nome do certificado" make app`. Serve até um certificado autoassinado criado no **Acesso às Chaves › Assistente de Certificado**, do tipo *Assinatura de Código*.

## Publicar uma nova versão

```bash
git tag v1.0.0
git push origin v1.0.0
```

O workflow [release.yml](.github/workflows/release.yml) compila o app universal (Apple Silicon + Intel) e cria o Release com `RonicMacToWindows-macOS.zip`. O botão de download deste README aponta sempre para a versão mais recente.

**Para distribuir sem avisos de segurança (opcional):** assine com *Developer ID* e faça a notarização: `SIGN_IDENTITY="Developer ID Application: …" ./scripts/package-macos.sh`, depois `xcrun notarytool submit …`.

## Limitações conhecidas

* **Campos de senha:** quando um campo seguro está em foco, o macOS bloqueia a interceptação de teclado. Nesses campos, os atalhos do Mac (⌘C, ⌘V) continuam valendo.
* **Home/End em textos com quebra automática** vão ao início e ao fim do *parágrafo*, não da linha visual.
* **Alt+Tab** alterna entre apps, como o ⌘Tab, e não entre janelas individuais.
* **Layouts não QWERTY** (Dvorak, Colemak): os atalhos seguem a posição física das teclas QWERTY/ABNT2.
* **Win+L e Win+D** usam APIs internas do macOS. Se a Apple remover essas APIs, o app usa um plano B: ⌃⌘Q para bloquear e ocultar os apps para mostrar a mesa.
* **Não está na Mac App Store**, porque o sandbox da loja não permite CGEventTap que modifica eventos.

## Licença

Defina a licença do projeto antes de distribuir (por exemplo, MIT).
