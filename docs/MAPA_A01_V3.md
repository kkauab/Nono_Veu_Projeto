# Porto dos Esquecidos — expansão da exploração

Revisão do mundo 3, implementada em 25/10/2026. O porto possui **27 setores, 4.346 pisos caminháveis, 37 inimigos comuns e um chefe**, além de cinco âncoras de descanso. O núcleo anterior foi preservado e recebeu três distritos de exploração; a entrada da arena agora depende de três selos.

## Rota e distritos

O núcleo Santuário → Cais → Mercado → Armazém → Ponte → Pátio → Jardim → Guarita continua reconhecível. Da Guarita, a Porta das Três Lembranças bloqueia fisicamente a arena. A saída do chefe para as Catacumbas continua sendo outro portão, liberado pela derrota do Porteiro.

| Distrito | Setores novos | Função |
|---|---|---|
| Norte | Pátio dos Escribas, Arquivo dos Nomes Velados, Praça dos Três Sinos, Escadaria dos Peregrinos | Encontrar a inscrição da Voz e executar sua sequência; loop entre Santuário e Mercado. |
| Leste | Portão das Caravanas, Fornos de Bronze, Estrada do Sal, Terraço do Farol, Observatório, Reservatório, Cais do Cobre | Encontrar a orientação celeste, alinhar os obeliscos e retornar pelo Embarcadouro. |
| Sul | Cisterna das Duas Fontes, Galeria das Comportas, Santuário Soterrado | Entender as fontes, preparar a oferenda da Maré e conferir o altar distante. |

Mercado e Guarita mantêm suas âncoras. Caravanas e Cisterna acrescentam descanso nos distritos novos. Cinco fragmentos adicionais ficam em desvios; os três selos também concedem um fragmento único cada. As memórias dos Peregrinos e do Cais do Cobre indicam os loops de retorno. O relicário das duas testemunhas continua opcional.

## Três puzzles obrigatórios

**Voz:** a inscrição está no Arquivo, separada dos sinos. Ela indica Lua → Aurora → Estrela. Uma nota errada reinicia somente a sequência; nada é consumido. A leitura da inscrição é necessária para reconhecer o selo.

**Maré:** a inscrição está na Cisterna. As duas fontes da Galeria acrescentam 2 e 3 marcas, uma utilização de cada até o reinício. O dreno remove uma marca. O altar do Santuário Soterrado pede nível 4 e a contribuição das duas fontes. O estado correto é 2 + 3 − 1. A válvula **Recircular**, na parte leste da Galeria, zera o nível e rearma ambas; drenar até zero também rearma. Não há estado parcial sem recuperação.

**Céu:** o Farol registra Sol → Leste, Lua → Oeste, Olho → Sul. No Observatório, cada interação gira um obelisco em um quarto de volta. O altar confere o alinhamento. Orientações incorretas ficam disponíveis para correção; não há punição nem perda de recursos.

Inscrições lidas, notas, fontes utilizadas, nível da água, orientações e selos persistem. O jogador pode morrer, sair e voltar sem perder uma descoberta. Um save antigo com o Porteiro derrotado mantém a entrada aberta e não recria o chefe.

## Encontros e circulação

Os novos encontros distribuem quatro perfis: guardas equilibrados, corredores frágeis e rápidos, lanceiros com alcance maior e guardiões resistentes com preparação longa. A arena preserva os dois padrões do Porteiro. A navegação inimiga usa um grafo compartilhado dos pisos caminháveis para contornar as aberturas de água, com desvio local diante dos objetos sólidos.

A decoração fica nas margens e deixa livres mecanismos, pontos de partida dos inimigos e âncoras. Poços centrais na Cisterna e no Reservatório criam caminhos ao redor da água. O piso, a água e os objetos usam as imagens do porto por `port_art.gd`; a arte não altera as colisões do layout.

O objetivo de projeto é uma expedição mais longa, com pistas, encontros e retornos reconhecíveis. A duração e a dificuldade ainda precisam de uma partida humana; não foi medido um tempo de conclusão de jogador.

## Verificação

`world_v6_test.gd -- --qa` aprovou **124 verificações** e percorreu os mecanismos das três alas usando **2.457 passos de física dirigidos pelas ações reais de movimento**, sem teleportar entre os objetivos dessa expedição. Antes do percurso, 28 fixtures de estado parcial da cisterna foram reposicionadas apenas para testar a interação de recirculação. O teste também verifica falta de bypass da arena, conectividade de todos os pisos, acesso a cada encontro comum, respostas erradas, leitura de pistas, checkpoint e recarga do save.

O percurso anterior passou em **121/121**, com uma fixture explícita de três selos já reconhecidos para isolar sua navegação antiga. Migração/menu/relicário passou em **31/31**, persistência/progressão em **111/111** e combate em **26/26**. Os slots são isolados em `user://qa/`; o progresso real não foi usado. Esses testes não substituem avaliação humana de arte, sensação de controle ou balanceamento.

`navigation_v6_test.gd` aprovou **8/8** verificações: os quatro perfis de inimigo percorrem fisicamente a borda da piscina da Cisterna, permanecem no piso e chegam à preparação de ataque contra um alvo do outro lado. Não atravessam o buraco de água nem ficam presos na recentralização dos pontos do grafo.
