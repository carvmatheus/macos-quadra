# Handoff: EQ do Mac no iPhone + dois áudios ao mesmo tempo no iOS

> Status: pesquisa concluída, nada implementado. Data: 2026-11-18.
> Não tem relação com o código do Quadra; este repo só guarda o plano.

## Objetivo

1. Reaproveitar no iPhone os perfis de EQ criados no Mac com o
   [macos-parametric-eq](https://github.com/dylenq/macos-parametric-eq) (v0.6.0).
2. Ouvir dois áudios ao mesmo tempo no iPhone (ex.: vídeo do YouTube + música),
   no estilo do Sound Assistant da Galaxy Store.

## O que já foi descoberto

### O EQ do Mac
- É um EQ paramétrico para o sistema inteiro, que usa o process tap do macOS 14.2+.
  Tem até 16 bandas (peak, low/high shelf, low/high pass), preamp, bass/treble/balance
  e um modo gráfico.
- Importa AutoEq / Equalizer APO (`ParametricEQ.txt`).
- Guarda o estado em `~/Library/Application Support/eq/` (`state.json`).
  **O formato dos presets ainda não foi inspecionado.**

### Limites do iOS (versão atual: iOS 27.2.1, de 09/11/2026; 27.3 em beta 2)
- **Não existe EQ para o sistema inteiro feito por terceiros.** Não há process tap nem
  driver virtual. O sandbox impede que um app leia ou altere o áudio de outro app.
- **Dois apps não tocam juntos se ambos pedem áudio exclusivo.** O controle de
  sessões de áudio do iOS (AVAudioSession) faz o YouTube pausar o Spotify e o
  contrário. Só o próprio app escolhe ser "misturável" (`.mixWithOthers`); ninguém
  muda essa regra por outro app.
- Mudar a saída (AirPlay, Bluetooth) **não** contorna essa regra. O iPhone também não
  manda AirPlay para si mesmo nem deixa um app se anunciar como receptor.
- Brechas descartadas: ReplayKit Broadcast Extension (só copia o áudio; o original
  continua tocando e o DRM fica mudo), Audio Units/Inter-App Audio (só entre apps
  que aceitam; o IAA foi removido), VPN local (o stream chega criptografado),
  SDKs de Spotify/MediaPlayer (só controlam a reprodução), APIs privadas e jailbreak.
- **Novidade do iOS 27:** os AirPods ganharam um EQ personalizado nativo, com ajuste
  manual das frequências. Ainda não verificado: número de bandas, se tem Q e se
  aceita valores digitados.

## Plano (em ordem de prioridade)

### Job 1: Perfis do Mac → EQ nativo dos AirPods (iOS 27)
- [ ] Confirmar quais AirPods são suportados, quantas bandas o EQ tem, as frequências
      fixas e os limites de ganho e Q.
- [ ] Ler o formato dos presets em `~/Library/Application Support/eq/`.
- [ ] Escrever um conversor: perfil paramétrico → bandas fixas do EQ dos AirPods
      (calcular a curva de resposta somada e amostrar nas frequências dos AirPods,
      com o preamp).
- [ ] Saída: uma tabela "banda → dB" para digitar no iPhone. Se houver import ou
      Atalhos, automatizar.
- Pronto quando: um perfil do Mac reproduzido no iPhone com erro ≤ ~1 dB nas bandas.

### Job 2: Player de YouTube "misturável" (único com chance de App Store)
- [ ] Protótipo de ~50 linhas: app SwiftUI com `AVAudioSession` em `.playback` +
      `.mixWithOthers` e um `WKWebView` com o player oficial do YouTube (IFrame API).
- [ ] **Teste decisivo:** com o Spotify ou o Deezer tocando, o vídeo toca sem pausar a música?
      Se o WebKit ignorar a configuração da sessão do app, a ideia morre aqui.
- [ ] Se passar: controle de volume do vídeo em relação à música e o EQ dos perfis
      do Mac aplicado no que for possível.
- Regras do YouTube: usar só o player incorporado; **não** remover anúncios, tocar com
  a tela bloqueada nem baixar vídeos.
- Antes de investir: procurar na App Store apps que já fazem isso.

### Job 3: Hack pessoal via Spotify Connect (fora da App Store)
- Ideia: um app no iPhone que se anuncia como aparelho Spotify Connect usando o
  [librespot](https://github.com/librespot-org/librespot). O Spotify baixa a
  música direto dos servidores, o iPhone vira só o controle remoto e o app toca a
  música em modo misturável, com EQ. O YouTube toca normalmente por cima.
- [ ] Compilar o librespot para iOS (Rust → staticlib) e ligá-lo a um app SwiftUI.
- [ ] Verificar se o iOS mantém o app ativo em segundo plano por muito tempo.
- Riscos: viola os termos do Spotify (só para uso pessoal, instalado pelo Xcode), exige Premium,
  pode quebrar quando o Spotify mudar o protocolo.
- **Deezer:** existe o [pleezer](https://docs.rs/crate/pleezer/0.13.0) (receptor
  Deezer Connect, Rust, feito para Linux). Descartado: o backend do Connect pode ter sido desligado
  (o status atual não foi confirmado) e ele exige uma chave de descriptografia obtida pelo próprio
  usuário. Não vamos seguir por esse caminho.

## Alternativas de hardware (para registro)
- Dongle ou DAC com EQ paramétrico embutido (Qudelix 5K, alguns FiiO e Moondrop):
  vale para o sistema todo, inclusive streaming. O software seria só um conversor de perfis.
- AirPlay para um Mac ou Raspberry Pi (shairport-sync + CamillaDSP) com o mesmo perfil:
  pega todos os apps, mas só em casa.

## Notas de distribuição iOS
- Apple ID gratuito + Xcode: o app expira em 7 dias.
- Conta de desenvolvedor (US$ 99/ano): 1 ano, TestFlight e App Store.

## Fontes
- iOS 27: https://en.wikipedia.org/wiki/IOS_27
- Apple Developer Releases: https://developer.apple.com/news/releases/
- Guia do iOS 26 (Macworld): https://www.macworld.com/article/2575705/ios-26-features-latest-update-release-date-beta.html
- Apple Community (dois áudios): https://discussions.apple.com/thread/252612052
- Áudio múltiplo no iPhone (Hollyland): https://store.hollyland.com/blogs/creator-hub/use-multiple-audio-sources-on-iphone
- pleezer: https://docs.rs/crate/pleezer/0.13.0
- Status do Deezer Connect: https://www.diyaudio.com/community/posts/6848570 , https://moodeaudio.org/forum/showthread.php?pid=63970
