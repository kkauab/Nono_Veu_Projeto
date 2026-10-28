"""Create the illustrated Portuguese story dossier from the project's canon.

Keeps the approved opening verbatim and separates written port content from
the campaign and endings proposed in the narrative bible. No game files change.
"""
import html
import json
import math
import re
from pathlib import Path

from PIL import Image as PILImage
from reportlab.lib import colors
from reportlab.lib.enums import TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate, Frame, Image, KeepTogether, PageBreak, PageTemplate,
    Paragraph, Spacer, Table, TableStyle,
)
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/pdf'
TMP = ROOT / 'tmp/pdfs/story'
OUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)
PDF = OUT / 'O_Nono_Veu_Historia_e_Universo.pdf'
W, H = A4
M = 48
CW = W - 2*M
INK = colors.HexColor('#0B2028')
TEAL = colors.HexColor('#294D50')
GOLD = colors.HexColor('#AA7B42')
PALE = colors.HexColor('#F8F4EA')
TEXT = colors.HexColor('#263B3E')
MUTED = colors.HexColor('#63716D')
RULE = colors.HexColor('#D8C9A8')

for name, file in {
    'Georgia':'georgia.ttf','GeorgiaB':'georgiab.ttf',
    'GeorgiaI':'georgiai.ttf','GeorgiaBI':'georgiaz.ttf',
    'Segoe':'segoeui.ttf','SegoeB':'segoeuib.ttf',
}.items():
    pdfmetrics.registerFont(TTFont(name, 'C:/Windows/Fonts/'+file))
pdfmetrics.registerFontFamily('Georgia',normal='Georgia',bold='GeorgiaB',italic='GeorgiaI',boldItalic='GeorgiaBI')
pdfmetrics.registerFontFamily('Segoe',normal='Segoe',bold='SegoeB',italic='Segoe',boldItalic='SegoeB')

STYLES = {
 'body':ParagraphStyle('Body',fontName='Georgia',fontSize=10.7,leading=15.9,
     textColor=TEXT,spaceAfter=10,alignment=TA_JUSTIFY,allowWidows=0,allowOrphans=0),
 'deck':ParagraphStyle('Deck',fontName='GeorgiaI',fontSize=11.8,leading=17.5,
     textColor=TEAL,spaceAfter=17),
 'kicker':ParagraphStyle('Kicker',fontName='SegoeB',fontSize=8.3,leading=12,
     textColor=GOLD,spaceAfter=7),
 'title':ParagraphStyle('Title',fontName='GeorgiaB',fontSize=25,leading=29,
     textColor=INK,spaceAfter=13,keepWithNext=True),
 'h2':ParagraphStyle('H2',fontName='GeorgiaB',fontSize=13,leading=17,
     textColor=TEAL,spaceBefore=9,spaceAfter=6,keepWithNext=True),
 'small':ParagraphStyle('Small',fontName='Segoe',fontSize=8.5,leading=12.4,
     textColor=MUTED,spaceAfter=8),
 'quote':ParagraphStyle('Quote',fontName='GeorgiaI',fontSize=12.5,leading=18.8,
     textColor=TEAL,spaceAfter=6),
 'dialogue':ParagraphStyle('Dialogue',fontName='Georgia',fontSize=10.5,leading=15,
     textColor=TEXT,spaceAfter=6,allowWidows=0,allowOrphans=0),
 'stage':ParagraphStyle('Stage',fontName='GeorgiaI',fontSize=10.1,leading=15.4,
     textColor=MUTED,spaceAfter=8),
 'toc':ParagraphStyle('TOC',fontName='Segoe',fontSize=10.5,leading=17,
     textColor=TEAL),
 'gloss':ParagraphStyle('Gloss',fontName='Georgia',fontSize=9.7,leading=14.1,
     textColor=TEXT),
}

def clean(text):
    return text.replace('\u2011','-').replace('\u2013','-').replace('\u2014','-')

def p(text, style='body'):
    return Paragraph(clean(text), STYLES[style])

def section(tag, title, anchor, deck=None):
    heading=p(title,'title')
    heading.bookmark=anchor
    heading.outline_title=title
    result=[p(tag,'kicker'),heading]
    if deck:result.append(p(deck,'deck'))
    return result

def h2(text):return p(text,'h2')

def quote(text, source=None):
    rows=[[p(text,'quote')]]
    if source:rows.append([p(source,'small')])
    block=Table(rows,colWidths=[CW-32])
    block.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,-1),colors.HexColor('#EFE9D9')),
        ('LINEBEFORE',(0,0),(0,-1),2,GOLD),
        ('LEFTPADDING',(0,0),(-1,-1),16),('RIGHTPADDING',(0,0),(-1,-1),16),
        ('TOPPADDING',(0,0),(-1,0),12),('BOTTOMPADDING',(0,-1),(-1,-1),7),
    ]))
    return [block,Spacer(1,14)]

def area(name, boss, text):
    return KeepTogether([h2(name),p('CHEFE: '+boss,'kicker'),p(text)])

LABELS={
 2:'A jornada de Senu',3:'O mundo e o mistério',4:'Personagens',
 5:'A chegada ao cais',6:'A promessa',7:'As marcas de Iri',
 8:'Hori e Sabu',9:'As vozes do porto',10:'Capítulo I',
 11:'Capítulo II',12:'Capítulo III',13:'Três desfechos',14:'Nomes e fontes',
}

def tracked(c, text, x, y, font='SegoeB', size=8.5, spacing=1.5, color=GOLD, center=False):
    c.setFillColor(color)
    t=c.beginText()
    t.setFont(font,size)
    t.setCharSpace(spacing)
    if center:
        width=pdfmetrics.stringWidth(text,font,size)+max(0,len(text)-1)*spacing
        x-=width/2
    t.setTextOrigin(x,y)
    t.textLine(text)
    c.drawText(t)

def cover(c):
    c.setFillColor(INK);c.rect(0,0,W,H,fill=1,stroke=0)
    title_art=str(ROOT/'assets/ui/port_title_v7.png')
    c.drawImage(title_art,0,175,width=W,height=W*360/640,mask='auto')
    c.setStrokeColor(GOLD);c.setLineWidth(.75);c.rect(29,29,W-58,H-58,stroke=1,fill=0)
    for x,y in [(29,29),(W-29,29),(29,H-29),(W-29,H-29)]:
        path=c.beginPath();path.moveTo(x,y+4);path.lineTo(x+4,y);path.lineTo(x,y-4);path.lineTo(x-4,y);path.close()
        c.drawPath(path,stroke=1,fill=0)
    tracked(c,'CADERNO DA HISTÓRIA',W/2,773,spacing=2.2,center=True)
    cx,cy=W/2,709
    c.setStrokeColor(GOLD)
    c.circle(cx,cy,13,stroke=1,fill=0)
    for i in range(8):
        a=math.tau*i/8
        c.line(cx+math.cos(a)*17,cy+math.sin(a)*17,cx+math.cos(a)*26,cy+math.sin(a)*26)
    c.setFillColor(colors.HexColor('#F4EBD4'));c.setFont('GeorgiaB',39)
    c.drawCentredString(W/2,636,'O NONO')
    c.setFillColor(colors.HexColor('#D9B773'));c.setFont('GeorgiaB',58)
    c.drawCentredString(W/2,575,'VÉU')
    c.setLineWidth(.6);c.line(W/2-80,554,W/2+80,554)
    c.setFillColor(colors.HexColor('#D4DBCE'));c.setFont('GeorgiaI',13)
    c.drawCentredString(W/2,525,'A memória é a última margem.')
    c.setFillColor(colors.HexColor('#EEE4CC'));c.setFont('Georgia',16)
    c.drawCentredString(W/2,133,'História e universo')
    tracked(c,'27.10.2026 / O NONO VÉU',W/2,88,size=8,spacing=1.4,center=True)
    c.setFillColor(colors.HexColor('#B6C5BA'));c.setFont('Segoe',8.4)
    c.drawCentredString(W/2,62,'Abertura aprovada e direção narrativa da campanha')

def page(c, doc):
    c.saveState()
    if doc.page==1:
        cover(c)
        c.bookmarkPage('capa');c.addOutlineEntry('O Nono Véu','capa',0,False)
    else:
        c.setFillColor(PALE);c.rect(0,0,W,H,fill=1,stroke=0)
        tracked(c,'O NONO VÉU',M,H-39,size=8.2,spacing=1.1,color=TEAL)
        c.setFillColor(MUTED);c.setFont('Segoe',8.1)
        c.drawRightString(W-M,H-39,LABELS.get(doc.page,'História e universo'))
        c.setStrokeColor(RULE);c.setLineWidth(.6);c.line(M,H-52,W-M,H-52)
        c.line(M,45,W-M,45)
        c.setFont('Segoe',7.7);c.setFillColor(MUTED)
        c.drawString(M,30,'História e universo | edição do projeto')
        c.setFont('Georgia',9.5);c.setFillColor(TEAL)
        c.drawRightString(W-M,29,f'{doc.page:02d}')
    c.restoreState()

class StoryDoc(BaseDocTemplate):
    def afterFlowable(self, flowable):
        if hasattr(flowable,'bookmark'):
            self.canv.bookmarkPage(flowable.bookmark)
            self.canv.addOutlineEntry(flowable.outline_title,flowable.bookmark,0,False)


source=(ROOT/'resources/dialogue/opening_fisherman.gd').read_text(encoding='utf8')
opening=[]
for match in re.finditer(r'\{"speaker":"([^"]+)".*?"text":"((?:\\.|[^"\\])*)"\}',source):
    opening.append((match.group(1),json.loads('"'+match.group(2)+'"')))
assert len(opening)==24,len(opening)

# A native complete portrait is only cropped for book illustration, not edited.
portrait=PILImage.open(ROOT/'assets/ui/dialogue_v15/fisherman.png').convert('RGBA')
portrait.crop((0,0,160,192)).save(TMP/'hori.png')

story=[Spacer(1,600),PageBreak()]

# 02 - Overview and navigable contents.
story+=section('01 / VISÃO DA HISTÓRIA','A jornada de Senu','jornada',
    'Uma busca por um mestre desaparecido se transforma numa disputa pelo direito de continuar sendo alguém.')
story += [p('O mundo às margens do Nilo está adoecendo. Pessoas deixam de reconhecer quem amam, mortos regressam sem memória e lugares inteiros parecem esquecer a própria forma. Os estudiosos chamam essa crise de <b>Inversão</b>.'),
    p('<b>Senu</b>, discípulo de uma ordem ligada à tradição de Hermes, perde o contato com seu mestre, <b>Iri</b>, depois de um ataque. A primeira pista o leva a um cais quase vazio em Alexandria. Dali, sua procura se estende pelo Egito e alcança o reino de Axum.'),
    p('O que começa como uma tentativa de encontrar alguém revela uma ameaça maior: o <b>Primeiro Copista</b> quer reescrever a relação entre consciência e realidade. Sua promessa é acabar com a morte e o sofrimento. O preço pode ser a liberdade de todas as pessoas.'),
    p('Este caderno reúne a abertura aprovada, as histórias já escritas para o Porto e a campanha planejada. Os capítulos futuros e os três desfechos permanecem propostas narrativas em desenvolvimento.','small'),h2('Percurso de leitura')]
contents=[('O mundo e o mistério','mundo',3),('Os personagens principais','personagens',4),
 ('A chegada ao cais / conversa aprovada','chegada',5),('A promessa','promessa',6),
 ('As marcas de Iri','marcas',7),('Hori e Sabu','hori',8),('As vozes do porto','vozes',9),
 ('Capítulo I / O Despertar do Discípulo','cap1',10),('Capítulo II / O Julgamento da Alma','cap2',11),
 ('Capítulo III / A Ascensão ao Nono Véu','cap3',12),('Três desfechos possíveis','finais',13),
 ('Nomes e fontes do projeto','fontes',14)]
toc=Table([[p(f'<link href="#{anchor}" color="#294D50">{title}</link>','toc'),p(f'{number:02d}','toc')] for title,anchor,number in contents],colWidths=[CW-35,35])
toc.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),0),('RIGHTPADDING',(0,0),(-1,-1),0),('TOPPADDING',(0,0),(-1,-1),1.5),('BOTTOMPADDING',(0,0),(-1,-1),1.5),('LINEBELOW',(0,0),(-1,-1),.25,RULE)]))
story += [toc,PageBreak()]

# 03 - World.
story+=section('02 / UNIVERSO','O mundo e o mistério','mundo',
    'A memória deixa de ser apenas uma lembrança. Ela se torna uma das coisas que sustentam o mundo.')
story += [h2('A Inversão'),p('As manifestações da crise não são iguais em todos os lugares. No Porto, nomes, rostos e vínculos se perdem. Em outros pontos do caminho, sacerdotes escutam vozes em estátuas ocas, constelações impossíveis aparecem no céu e templos desaparecem para voltar transformados. Há mortos que regressam sem reconhecer os próprios parentes.'),
    h2('O Reverso'),p('Existe uma camada invisível da realidade, chamada <b>Reverso</b>. A Inversão é a crise causada pelo reflexo imperfeito entre essa camada e o mundo material. As duas palavras não designam a mesma coisa: o Reverso é uma dimensão; a Inversão é o adoecimento que atravessa a relação entre elas.'),
    h2('O conhecimento e seus limites'),p('No centro do mistério está uma ordem de escribas e iniciados que preserva ensinamentos atribuídos a Hermes Trismegisto. Os seus membros buscaram compreender a consciência, a matéria e aquilo que sobrevive à morte. A campanha planejada revela que esse estudo ultrapassou limites cujas consequências a própria ordem não conseguiu controlar.'),
    h2('Os véus'),p('O título evoca os limiares entre percepção e realidade. Cada descoberta exige que Senu reconsidere o que sabe, em quem confia e como interpreta os sinais. A história preserva informações incompletas e testemunhos contraditórios, mas permite que o jogador reúna pistas por ambientes, inscrições, encontros e escolhas.'),
    h2('A presença de Hermes'),p('Hermes surge de modo ambíguo em sonhos, textos e sinais. Sua presença pode ser revelação, memória, projeção ou manipulação. Ele não deve explicar todo o mistério nem substituir as decisões do discípulo.')]
story += quote('Quem teria legitimidade para determinar o destino de todas as consciências?','Pergunta central da campanha')
story += [PageBreak()]

# 04 - Characters.
story+=section('03 / PERSONAGENS','Quem atravessa os véus','personagens')
profiles=[
 ('Senu','O discípulo','Sua primeira urgência é encontrar Iri. Ao seguir as marcas do mestre, Senu precisa aprender a distinguir orientação de autoridade, conhecimento de imposição. O arco planejado o leva de uma busca pessoal a uma decisão sobre o destino de todas as consciências. O vínculo com a ordem não o dispensa de questionar o que ela fez.'),
 ('Iri','O mestre desaparecido','Iri é o mentor próximo de Senu, alguém associado às lições, aos livros e aos caminhos de retorno. No Porto, sua presença sobrevive em marcas e recados. A campanha futura prevê a descoberta de sua participação nos primeiros experimentos com a Inversão, transformando a busca num confronto com a responsabilidade do próprio mestre.'),
 ('Hermes Trismegisto','A presença ambígua','Figura mítica ligada à tradição da ordem. Aparece como uma possibilidade de orientação, mas também como um problema de interpretação. A história mantém em aberto se seus sinais pertencem a uma presença autêntica, a uma lembrança ou a uma interferência.'),
 ('Erena','A astrônoma de Axum','Aliada planejada para a campanha. Investiga as anomalias do céu e questiona as certezas da ordem. Sua perspectiva ajuda a relacionar pistas de lugares e tradições diferentes, sem reduzir sua existência ao papel de explicar o mundo a Senu.'),
 ('O Primeiro Copista','A promessa de uma cura absoluta','Antigo discípulo associado à tradição de Hermes e antagonista central. Quer acabar com morte, sofrimento e ignorância por meio da unidade das consciências. Seus argumentos precisam ser compreensíveis, mesmo quando sua solução exige extinguir a escolha e a individualidade.'),
]
for name,role,text in profiles:
    story += [KeepTogether([h2(name),p(role.upper(),'kicker'),p(text)])]
story += [p('Os arcos de Iri, Erena, Hermes e do Primeiro Copista descrevem a direção planejada da campanha; suas cenas detalhadas ainda não constituem um roteiro final.','small'),PageBreak()]

# 05 and 06 - Exact approved opening.
story+=section('04 / ABERTURA APROVADA','A chegada ao cais','chegada',
    'Alexandria, ao amanhecer. A barca encosta. O pescador interrompe o conserto de uma rede e se aproxima para receber a corda.')
for i,(speaker,text) in enumerate(opening[:12]):
    if i==3:story.append(p('Senu olha para os barcos parados. O pescador termina a amarração.','stage'))
    name='Senu' if speaker=='SENU' else 'Pescador'
    color='#294D50' if speaker=='SENU' else '#94692F'
    story.append(p(f'<font name="SegoeB" color="{color}">{name.upper()}</font><br/>'+html.escape(text),'dialogue'))
story.append(PageBreak())
story+=section('04 / ABERTURA APROVADA','A promessa','promessa',
    'Senu se prepara para partir. O pescador o chama antes que se afaste.')
for i,(speaker,text) in enumerate(opening[12:],12):
    if i==14:story.append(p('O pescador olha para a rede que deixou no chão.','stage'))
    if i==17:story.append(p('Uma pausa. O pescador passa o polegar por um dos nós.','stage'))
    if i==23:story.append(p('Senu olha novamente para a rede, depois para o pescador.','stage'))
    name='Senu' if speaker=='SENU' else 'Pescador'
    color='#294D50' if speaker=='SENU' else '#94692F'
    story.append(p(f'<font name="SegoeB" color="{color}">{name.upper()}</font><br/>'+html.escape(text),'dialogue'))
story += [p('O pescador faz um pequeno aceno e retoma a rede. Senu segue na direção dos armazéns.','stage'),PageBreak()]

# 07 - Current port story.
story+=section('05 / HISTÓRIAS ATUAIS DO PORTO','As marcas de Iri','marcas',
    'O mestre desaparecido deixou mais que uma direção. Deixou um modo de olhar para os vestígios.')
story += [p('A testemunha do cais não pode garantir que o homem dos livros fosse Iri. A investigação ganha um apoio mais concreto quando Senu encontra quatro marcas da ordem espalhadas pelo Porto. São mensagens que falam diretamente ao discípulo e preservam lembranças compartilhadas.'),
    h2('O Arquivo'),p('Nomes foram reescritos pela mesma mão. A tinta é recente, embora imite letras antigas. A mensagem de Iri adverte Senu para não confiar apenas no registro escrito: há diferença entre aquilo que foi anotado e aquilo que alguém ainda consegue lembrar.'),
    h2('O Observatório'),p('Uma lembrança de infância atravessa o recado: Senu contava estrelas para se manter acordado nas vigílias. Iri o convida a contar outra vez e deixa uma seta na direção do santuário. O céu aparece como um registro que resiste à falsificação.'),
    h2('O Santuário Soterrado'),p('A água guarda aquilo que as pessoas esquecem. Sob o lodo, a marca recupera uma lição sobre identidade: um nome não é somente o que os outros dizem, mas aquilo a que alguém responde. Lembrar do próprio nome torna-se um gesto de resistência.'),
    h2('A Guarita'),p('Iri preparou o caminho de volta, como fazia nas viagens com o discípulo. Deixou algo onde tudo começa, na Primeira Palavra. As quatro marcas conduzem a um relicário no hub, o Santuário da Primeira Palavra.'),
    h2('O relicário'),p('Dentro da caixa de cedro está o cordão de contas usado pelo mestre para contar as respirações durante as lições. O pano escuro dos livros envolve o objeto e guarda a pista concreta da continuação: Iri desceu às Catacumbas atrás de quem reescreve os nomes. Seu recado pede que Senu só o siga quando estiver pronto.'),PageBreak()]

# 08 - Brothers.
story+=section('06 / HISTÓRIAS ATUAIS DO PORTO','Hori e Sabu','hori',
    'O irmão ainda conhece os nós. O que se perdeu foi o rosto ligado a eles.')
portrait=Image(str(TMP/'hori.png'),width=98,height=117.6)
intro=[p('Quando Senu retorna ao cais, o pescador revela seu nome: <b>Hori</b>. Dizer o próprio nome, depois daquela manhã, parece importante. Ele ainda não recebeu notícias de seu irmão, <b>Sabu</b>, mas um carregador viu um homem enrolando cordas no Embarcadouro Velho, ao sul do Pátio das Memórias.'),
       p('Senu encontra Sabu desfazendo e refazendo o mesmo nó. As mãos conservam um saber que a memória já não consegue explicar. A palavra “irmão” parece boa, mas não traz um rosto.')]
aside=Table([[intro,portrait]],colWidths=[CW-116,116])
aside.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),0),('RIGHTPADDING',(0,0),(0,0),13),('RIGHTPADDING',(1,0),(1,0),0),('TOPPADDING',(0,0),(-1,-1),0),('BOTTOMPADDING',(0,0),(-1,-1),0)]))
story += [aside,h2('Um nó de três voltas'),p('Ao saber que o irmão está vivo, Hori entrega a Senu um cordão. O nó de três voltas foi a primeira coisa que Sabu lhe ensinou quando os dois eram meninos. Não é uma solução completa para o esquecimento; é um vestígio concreto de uma vida compartilhada.'),
    p('Sabu reconhece o nó como seu, mas o nome ligado a ele ainda parece preso atrás de uma porta. No arco atual do Porto, a travessia do limiar guardado pelo Porteiro Sem Nome permite que essa lembrança avance. Com o cordão nas mãos, ele finalmente diz: <b>Hori</b>.'),
    h2('O caminho até o cais'),p('Senu volta para contar. Hori não precisa de uma explicação longa: começa a olhar para o fim do cais antes que o relato termine. Sabu retorna ao entardecer. Ainda confunde acontecimentos recentes, mas reconhece o nome do irmão.'),
    p('O reencontro preserva uma recuperação parcial e humana. A Inversão não desaparece. O que volta é um vínculo, acompanhado de uma pequena disputa familiar: cada um passa a dizer que foi o outro quem ensinou o nó.')]
story += quote('“Se encontrar seu mestre, Senu, traga-o aqui. Temos água para os dois.”','Hori, depois do retorno de Sabu')
story += [PageBreak()]

# 09 - City vignettes.
story+=section('07 / HISTÓRIAS ATUAIS DO PORTO','Uma cidade que insiste em viver','vozes',
    'A Inversão também se revela nos ofícios, nos cheiros e nas tarefas que continuam sendo repetidas.')
vignettes=[
 ('Merit, no empório','“Não lembro o nome destes frascos, mas reconheço cada um pelo cheiro.”','Merit já não depende dos nomes para distinguir aquilo que vende. O aroma dos frascos preserva um conhecimento cotidiano. Sua presença mostra que esquecer uma palavra não é necessariamente perder toda a relação com uma coisa.'),
 ('Nakht, na forja','“O forno não apaga desde que eu cheguei, e não lembro como apagá-lo.”','O fogo permanece aceso, e o bronze ainda obedece às mãos do ferreiro. O domínio do ofício convive com uma perda que ele não consegue resolver. A cidade continua produzindo, mesmo quando seus habitantes deixam de compreender partes do que fazem.'),
 ('Adiam, entre os cordões','“Cada nó destes cordões é uma rota.”','As rotas de viagem são registradas em nós porque a memória já não parece confiável. Assim como o cordão de Hori, o objeto conserva um caminho por meio do gesto e da matéria. Adiam transforma esse recurso numa forma de seguir circulando pelo mundo.'),
 ('O guarda e o próprio soldo','“Se eu não voltar para buscar, é porque já não sei que ele é meu.”','Um bilhete registra rondas repetidas e a localização do soldo. Seu autor teme esquecer a razão do trabalho e o vínculo com aquilo que lhe pertence. A escrita funciona como tentativa de proteção, embora as marcas de Iri já tenham mostrado que registros também podem ser alterados.'),
]
for title,line,text in vignettes:
    story += [h2(title),p(line,'stage'),p(text)]
story += [p('Essas vozes já estão escritas no projeto atual. Elas aproximam o mistério de situações pequenas e dão ao Porto habitantes com experiências próprias.','small'),PageBreak()]

# 10 - Campaign I.
story+=section('08 / CAMPANHA PLANEJADA','O Despertar do Discípulo','cap1',
    'Capítulo I - Alexandria e Faium. Memória, percepção e os primeiros sinais do Reverso.')
story += [p('A investigação começa com a ausência de Iri e com um Porto que já não reconhece a própria vida cotidiana. A progressão planejada amplia esse primeiro contato: o esquecimento deixa de parecer um problema isolado e passa a indicar uma crise anterior ao ataque à ordem.'),
 area('A01 / O Porto dos Esquecidos','O Porteiro Sem Nome','Ruas portuárias degradadas e cais tomados por marinheiros sem memória introduzem o mistério das identidades roubadas. É o ponto de partida da busca e o lugar onde os vínculos de Hori e Sabu dão escala humana ao fenômeno.'),
 area('A02 / As Catacumbas do Eco','As Irmãs do Eco','Túneis funerários reproduzem vozes de acontecimentos possíveis. O espaço questiona a diferença entre o que foi vivido, o que poderia ter acontecido e aquilo que parece ser lembrado. Aqui aparecem as primeiras pistas mais diretas do Reverso.'),
 area('A03 / O Santuário da Palavra','A Voz de Mármore','Um recinto secreto associado à ordem revela que o ataque exigiu conhecimentos internos. Senu precisa considerar a participação de pessoas próximas da tradição à qual pertence. Este local não deve ser confundido com o hub da Primeira Palavra.'),
 area('A04 / O Jardim das Formas','O Jardineiro de Vidro','No Faium, corpos tendem a se tornar estátuas. A ameaça apresenta o horror de uma perfeição imposta: preservar uma forma pode significar retirar dela a possibilidade de mudar.'),
 h2('O que muda para Senu'),p('Ao fim do capítulo, a Inversão se revela anterior ao ataque em Alexandria e ligada a raízes mais ao sul. A busca pelo mestre começa a exigir uma investigação da própria ordem. A Visão do Reverso é uma habilidade narrativa prevista para esse momento.'),PageBreak()]

# 11 - Campaign II.
story+=section('09 / CAMPANHA PLANEJADA','O Julgamento da Alma','cap2',
    'Capítulo II - Alto Egito. Mortalidade, responsabilidade e a culpa da ordem.')
story += [p('O percurso segue por regiões do Alto Egito, com referências a Tebas, Karnak, ao Vale dos Reis, a Assuã e a Filas. Os lugares planejados deslocam a pergunta inicial: encontrar Iri já não basta se o próprio mestre participou da origem da crise.'),
 area('A05 / O Templo das Duas Verdades','A Balança Vazia','As decisões materializam consequências. O capítulo começa confrontando Senu com o julgamento e a responsabilidade: compreender um acontecimento não elimina a necessidade de responder pelos seus efeitos.'),
 area('A06 / O Vale dos Reis Adormecidos','O Faraó Sem Sono','Tumbas e câmaras de memória distorcem o tempo. O conflito mostra o custo de preservar a consciência à força e prepara o questionamento da promessa de uma existência sem morte.'),
 area('A07 / O Santuário das Lágrimas','A Guardiã das Marés','Passagens fluviais e ruínas sofrem a ação de marés sobrenaturais. A investigação revela por que parte da ordem decidiu proteger o segredo, em vez de torná-lo conhecido.'),
 area('A08 / A Biblioteca Submersa','O Escriba Afogado','Um arquivo lacrado existe parcialmente sob a água e parcialmente no Reverso. As descobertas ligam Iri aos experimentos que participaram da formação da Inversão.'),
 h2('O conhecimento como responsabilidade'),p('A revelação prevista é que a ordem tentou tornar a sobrevivência da consciência uma lei física. O vínculo entre discípulo e mestre passa a incluir culpa, dúvida e escolha. O Passo Mercurial é a habilidade de progressão planejada para esse arco.'),PageBreak()]

# 12 - Campaign III.
story+=section('10 / CAMPANHA PLANEJADA','A Ascensão ao Nono Véu','cap3',
    'Capítulo III - Deserto oriental, Mar Vermelho, Adúlis, Axum e o limiar final.')
story += [p('A jornada alcança caminhos do deserto e rotas até o reino de Axum. O mistério deixa de envolver apenas o desaparecimento do mestre ou os experimentos da ordem: passa a atingir a identidade do próprio Senu.'),
 area('A09 / O Deserto das Vozes','O Peregrino de Sal','Ruínas repetem pensamentos dos viajantes. O caminho testa a percepção e a confiança na própria memória, preparando Senu para encarar informações que podem alterar sua compreensão de si.'),
 area('A10 / O Mercado das Almas','O Mercador de Memórias','Em Adúlis, reinterpretada como espaço de fantasia, lembranças circulam como mercadorias. A revelação planejada liga Senu ao Primeiro Copista: parte da consciência do antagonista teria sido transferida para ele durante sua iniciação.'),
 area('A11 / A Necrópole das Estelas','Iri, o Mestre Caído','Um conjunto monumental de estelas e uma cripta de iniciação recebem o confronto com o mentor. A busca iniciada no cais se transforma num encontro com as escolhas e a responsabilidade de Iri.'),
 area('A12 / O Nono Véu','O Primeiro Copista','Uma região metafísica de espaço e tempo instáveis concentra o conflito final. Senu precisa enfrentar a proposta de reorganizar todas as consciências e decidir o que pode ser sacrificado em nome de uma cura absoluta.'),
 h2('O limite da autoridade'),p('Erena oferece uma perspectiva que questiona as certezas da ordem. Hermes permanece ambíguo. O ponto de chegada planejado exige que Senu decida sem entregar toda a responsabilidade ao mestre, à tradição ou à promessa de um mundo perfeito.'),PageBreak()]

# 13 - Endings.
story+=section('11 / DESFECHOS PROPOSTOS','Três respostas ao mesmo conflito','finais',
    'A Coroa do Silêncio concentra a tentativa de resolver a crise pela eliminação da individualidade.')
story += [p('Os três finais abaixo são alternativas de roteiro. Não existe, neste documento, um desfecho escolhido como definitivo. Cada um responde de um modo ao conflito entre liberdade, sofrimento e conhecimento.'),
 h2('I / O Mundo Imperfeito'),p('Senu rejeita o controle absoluto e destrói a Coroa do Silêncio. A morte e o sofrimento continuam fazendo parte da existência, mas a liberdade é preservada. O mundo permanece imperfeito, sem que uma única vontade tenha o direito de determinar o destino de todos.'),
 h2('II / A Unidade Absoluta'),p('Senu aceita o plano do Primeiro Copista. As consciências se fundem e o sofrimento diminui. A unidade, porém, apaga a individualidade e a capacidade de escolher. A promessa de proteção é realizada ao preço daquilo que fazia cada pessoa ser distinta.'),
 h2('III / O Caminho do Meio'),p('Na alternativa secreta, Senu compreende o problema e renuncia à imposição de uma resposta única. Ele desfaz a Inversão sem forçar a fusão das consciências nem destruir toda possibilidade de conhecimento. Esse caminho depende de investigação e descobertas opcionais, cujas condições ainda estão em desenvolvimento.'),
 h2('O que a escolha precisa carregar'),p('Os finais são o encerramento de uma pergunta apresentada desde o cais: o que significa ajudar alguém que está deixando de reconhecer o mundo? O reencontro parcial de Hori e Sabu não resolve a crise, mas oferece uma medida concreta do que pode estar em jogo quando Senu escuta a promessa de uma cura absoluta.')]
story += quote('A procura por Iri começa com a vontade de trazer alguém de volta. O fim da jornada pergunta quem pode decidir o que esse retorno deve custar.')
story += [PageBreak()]

# 14 - Glossary and traceability.
story+=section('12 / REFERÊNCIA','Nomes e fontes do projeto','fontes')
glossary=[
 ('Inversão','Crise que faz o mundo material e o Reverso se refletirem de maneira imperfeita.'),
 ('Reverso','Camada invisível da realidade envolvida na crise.'),
 ('Véus','Limiares entre percepção e realidade evocados pelo título.'),
 ('Coroa do Silêncio','Mecanismo central do plano de unificar as consciências.'),
 ('Primeira Palavra','Santuário sob Alexandria que funciona como ponto de retorno da jornada.'),
 ('Santuário da Palavra','Área A03 da campanha planejada, associada aos segredos da ordem.'),
 ('Santuário Soterrado','Local do Porto onde existe uma das quatro marcas de Iri.'),
 ('Marcas de Iri','Mensagens deixadas no Arquivo, Observatório, Santuário Soterrado e Guarita.'),
 ('Embarcadouro Velho','Píer onde Senu encontra Sabu trabalhando nas cordas.'),
]
table=Table([[p('<b>'+a+'</b>','gloss'),p(b,'gloss')] for a,b in glossary],colWidths=[138,CW-138])
table.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),0),('RIGHTPADDING',(0,0),(0,-1),11),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),7),('LINEBELOW',(0,0),(-1,-1),.35,RULE)]))
story += [table,Spacer(1,17),h2('Base editorial'),
 p('A abertura de 24 falas foi preservada a partir do texto aprovado. As marcas de Iri, a história de Hori e Sabu e as vozes dos moradores foram reunidas dos textos atuais do projeto. O universo, os capítulos e os finais foram organizados a partir da bíblia narrativa, preservando o caráter de planejamento das partes futuras.','small'),
 p('<b>História e campanha:</b> docs/O_NONO_VEU_GDD.md, seções 3 e 4.<br/><b>Abertura aprovada:</b> resources/dialogue/opening_fisherman.gd.<br/><b>Histórias do Porto:</b> scripts/world/port_story.gd.<br/><b>Moradores e bilhetes:</b> scripts/world/house_catalog.gd.','small'),
 p('<b>Arte:</b> capa em pixels e retrato do pescador pertencentes ao acervo visual do projeto.','small'),
 p('O Nono Véu | História e universo | 27 de outubro de 2026','small')]

doc=StoryDoc(str(PDF),pagesize=A4,leftMargin=M,rightMargin=M,topMargin=94,bottomMargin=62,
    title='O Nono Véu - História e Universo',author='Projeto O Nono Véu',
    subject='Abertura aprovada, universo, personagens e campanha planejada',
    pageCompression=1,allowSplitting=1)
doc.addPageTemplates([PageTemplate(id='Story',frames=[Frame(M,62,CW,H-156,leftPadding=0,rightPadding=0,topPadding=0,bottomPadding=0)],onPage=page)])
doc.build(story)
reader=PdfReader(PDF)
report={'pdf':str(PDF),'pages':len(reader.pages),'bytes':PDF.stat().st_size,
        'opening_lines':len(opening),'page_text_lengths':[len(pg.extract_text() or '') for pg in reader.pages]}
(TMP/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(report,ensure_ascii=False))
assert len(reader.pages)==14, f'Unexpected overflow: {len(reader.pages)} pages'
assert all(length>200 for length in report['page_text_lengths'][1:]),'Unexpected empty/short page'
alltext='\n'.join(pg.extract_text() or '' for pg in reader.pages)
for term in ['Senu','Iri','Erena','Hori','Sabu','Primeiro Copista','Caminho do Meio','Eu volto para contar o que encontrar.']:
    assert term in alltext,term
