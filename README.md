# Oblitus Limbo — o jogo (teste com IA)

Adaptação em jogo de ação 3D do livro **Oblitus Limbo: Volume I**, de **ByGuizo**.
Feito em **Godot 4.7** com visual cel-shading no estilo *Naruto Shippuden: Ultimate Ninja Storm*,
desenvolvido com assistência de IA (Claude).

## Modos

- **História** — Prólogo e 3 capítulos do livro: Vardun, a taverna de Darius, o Vale das Flores
  Sangrentas e o salão do trono de Hikari, com cinemáticas, diálogos e chefes.
- **Versus (1 × CPU)** — luta estilo Storm em rounds, com 8 personagens:
  Kiana, Viktor, Near, Darin, Amnon, Calista, Krauser e Yuto.
  Cada um tem combos próprios, 3 habilidades, despertar e Ultimate cinematográfico com cut-in.

## Como jogar

1. Baixe o **Godot 4.7.2 (Standard, Windows)** em <https://godotengine.org/download/archive/>.
2. Coloque o executável em `engine/Godot_v4.7.2-stable_win64.exe` e rode `Jogar.bat`
   — ou abra a pasta `OblitusLimbo/` pelo editor do Godot e aperte F5.

Na primeira abertura o Godot importa os assets (leva alguns minutos).

## Controles

| Tecla | Ação |
|---|---|
| W A S D / Mouse | Mover / câmera |
| Clique esquerdo / direito | Ataque leve / pesado (ramifica e finaliza combos) |
| Espaço | Esquiva (perfeita = câmera lenta) · no Versus, apanhando: **Substituição** |
| C (segurar) | Defender · no tempo certo: Aparar |
| Shift | Correr · no Versus: investida de chakra |
| 1 2 3 | Habilidades |
| F / segurar F | Ultimate / Despertar |
| R | Poção · no Versus: carregar chakra |
| Q | Travar alvo |
| Enter/Espaço (segurar) | Pular cena |

## Estrutura

- `OblitusLimbo/` — projeto Godot (cenas, scripts, shaders e assets usados).
  - `scripts/combat/kits/` — um arquivo por personagem jogável (habilidades, despertar, Ultimate).
  - `scripts/versus/` — modo Versus e a CPU.
  - `scripts/story/` — roteiro do modo história.
- `tools/` — scripts de apoio (geração de rostos, texturas de efeitos, testes automáticos).
- `versao_web/` — primeira versão do jogo, no navegador.

## Créditos

- História, personagens e artes dos personagens: **ByGuizo** (todos os direitos reservados).
- Modelos 3D: Quaternius (Universal Animation Library, Modular Outfits, Medieval Village,
  Stylized Nature) e KayKit — Kay Lousberg (Dungeon Remastered, Fantasy Weapons) — CC0.
- Texturas pintadas à mão: Lynocs — Stylized Texture Pack (CC0).
- Fontes: Cinzel, Cinzel Decorative, Cormorant e Kaushan Script (SIL Open Font License).
- Motor: Godot Engine (MIT).
