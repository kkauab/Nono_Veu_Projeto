# NPCs, interiores e missões — v2

Hori, Sabu, Merit, Nakht, Adiam e Tarek receberam novos sprites com quatro poses completas: repouso, respiração, piscada e gesto. Os pés mantêm o mesmo apoio; a animação não aumenta nem diminui a imagem. A sequência de repouso intercala as poses, evitando gestos constantes.

Os quatro interiores receberam móveis novos, sombras de contato, tapetes e detalhes nas paredes. A forja tem três quadros de fogo. Colisões, portas e ordenação dos objetos continuam sendo verificadas pelos testes existentes.

## Como jogar

- Pressione **N** para abrir o Caderno de Missões, também disponível na pausa.
- Nas lojas, use **Conversar · missão**. Tarek pode ser abordado na Casa da Guarda.
- Objetos encontrados antes de aceitar uma missão ficam registrados e podem ser entregues depois.

| Personagem | Missão | Objetivo | Recompensa |
|---|---|---|---|
| Merit | O perfume que ficou | Recuperar a mirra no Jardim Inundado | 30 óbolos |
| Nakht | Bronze que canta | Recuperar a tenaz nos Fornos do Bronze | 40 óbolos |
| Adiam | Cartografia das margens | Visitar o Aqueduto e o Terraço do Farol Partido | 25 óbolos |
| Tarek | O último turno | Recuperar a escala no Arquivo dos Nomes Velados | 35 óbolos |

## Os irmãos

Encontre Sabu, retorne a Hori para receber o cordão, mostre o nó a Sabu, toque a sineta do embarcadouro e fale novamente com Sabu. Depois, volte a Hori para concluir o reencontro e receber os dois fragmentos de Nous. Essa sineta é independente do puzzle dos três sinos.

Encontrar Sabu antes de conhecer Hori também funciona. Derrotar o chefe não é mais necessário para concluir a missão. Estados antigos da missão continuam reconhecidos, sem repetir a recompensa. O caderno informa a próxima ação.

## Arte e manutenção

O projeto editável é `art/pixelorama/interiors_v2/interiors_v2.pxo`. Abra com **ABRIR_INTERIORES_PIXELORAMA.cmd** e exporte com **EXPORTAR_INTERIORES.cmd**.

O atlas tem 45 quadros de 128×144, paleta de 33 cores e transparência binária. Os sprites usam filtro nearest e apoio fixo em (64,112); os personagens têm altura máxima de 44 pixels no mundo.

As bases foram geradas com ImageGen, preparadas em baixa resolução pelo construtor nativo e exportadas pelo Pixelorama. Não foram desenhadas manualmente na interface do aplicativo. As fontes ficam na pasta `sources`, excluída da importação do Godot.

O padrão reutilizável dos efeitos de morte e moedas está em [GUIA_ANIMACOES_REUTILIZAVEIS.md](GUIA_ANIMACOES_REUTILIZAVEIS.md), acompanhado por uma gravação da execução real.
