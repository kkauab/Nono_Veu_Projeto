# Porteiro — costas e agilidade v9

Revisão solicitada após a v8: costas com nuca/cabelo, ombros sob a gola e manto cobrindo o dorso, com dobras diagonais e abertura inferior assimétrica. Braços/arma continuam em camadas separadas. Todas as poses traseiras recebem a correção; pivô96,144 e densidade corporal preservados. As cinco vistas frontais/laterais mantêm os mesmos pixels da fonte v8; o rosto v3 preferido não muda.

Fonte local em cinco camadas,1.336 cels, oito vistas; `porteiro_live_v9.pxo` e `directions/*.pxo`. Construção articulada/recortes dos concepts com retoques de pixels, sem API paga. Não são 1.336 desenhos manuais feitos na interface. Fontes antigas e suas edições ficam preservadas; hashes impedem reconstruir sobre fonte/export alterado.

- `build_gatekeeper_live_v9.py --proof-only`: comparação com v8; sem reexportar a fonte.
- `build_gatekeeper_live_v9.py`: cria a fonte nova. Prévia de caminhada em46 px/s; no jogo as poses continuam ligadas à distância efetivamente percorrida, sem deslizar o apoio para aumentar a velocidade.
- `export_gatekeeper_live_v7.ps1 -ArtVersion 9`: exportação por vista via Pixelorama. Nesta produção, cinco exports Pixelorama existentes foram reutilizados após comparar4.175 camadas nativas byte a byte; as três vistas traseiras foram reexportadas. Prova em `qa/porteiro_combate/export_v9_rear/reuse_proof.json`.
- `validate_gatekeeper_live_v7.py 9`: compara cada pixel exportado com as camadas nativas, pivôs, alpha, margens, rosto e relógio dos ataques.

Runtime: `assets/sprites/porteiro_live_v9.png` e manifesto compacto. Configuração em `gatekeeper_combat.json`:720 PV, movimento46/54,28 nas duas fases, fase2 com relógio1,10× e pausa adicional0,28/0,16 s. Dano, avisos, parry e vulnerabilidade após os golpes continuam usando o sistema existente.

Provas: `qa/porteiro_refino_v9/`; capturas e GIFs atuais em `qa/porteiro_refino_v9/runtime/`. `TESTAR_PORTEIRO.cmd` abre o mesmo encontro com progresso separado. Avaliação humana de arte e dificuldade continua necessária.
