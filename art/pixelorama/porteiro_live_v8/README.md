# Porteiro Sem Nome — silhueta v8

Revisão da v7 após o jogador rejeitar o aspecto tubular no mapa. Mesma altura/densidade/pivô, rosto v3 preferido e temporização dos nove golpes. Não altera a dificuldade:720 PV, movimento36/40,32 e danos aumentados.

Ombros mais largos que a cintura; túnica dividida em duas abas; pernas separadas; manto com dobras e pontas assimétricas. Braços permanecem visíveis nas vistas de costas, enquanto a arma pode passar atrás do corpo. Placas de bronze pendem de pontos espaçados ao longo do cinto; não avançam como uma barra para fora da cintura.

1. `tools/pixelorama/build_gatekeeper_live_v8.py --proof-only`: comparação de silhueta sem reexportar a fonte.
2. `build_gatekeeper_live_v8.py`: fonte própria de1.336 cels em oito vistas, cinco camadas,192²/pivô96,144. Reutiliza o construtor/articulações v7 com a nova passagem de anatomia; fontes V1–V7 preservadas. Retoques manuais são protegidos por hashes.
3. `export_gatekeeper_live_v7.ps1 -ArtVersion 8`: separa as oito fontes editáveis, exporta pelo Pixelorama e compacta os exports reais. O parâmetro padrão7 mantém o pipeline anterior.
4. `validate_gatekeeper_live_v7.py 8`: verifica cada pixel contra as camadas nativas, rosto, pivô/margens, alpha e relógio JSON.

Arquivo mestre `porteiro_live_v8.pxo`; `directions/*.pxo` para edição/exportação por vista. Runtime `assets/sprites/porteiro_live_v8.png` + manifesto. Provas/comparação em `qa/porteiro_silhueta_v8/`; captura do encontro em `qa/porteiro_combate/`. As fontes usam montagem/articulações e texturas dos concepts, não são desenhos manuais de todos os cels feitos na interface.
