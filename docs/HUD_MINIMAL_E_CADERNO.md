# HUD minimalista e caderno de missões

Aplicado na versão principal `D:\Nono_Veu`.

## Interface durante a partida

O símbolo solar, as letras serifadas, o ouro envelhecido e o fundo escuro preservam a identidade de O Nono Véu. Os painéis grandes e as molduras duplas saíram da interface de exploração. Vida usa uma faixa vermelha; a linha fina abaixo continua mostrando XP, sem criar uma barra de energia inexistente no jogo. Vida numérica, nível, óbolos, Nous, arma, poderes e bálsamos permanecem disponíveis.

Somente o nome da área fica no alto à direita, com um pequeno marcador vertical. O objetivo da jornada e os selos ficam em Missões no caderno, sem acompanhamento fixo no HUD. Avisos de interação e mensagens temporárias têm borda simples. A faixa de comandos de movimento foi removida, inclusive a antiga opção que poderia reativá-la. Os comandos podem ser consultados no menu de pausa.

## Caderno

**N** abre e fecha o caderno; ele também está na pausa. As páginas ficam sobre couro escuro e papiro claro. À esquerda, a seção Principais registra a travessia pelo Porto e a seção Secundárias reúne os pedidos conhecidos dos moradores. À direita, o conteúdo da missão selecionada flui com rolagem: nome, morador, próximo passo, anotação, objetivos e recompensa quando houver. Mouse, setas e rolagem permitem consultar páginas longas. Os marcadores refletem os itens, lugares visitados e conclusões reais do save.

As abas abrem Missões, Mapa, Inventário e Emanações. **Esc / Voltar** segue a navegação do HUD. Ler ou trocar uma página não conclui missões nem concede recompensas. Uma partida sem pedidos conhecidos mostra orientação em páginas vazias.

Textos são controles nativos do Godot e usam o tamanho final da janela, sem ampliar letras rasterizadas em baixa resolução. Fundo ilustrado e texto são separados. As capturas de conferência incluem 960×540 e 1280×720.

## Arquivos

- `scripts/ui/game_hud_v6.gd`: HUD e integração do menu existente.
- `scripts/ui/quest_journal_book.gd`: páginas, seleção e visualização do progresso.
- `assets/ui/quest_journal_v1.png`: fundo de couro e papiro criado com ImageGen.
- `assets/ui/hud_journal.svg`: ícone do caderno no estilo dos demais ícones.
- `tests/journal_book_test.gd`: navegação, estados e legibilidade por tamanho.
- `tests/hud_minimal_preview.gd`: capturas do jogo usando somente progresso de QA.

Testes de referência: HUD, caderno, missões dos NPCs e árvore de habilidades. A conferência visual é necessária além dos testes de funcionamento.

## Conversas na exploração

Conversas comuns usam balões junto ao personagem que fala, com até quatro linhas por trecho. E, Espaço, Enter ou o botão Continuar avançam; Esc fecha. O nome fica separado da fala; ações narradas e anotações usam cartões sem apontar para um falante. A abertura mantém sua encenação e inscrições continuam no leitor de textos.
