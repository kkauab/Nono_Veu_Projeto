# Caderno de pausa — v8

O menu de pausa da versão principal agora é o caderno inteiro. Esc abre na página de Senu; as abas laterais acessam personagem, missões, mapa, Emanações, inventário, configurações e saída. Esc fecha o caderno; na página Controles, retorna primeiro às configurações. Preferências abertas pela capa retornam à capa. N abre Missões diretamente e as abas continuam acessíveis por mouse; N fecha essa página. Missões separa a jornada principal dos pedidos secundários dos moradores.

## Senu

A página principal utiliza as texturas e o renderizador de sprites da partida (`senu_supplied_view.gd`), com a arma equipada. Não usa a ilustração de personagem gerada durante a proposta. A prévia é um ator visual sem corpo físico, grupo de jogador, dano ou acesso à gravação. Ataque, esquiva e aparo demonstram os clipes reais sem mover ou ferir o personagem no mundo.

Atributos são números reais da sessão: vida máxima, dano da arma com os bônus atuais, velocidade e proteção de Pele de Alabastro quando aprendida. O equipamento exibido corresponde ao que Senu está usando; não há escudos ou acessórios fictícios para preencher o esboço.

## Inventário

Slots selecionáveis e filtros para Todos, Armas, Itens, Fragmentos e Chaves. A página lista armas descobertas, compras reais, cargas, objetos de missão ainda não entregues, selos e Nous disponíveis. Selecionar mostra imagem, descrição, estatísticas e situação do item. Armas podem ser equipadas; melhorias passivas são identificadas como ativas. Slots vazios não representam itens não encontrados.

Imagens de armas vêm dos cels de equipamento do próprio Senu (`senu_shared_v6.png`); objetos reutilizam os sprites do cenário. Não foram criados novos desenhos de equipamentos. A página não adiciona armas ou funções de descarte inexistentes no jogo.

## Emanações

Selecionar um dos 13 nós mostra seu efeito, custo e requisitos. Para aprender, é necessário manter o botão pressionado por **1,5 segundo**, com mouse ou Enter/Espaço. Soltar, mudar de nó ou sair da página cancela. Requisitos e saldo são verificados durante a confirmação; uma pressão longa conclui no máximo uma compra. O efeito entra em vigor na sessão imediatamente.

## Configurações e progresso

Controles é uma página dentro de Configurações. A pausa não tem opção Salvar nem Salvar e sair. Sair e fechar a janela não gravam a jornada. Coletas, compras, melhorias e missões continuam em memória; **somente a interação com uma torre de salvamento grava progresso**. Preferências de janela e taxa de quadros são independentes do save da jornada.

Regras e compatibilidade de gravação estão em [SALVAR_NAS_TORRES.md](SALVAR_NAS_TORRES.md). O último arquivo ancorado e os backups existentes são preservados ao criar uma jornada nova até que sua primeira torre seja usada.

## Conferência

- `pause_notebook_test.gd`: navegação das páginas, prévia isolada e retorno à capa/jogo.
- `inventory_book_test.gd`: conteúdo real, bônus, filtros e sprites.
- `skill_book_test.gd` e `skill_book_integration_test.gd`: duração, cancelamento, débito único, efeitos e eventos reais de mouse/teclado.
- `tower_only_save_test.gd` e `enemy_respawn_test.gd`: bytes do arquivo e descanso nas torres.
- `pause_notebook_preview.gd`: capturas das páginas em 1280×720 e do inventário em 960×540, somente com dados de QA.

O mapa usa os contornos reais das áreas visitadas e conexões abertas, com miniaturas do atlas como marcos. As abas não revelam segredos ou concedem progresso por leitura.

Os textos respeitam a área interna do papel, com margens livres dos ornamentos e palavras inteiras. Lista e detalhes de Missões usam rolagem independente; as abas e o fechamento ficam acima das páginas incorporadas.
