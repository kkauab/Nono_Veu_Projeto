> Registro histórico do primeiro protótipo. A abertura atual é a cena de RPG descrita em [ABERTURA_RPG_V11.md](ABERTURA_RPG_V11.md).

# Abertura animada — A margem da Inversão

Abertura de 21 segundos encenada em tempo real com os pixels, o barco, a arquitetura e os passos de Senu já usados pelo jogo. Não foi gerado um vídeo nem uma nova ilustração. A montagem e as animações são do Godot; as artes reutilizadas têm seus projetos editáveis no Pixelorama.

## Roteiro e movimento

| Tempo | Plano | Ação |
|---|---|---|
| 0–6 s | Alexandria, à margem do Nilo | Panorama do porto; correnteza, reflexos, capa e faixa recebem movimento em pixels. A legenda situa o efeito da Inversão. |
| 6–14 s | Porto dos Esquecidos | O barco se aproxima do cais, é amarrado, uma prancha é baixada e Senu desembarca com os quadros reais de caminhada. A legenda explica o ataque à ordem e a busca por Iri. |
| 14–21 s | Santuário da Primeira Palavra | Senu caminha pelo pátio, para diante da inscrição e a glifa se acende. A luz e as chamas continuam animando, ligando o prólogo ao início da exploração. |

As legendas são texto original baseado nas premissas de `docs/O_NONO_VEU_GDD.md`, seções 3.1 e A01: Alexandria, Inversão, discípulo de Hermes, Iri desaparecido e marinheiros sem memória. Não apresentam o porto físico como se já estivesse no Reverso nem antecipam o chefe.

## Regra de reprodução

A abertura é destinada ao fluxo obrigatório de Nova jornada. Seu componente não possui botão de pular. Esc e cliques são consumidos; um toque em Espaço não a encerra. É necessário manter **Espaço pressionado continuamente por 3 segundos**, acompanhado por barra de progresso. Soltar a tecla ou perder o foco da janela cancela o progresso. O fim natural e o salto emitem o mesmo sinal uma única vez.

O componente usa `PROCESS_MODE_ALWAYS`, mantendo somente sua encenação ativa enquanto a árvore do jogo está pausada. O Senu da abertura é um ator separado, sem colisão e fora do grupo `player`, de modo que a filmagem não desloca, danifica ou altera o jogador real.

## Integração e arquivos

- Componente: `scripts/ui/opening_cutscene.gd`.
- API: `begin()`, sinal `finished`, `DURATION = 21.0`, `elapsed`, `seek(seconds)` para captura e teste.
- O fluxo do jogo deve ocultar o HUD e o mundo real, pausar sua física e restaurá-los após `finished`. A persistência e a chamada obrigatória pertencem a `port_demo.gd`, e não ao componente visual.
- Capturas: `qa/opening_v9_river.png`, `opening_v9_boat.png`, `opening_v9_landing.png`, `opening_v9_sanctuary.png`.
- Ferramenta de captura: `tools/qa/capture_opening_v9.gd`.
- Teste do componente: `tests/opening_cutscene_v9_test.gd`; registro `qa/opening_v9_test.log`.

O teste verifica barco em deslocamento, desembarque com passos, chegada ao altar, reprodução durante pausa, Esc ignorado, liberação de Espaço antes do tempo, cancelamento ao perder foco, salto somente após 3 s, emissão única e conclusão natural.
