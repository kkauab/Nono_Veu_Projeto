# Áudio original do Porteiro

WAVs sintetizados localmente por `tools/audio/build_gatekeeper_sfx.py` e `build_gatekeeper_score.py`, sem serviços pagos ou músicas externas. Hashes protegem arquivos alterados manualmente.

- `gatekeeper_duty.wav`: camada contida, solene; `gatekeeper_despair.wav`: tensão/percussão adicional na fase2. Loops no bus Musica existente, respeitando preferências.
- Sinos/correntes/passos de pedra/respiração usam o pool de vozes e buses atuais. O leito de água/vento é o ambiente já existente.
- `resources/bosses/gatekeeper_audio.json` oferece cues de esforço/desespero/riso/grito/última respiração, substituíveis por arquivos definitivos. Os arquivos atuais são respirações sintéticas provisórias com variações de pitch/volume; não são gravações humanas de risos, gritos ou diálogo. Não há dublagem das falas.
