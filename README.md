# Quadra

Encaixe de janelas para macOS, no estilo do Windows (Win + setas) e do PowerToys FancyZones.

| Atalho | Ação |
|---|---|
| ⌃⌘← | Janela ativa ocupa a metade esquerda da tela |
| ⌃⌘→ | Janela ativa ocupa a metade direita da tela |
| ⌃⌘→ de novo (já na metade direita) | Vai para a metade esquerda do monitor à direita (idem para ←) |
| ⇧ enquanto arrasta uma janela | Mostra as zonas do layout; soltar o mouse encaixa a janela na zona destacada |
| ⇧ + soltar perto da divisa entre zonas | A janela ocupa as duas zonas (perto de um canto da grade, as quatro) |

Cada monitor tem suas próprias zonas (menu da barra › *Zonas por monitor* › nome do monitor):

- **Layout**: 2/3/4 colunas, 2/3 linhas, grade 2×2 e 3×2, foco central (25 | 50 | 25).
- **Espaço entre zonas**: sem espaço (padrão), 4, 8, 16 ou 24 pt — vale também para a borda da tela.

A faixa de junção é 10% do tamanho da zona a partir da borda compartilhada (numa coluna de 850 pt, os últimos ~85 pt de cada lado da divisa).

**Dock**: as janelas respeitam o Dock só no monitor em que ele está agora; nos outros, e quando ele se oculta automaticamente, usam a altura toda. O monitor do Dock é detectado pela janela do próprio Dock, porque o `visibleFrame` do macOS pode continuar reservando o lugar antigo depois que o Dock muda de tela.

Apps com tamanho mínimo maior que a zona (o Outlook não fica com menos de ~810 pt de largura) são empurrados de volta para dentro da tela, mantendo a borda que encosta na lateral do monitor.

Ao escolher, as zonas piscam no monitor alterado. As configurações ficam salvas pelo UUID do monitor, então sobrevivem a reinícios e a desconectar/reconectar.

## Por que ⌃⌘ + setas

O macOS 15+ já tem tiling nativo em **🌐⌃ + setas** (menu *Janela › Mover e Redimensionar*), e ⌃ + setas troca de Espaço. ⌃⌘ + setas não é usado pelo sistema. Alguns apps usam (o Xcode navega para trás/frente com ⌃⌘←/→); o atalho global do Quadra tem prioridade enquanto ele estiver aberto.

## Como funciona

- **Atalhos**: `RegisterEventHotKey` (Carbon) — global e sem precisar de permissão.
- **Mover/redimensionar**: API de Acessibilidade (`AXUIElement`, atributos `AXPosition`/`AXSize`). Exige a permissão em *Ajustes do Sistema › Privacidade e Segurança › Acessibilidade*.
- **Arrastar com ⇧**: monitores globais de `NSEvent` só observam o mouse. Ao clicar, o Quadra identifica a janela sob o cursor; se ela se mover sem mudar de tamanho, é um arrasto de barra de título. Com ⇧ pressionado, um painel transparente (que deixa os cliques passarem) desenha as zonas sobre a tela.

## Desenvolvimento

Requer Xcode e [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). O `.xcodeproj` é gerado a partir de `project.yml`.

```sh
make run       # gera o projeto, compila (Debug) e abre o app
make test      # testes da geometria (layouts, metades, conversão de coordenadas)
make install   # compila Release e instala em /Applications
```

O app é assinado com um certificado Apple Development (`DEVELOPMENT_TEAM` em `project.yml`). Assinar sempre com a mesma identidade mantém a permissão de Acessibilidade entre builds; com assinatura ad-hoc seria preciso conceder de novo a cada compilação.
