# OBLITUS LIMBO — Volume I (Demo)

RPG de ação com combate em arena, adaptado do livro *Oblitus Limbo: Volume I*, de ByGuizo.
Feito em Three.js (WebGL 2): todos os modelos, texturas, efeitos, músicas e sons são gerados
proceduralmente no próprio jogo. As ilustrações dos personagens (em `assets/portraits`) são usadas
nos diálogos, no HUD e no Compêndio.

## Como jogar

1. Dê dois cliques em **`Jogar.bat`** (precisa do Python instalado).
   O navegador abre em `http://localhost:8765`.
2. Clique na tela para começar. Use fones de ouvido.

> Abrir o `index.html` direto (file://) não funciona: módulos JavaScript precisam de um servidor local.
> Alternativa manual: `python -m http.server 8765` nesta pasta.

Recomendado: Chrome ou Edge atualizados. Em PCs mais fracos, use **Opções → Qualidade gráfica → Média/Baixa**.

## Controles

| Tecla | Ação |
|---|---|
| W A S D | Mover |
| Mouse | Câmera |
| Clique esquerdo | Atacar (combo de 3 golpes; 4 durante o Apagão) |
| Clique direito (segurar) | Defender — no instante do golpe: **Aparar** (atordoa o inimigo) |
| Espaço | Esquivar — no último instante: **Esquiva Perfeita** (câmera lenta) |
| Shift | Correr |
| Q / botão do meio | Travar alvo |
| 1 · 2 · 3 | Habilidades |
| F | Fúria: **Apagão** → depois **Manifestação Harmônica** (Kiana) / **Punho Flamejante** (Viktor) |
| R / Tab | Poção |
| E | Interagir |
| Esc | Pausa |

**Kiana** — 1: Acorde Cortante (lâmina de som) · 2: Ressonância (onda de choque com o ukulele) · 3: Passo Sombrio (some e reaparece cravando a adaga).
**Viktor** — 1: Lança de Gelo · 2: Floresta de Lanças · 3: Gelo Negro.

## Conteúdo da demo

- **Prólogo — A Presença**: o coração do Limbo, a Segunda e a Presença.
- **Capítulo I — Um Fogo que Não Pertence a Este Mundo**: Vardun à noite (Velha Mira, Rurik, Near), a taverna de Darius, mais de vinte homens e o primeiro apagão.
- **Capítulo II — O Vale das Flores Sangrentas**: o diário dos oito dias, o loop espacial, as runas de Darin, a chegada de Calista e a Criatura Mutável (água → vento → fogo) com os quatro aliados; Amnon segura o núcleo em chamas. Depois: a lenda de Kynare e “O Alvorecer da Ausência”.
- **Capítulo III — Oblitus Limbo**: o salão do trono de Hikari, a revelação do Quinto Presságio, o sacrifício de Calista, o cristal de Krauser e a memória do orfanato, a Manifestação Harmônica, a mente de Krauser, Viktor jogável contra o Frio Absoluto, o Punho Flamejante e o ritual final.
- **Epílogo**: de volta ao Limbo.

O menu **Capítulos** permite ir direto para qualquer capítulo. O progresso e as opções ficam salvos no navegador.

## Estrutura

```
index.html        HUD, menus, diálogos e estilos
src/main.js       renderização, pós-processamento, entrada, diretor de roteiro, menus
src/story.js      roteiro de todos os capítulos (diálogos, cinemáticas, ondas, chefes)
src/actors.js     jogador (Kiana / Viktor), inimigos, chefes, aliados, NPCs
src/world.js      dano, defesa/aparar, ataques com aviso, projéteis, zonas, colisão
src/models.js     personagens procedurais, esqueleto e animações por keyframe
src/levels.js     cenários: Vardun, taverna, Vale, barreira do infinito, salão do trono, Limbo
src/fx.js         partículas, cortes, ondas de choque, avisos no chão
src/audio.js      trilha e efeitos sintetizados (inclui o tema “O Alvorecer da Ausência”)
src/textures.js   texturas procedurais
src/camera.js     câmera dinâmica (ombro, trava de alvo, tremor, cinemáticas)
vendor/           Three.js r186 (local, funciona offline)
```
