# Progresso ancorado nas torres

O arquivo da jornada só é gravado quando Senu interage com uma torre de salvamento. Essa interação continua restaurando vida e cargas de bálsamo e renovando os inimigos comuns. Chefes já vencidos permanecem vencidos no estado ancorado.

Coletar objetos, XP ou óbolos, aceitar ou concluir missões, comprar itens, aprender habilidades, resolver mecanismos e terminar a abertura atualizam a sessão em memória. Esses eventos não escrevem o arquivo de progresso. Para conservar as mudanças entre sessões, medite numa torre.

**Sair** e fechar a janela encerram a partida sem salvar. O próximo carregamento usa a última torre. A função legada `save_and_quit()` foi mantida para compatibilidade, mas segue o mesmo caminho de saída sem gravação.

Ao começar uma nova jornada, o último progresso ancorado é arquivado e o novo mundo começa em memória. O slot anterior continua intacto até a primeira torre da nova jornada. O arquivo de segurança copia os dados que estavam no disco, sem transformar mudanças não salvas da sessão anterior em um salvamento.

A morte mantém as regras atuais de retorno ao último ponto de descanso durante a sessão; não grava progresso no disco. Se uma torre não puder gravar o arquivo, não há cura, recarga nem renovação de inimigos, e o ponto anterior é preservado.

## Implementação

- `world._save()` sincroniza a arma equipada e o estado da sessão; não realiza entrada ou saída de arquivo.
- `world._persist_progress()` grava o estado e só é chamado pela transação de descanso da torre.
- `world.has_unsaved_progress()` informa se a sessão difere da última ancoragem.
- `world.quit_without_save()` encerra a partida. O fechamento da janela usa essa mesma função.
- `DemoSaveStore.save_progress()` continua disponível como API de serialização e nos testes isolados; nenhum outro evento do jogo a chama diretamente.

O teste `tests/tower_only_save_test.gd` verifica os bytes do arquivo antes e depois de compras, habilidades, coletas, saídas e novas jornadas, além do descanso e da renovação dos inimigos. Todos os arquivos de teste ficam em uma pasta exclusiva de `user://qa`.
