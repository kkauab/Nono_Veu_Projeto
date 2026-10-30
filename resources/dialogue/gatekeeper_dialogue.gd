extends RefCounted
## Requested dialogue, verbatim; the approved quay opening stays separate.
const INTRO="PORTEIRO — Diga seu nome.\n\nSENU — Senu. Sou discípulo de Iri. Preciso passar.\n\nPORTEIRO — Senu...\n\nPORTEIRO — Não... Não está aqui.\n\nSENU — Procure novamente.\n\nPORTEIRO — Eu procurei.\n\nPORTEIRO — Procurei todos.\n\nPORTEIRO — Ninguém mais está aqui.\n\nPORTEIRO — E o meu?\n\nPORTEIRO — Onde escreveram o meu?"
const PHASE="PORTEIRO — Eu escrevi todos...\n\nPORTEIRO — Todos...\n\nPORTEIRO — POR QUE NÃO CONSIGO ENCONTRAR O MEU?"
const DEFEAT="PORTEIRO — Eu me lembrava de todos...\n\nPORTEIRO — Por que ninguém se lembrou de mim?"
const RECORDS=[
 {"id":"gatekeeper_record_01","tile":Vector2(-10,18),"title":"O livro das chegadas","text":"O guarda da passagem dispensava os livros. Reconhecia pelo nome os marinheiros que não via havia anos. Por ordem do porto, voltou a registrar cada chegada. Ninguém deveria depender de uma única memória."},
 {"id":"gatekeeper_record_02","tile":Vector2(-1,18),"title":"Placas de marinheiros","text":"Dezenas de nomes foram gravados no bronze. Alguns perderam apenas uma letra. Outros são sulcos vazios. Ao lado de cada nome, a mesma palavra: voltou."},
 {"id":"gatekeeper_record_03","tile":Vector2(-10,28),"title":"Uma anotação dobrada","text":"Hoje precisei perguntar o nome de minha filha. Ela riu, pensando que era uma brincadeira. Escrevi aqui para que amanhã...\n\nO restante foi riscado até rasgar o papel."},
 {"id":"gatekeeper_record_04","tile":Vector2(-1,28),"title":"O registro corrigido","text":"O mesmo espaço foi raspado e regravado muitas vezes. Sob os riscos, resta uma frase: Se eu esquecer, quem permitirá que eu volte?\n\nNenhum nome pode ser recuperado."}
]
