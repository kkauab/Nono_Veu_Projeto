extends RefCounted
## Conversation approved by the author before the portrait interface was added.
## Display wrapping and pagination belong to the dialogue view, not the prose.

const LINES := [
	{"speaker":"PESCADOR", "expression":"neutral", "listener_expression":"concerned", "stage":"mooring", "text":"Passe por baixo do poste. Isso… Agora pode descer."},
	{"speaker":"SENU", "expression":"neutral", "listener_expression":"neutral", "text":"Obrigado. Nunca vi esse cais tão vazio."},
	{"speaker":"PESCADOR", "expression":"sad", "listener_expression":"concerned", "text":"Nesta hora, já tinha gente discutindo por um lugar para descarregar. Hoje você é o primeiro."},
	{"speaker":"SENU", "expression":"concerned", "listener_expression":"neutral", "text":"Estou procurando um homem. Iri, meu mestre. É um escriba mais velho. Costuma carregar os livros embrulhados num pano."},
	{"speaker":"PESCADOR", "expression":"concerned", "listener_expression":"concerned", "text":"Um pano escuro? Vi alguém assim antes de clarear. Pediu água, mas não soltou o embrulho nem para beber."},
	{"speaker":"SENU", "expression":"concerned", "listener_expression":"concerned", "text":"Ele estava ferido?"},
	{"speaker":"PESCADOR", "expression":"concerned", "listener_expression":"concerned", "text":"Andava devagar. Não vi sangue. Você esperava encontrá-lo aqui?"},
	{"speaker":"SENU", "expression":"sad", "listener_expression":"concerned", "text":"Nossa ordem foi atacada esta noite. Nós nos separamos durante a fuga. Disseram que um homem com a descrição dele tinha vindo para o porto."},
	{"speaker":"PESCADOR", "expression":"sad", "listener_expression":"sad", "text":"Sinto muito. Eu devia ter perguntado se precisava de ajuda."},
	{"speaker":"SENU", "expression":"resolute", "listener_expression":"sad", "text":"Você deu água a ele. Já fez alguma coisa. Para onde ele foi?"},
	{"speaker":"PESCADOR", "expression":"concerned", "listener_expression":"concerned", "text":"Entrou pelo caminho dos armazéns. Depois disso, perdi de vista. Não posso garantir que fosse seu mestre."},
	{"speaker":"SENU", "expression":"resolute", "listener_expression":"concerned", "text":"É a primeira pista que tenho desde o ataque."},
	{"speaker":"PESCADOR", "expression":"concerned", "listener_expression":"concerned", "stage":"warning", "text":"Tenha cuidado por lá. Há homens armados… e gente que já não reconhece quem está diante deles."},
	{"speaker":"SENU", "expression":"concerned", "listener_expression":"sad", "text":"Por causa da Inversão?"},
	{"speaker":"PESCADOR", "expression":"sad", "listener_expression":"concerned", "stage":"net", "text":"É o nome que estão dando. Meu irmão passou aqui ontem. Perguntou quanto eu queria por esta rede."},
	{"speaker":"SENU", "expression":"concerned", "listener_expression":"sad", "text":"Ele não reconheceu você?"},
	{"speaker":"PESCADOR", "expression":"sad", "listener_expression":"sad", "stage":"knot_pause", "text":"Não. Ficou esperando eu dizer o preço. Foi ele quem me ensinou a fazer esses nós."},
	{"speaker":"SENU", "expression":"resolute", "listener_expression":"sad", "text":"Iri estudava esses esquecimentos. Se eu encontrá-lo, vou contar o que aconteceu com seu irmão."},
	{"speaker":"PESCADOR", "expression":"concerned", "listener_expression":"concerned", "text":"Você acha que ele pode ajudar?"},
	{"speaker":"SENU", "expression":"concerned", "listener_expression":"concerned", "text":"Não sei. Mas ele talvez saiba por onde começar."},
	{"speaker":"PESCADOR", "expression":"neutral", "listener_expression":"resolute", "text":"Então procure por ele. Se descobrir alguma coisa, passe por aqui."},
	{"speaker":"SENU", "expression":"concerned", "listener_expression":"sad", "text":"Você vai continuar vindo?"},
	{"speaker":"PESCADOR", "expression":"sad", "listener_expression":"concerned", "text":"Meu irmão ainda sabe o caminho até este cais. Quero estar aqui quando ele aparecer."},
	{"speaker":"SENU", "expression":"resolute", "listener_expression":"sad", "stage":"promise", "text":"Eu volto para contar o que encontrar."}
]

## Authored delivery beats in seconds. These drive acting, independently of
## text reveal speed, punctuation processing, or the reader revealing a line.
const DELIVERY_SECONDS := [
	4.0, 3.2, 5.4, 6.8, 6.3, 1.7, 4.4, 7.2,
	3.8, 4.0, 6.5, 2.8, 6.0, 1.9, 6.7, 1.8,
	5.2, 5.3, 1.8, 3.3, 4.5, 1.9, 5.2, 2.8
]

static func legacy_lines() -> Array:
	var result: Array = []
	for line in LINES: result.append([line["speaker"], line["text"]])
	return result
