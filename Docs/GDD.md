# AI CAT — Documento de diseño (GDD)

> Juego iOS para enseñar los fundamentos de la inteligencia artificial a niños de 6 a 12 años, guiados por **AI CAT**, un gatito negro que crece con cada reto. Bilingüe (ES/EN), 100 % en el dispositivo, diseñado primero para **iPhone Duo** y compatible con cualquier iPhone con iOS 26.

## 1. Visión

- **Promesa**: "Enseñas a un gatito y, sin darte cuenta, aprendes cómo aprende una máquina."
- **Tono**: cálido, curioso, honesto. AI CAT nunca "sabe" por arte de magia: en cada reto el niño ve de dónde sale su conocimiento (sus propios ejemplos).
- **Crecimiento como recompensa**: el gato crece físicamente (morfología continua de gatito a adulto) y en conocimiento (accesorios y nuevas frases). No hay monedas ni compras.

## 2. Público y bandas de edad

| Banda | Edad | d₀ | Pistas | Cronómetro | Texto |
|---|---|---|---|---|---|
| Explorador | 6–7 | 0.20 | automáticas | no | ≤ 8 palabras por frase, todo leído en voz alta |
| Aprendiz | 8–10 | 0.45 | a pedido (3, maestro 1) | no | ≤ 14 palabras |
| Maestro | 11–12 | 0.70 | a pedido (1, maestro 0) | suave | ≤ 20 palabras, números reales de la IA |

La banda la elige un adulto en la **zona de padres** (puerta parental: mantener pulsado + suma). El niño solo nombra al gato.

## 3. Currículo (alineado a las "Five Big Ideas in AI" de AI4K12)

| # | Mundo | Gran idea | Concepto | Mecánica | Estado |
|---|---|---|---|---|---|
| 1 | Jardín de Patrones | Percepción | ¿Qué es IA? Patrones y reglas | arrastrar frutas 3D a canastas; AI CAT aprende la regla | **jugable** |
| 2 | Biblioteca de Datos | Aprendizaje | Datos, etiquetas, calidad | etiquetar tarjetas; medidor de precisión k-NN; ratón travieso | **jugable** |
| 3 | Taller de Clasificación | Aprendizaje | Clasificador, frontera de decisión | tablero 2D (tamaño × pelusa): umbral, línea o centroides; medidor de precisión; animales de prueba | **jugable** |
| 4 | Sendero de Instrucciones | Representación | Algoritmos, si/entonces, bucles | bloques de instrucciones que AI CAT ejecuta en 3D (avanzar, girar, saltar, SI charco, REPETIR) | **jugable** |
| 5 | Laberinto de Recompensas | Aprendizaje | Aprendizaje por refuerzo | el niño diseña el laberinto (premio, charcos); Q-learning tabular; casillas pintadas con V(s); repetición del mejor camino en 3D | **jugable** |
| 6 | Fábrica de Neuronas | Aprendizaje | Redes neuronales, pesos | neuronas de cables ternarios y umbral; dos capas; red sigmoide que se entrena sola con curva de error | **jugable** |
| 7 | Ojos de AI CAT | Percepción | Visión por computadora | píxeles con números, detector de bordes por umbral, emparejado de formas por pistas, cámara con Vision on-device (o imágenes de muestra) | **jugable** |
| 8 | Voz de AI CAT | Interacción natural | Lenguaje natural, tokens | tokenizador por fichas, bigramas contables, voz a texto on-device (o fichas), respuestas con errores plantados | **jugable** |
| 9 | Balanza Justa | Impacto social | Sesgo, justicia, privacidad | grupo faltante, balancear el dataset (balanza 3D), minimización de datos, juzgar casos | **jugable** |
| 10 | Laboratorio Creativo | Interacción natural | IA generativa, proyecto final | semillas de historia (gramática generativa o modelo on-device), remezcla, diseño de un ayudante, examen de graduación | **jugable** |

Cada mundo tiene 3 retos (tier 1, 2, 3) y un **reto maestro** (tier 3, opcional para avanzar). Todo el texto (títulos, objetivos, conceptos, guion de AI CAT) existe en ES y EN en `Tools/strings_source.py`; la estructura vive como literales Swift en `Packages/AICatCore/Sources/AICatCore/Curriculum.swift`.

### 3.1 Jardín de Patrones (detalle)

1. **¿Roja o verde?** — regla dicha. El niño sigue la regla; AI CAT observa.
2. **El patrón secreto** — regla oculta en un atributo (color o forma); el niño la descubre probando.
3. **Dos pistas a la vez** — conjunción (p. ej. rojas Y redondas → canasta 1).
4. **Maestro del jardín** — tres atributos activos, regla aleatoria, menos pistas.

**La IA real detrás**: AI CAT usa un *decision stump* (ID3 de un nivel) sobre los ejemplos correctos del niño. Solo se compromete cuando **exactamente una** hipótesis es consistente con los ejemplos (idea de *version space*): si dos atributos explican los datos, pide más ejemplos; en los niveles de conjunción acepta una regla de dos pistas solo cuando todas las reglas de una pista han sido refutadas. Cuando aprende, acarrea él mismo las frutas que puede clasificar; las de valores nunca vistos se las deja al niño ("necesito ver más frutas").

### 3.2 Biblioteca de Datos (detalle)

1. **¿Gato o perro?** — etiquetar; el medidor sube.
2. **Tres animales** — gato, perro y ave.
3. **El ratón travieso** — una etiqueta ya está mal: hay que encontrarla y arreglarla.
4. **Maestro de la biblioteca** — rasgos ruidosos y dos etiquetas cambiadas.

**La IA real detrás**: un clasificador **k-NN (k = 3)** sobre tres rasgos (tamaño, orejas puntiagudas, canto) cuyo único conocimiento son las etiquetas del niño (incluidas las erróneas, que se quedan hasta que se corrigen). El medidor evalúa un conjunto de prueba oculto. Cada etiqueta aparece como un bloque de datos en la pila de AI CAT en el escenario 3D; los bloques erróneos brillan en rojo.

### 3.3 Taller de Clasificación (detalle)

1. **Grande o pequeño** — dos grupos separables por el eje *tamaño*; el modelo es un **umbral** `x = t` que el niño arrastra.
2. **Traza la línea** — dos grupos separables en diagonal; el modelo es una **recta** por dos manijas.
3. **Tres grupos** — tres clases; el modelo son **tres centroides** (clasificación por centroide más cercano).
4. **Maestro constructor** — tres clases con 2 **valores atípicos** (animales colocados en el grupo equivocado). El niño puede marcarlos con ❌ para excluirlos; marcar un animal real cuenta como error.

**La IA real detrás**: el tablero es el espacio de rasgos `[0,1]²` (tamaño, pelusa). Los puntos de cada clase se muestrean alrededor de centros fijos con ruido uniforme `±0.11` (semilla determinista). La predicción es `signo(x − t)` (umbral), el **signo del producto cruzado** `(b − a) × (p − a)` (recta; la polaridad se elige con los datos para que la etiqueta "del lado correcto" no dependa de la dirección en que el niño trace la recta) o `argmin_k ‖p − c_k‖` (centroides). Precisión de entrenamiento `acc = correctos / (puntos no marcados + reales marcados)`, meta `0.9`. Al pulsar "¡Listo!" el mismo modelo clasifica **animales de prueba** no vistos: la generalización se ve en pantalla. La pista mueve el modelo a mitad de camino hacia el **modelo ideal** (umbral = punto medio entre centros; recta = mediatriz; centroides = medias reales). XP: `acc` si se alcanzó la meta, `acc/2` si no.

### 3.4 Sendero de Instrucciones (detalle)

1. **Primeros pasos** — avanzar/girar, 3 pasos hasta el pez; presupuesto de 6 bloques.
2. **Si hay un charco** — aparece `SI charco adelante: salta`; sin él, AI CAT cae al charco (¡splash!) y vuelve al inicio.
3. **Otra vez y otra vez** — `REPETIR n: avanzar` (n = 2…5) para subir una escalera larga con pocos bloques.
4. **Maestro explorador** — SI + REPETIR combinados en un sendero con esquina.

**La IA real detrás**: un **intérprete** determinista (`TrailInterpreter`) ejecuta el programa sobre una cuadrícula con orientación (N/E/S/O); los bloques de control cuestan 2 del presupuesto (el bloque y su cuerpo), hay dos trazados por nivel elegidos por `semilla mod 2`, y un límite de 60 pasos convierte un bucle infinito en el resultado "ese programa nunca termina". Resultados: `goal`, `splash`, `lost` (se detuvo antes del pez) y `tooLong`. Cada ejecución se anima en el mundo 3D: el gato camina celda a celda y gira con la pose correspondiente. Puntuación `s = max(0.55, 1 − 0.15·(ejecuciones − 1))` si llegó al pez; `0` si no.

### 3.5 Laberinto de Recompensas (detalle)

1. **Un premio al final** — el niño coloca el premio (a ≥ 2 casillas); AI CAT explora y lo encuentra.
2. **Cuidado con los charcos** — premio fijo; el niño coloca 1 charco (castigo) y ve cómo cambia el camino aprendido.
3. **Casillas tibias** — laberinto de 6×6; el niño coloca el premio (a ≥ 4 casillas) y hasta 2 charcos; las casillas se pintan con lo que AI CAT espera.
4. **Maestro del laberinto** — 7×7 con un pasillo corto y una vuelta larga; el niño coloca 3 charcos y elige la curiosidad (ε ∈ {0.05, 0.3, 0.8}). Solo cuenta si el camino aprendido es **largo y seguro** (más largo que la distancia Manhattan).

**La IA real detrás**: **Q-learning tabular** sobre la cuadrícula: `Q(s,a) ← Q(s,a) + α·(r + γ·max_a' Q(s',a') − Q(s,a))` con α = 0.5, γ = 0.9, exploración ε-greedy (ε = 0.3 salvo en el maestro), 60 pasos por episodio, recompensas: paso −0.04, chocar −0.10, premio +1 (terminal), charco −1 (terminal). Cada "¡Explora!" corre una tanda de episodios (n = ítems + extra por nivel): el primero se anima en el escenario (el gatito deambula), después las casillas se pintan con `V(s) = max_a Q(s,a)` (cálido positivo, azul negativo) y se reproduce la política **greedy** desde el inicio. Resuelto cuando esa reproducción llega al premio (y da el rodeo exigido en el maestro). Cualquier cambio al mapa **borra la tabla Q** (los valores viejos ya no son verdad: honestidad con el niño). Trazados a mano (2 por nivel, `semilla mod 2`) con la garantía, probada en tests, de que toda casilla libre es alcanzable. Calibración en Python (40 semillas): nivel 1 en 2–3 tandas, nivel 4 con el pasillo bloqueado en 4–6 tandas de 10–12 episodios. Puntuación: `max(0.6, 1 − 0.06·max(0, tandas − 3))`; las pistas son tandas gratis.

### 3.6 Fábrica de Neuronas (detalle)

1. **Una neurona** — 2 lámparas de entrada, 3 perillas: dos cables ⚪/🟢/🔴 (peso 0/+1/−1) y el umbral "enciende si el total es al menos k".
2. **Tres entradas** — 3 cables + umbral; reglas como "al menos dos", "la primera y la segunda", "la segunda pero no la tercera".
3. **Dos capas** — 2 neuronas ocultas + neurona de salida (11 perillas) para patrones como XOR o "exactamente una encendida". Los ejemplos mostrados se eligen de modo que **ninguna neurona de una capa** los pueda resolver (comprobación por fuerza bruta: 3ⁿ·(n+1) candidatos).
4. **Maestro ingeniero** — red 4-3-1 con sigmoides sobre la tabla de verdad completa (16 filas); el niño elige la velocidad de aprendizaje 🐢 0.5 / 🐇 3 / 🚀 20, pulsa "Entrenar" (60 épocas) y ve la curva de error; puede pedir "pesos nuevos" (reinicio aleatorio).

**La IA real detrás**: niveles 1–3, neuronas **ternarias** `y = [Σ wᵢxᵢ ≥ k]` con `wᵢ ∈ {−1,0,1}`, `k ∈ 0…n`; la pista pone la primera perilla que difiere de la solución guardada. Nivel 4, **descenso de gradiente** por lotes completos con entropía cruzada: `∂L/∂z_out = o − t`, `∂L/∂z_h = (o − t)·w₂·h·(1 − h)`, pesos iniciales U(−0.8, 0.8) con semilla. Medido en Python (40 semillas): con η = 3 la regla XOR converge en 167 épocas (mediana, máx. 354) y "al menos tres" en ~30; con η = 20 solo 5/40 convergen (rebota: lección de "demasiado rápido"); con η = 0.5 XOR tarda ~1000 épocas (lección de "demasiado lento"). Puntuación: niveles 1–3 `max(0.7, 1 − 0.02·max(0, giros − 2·perillas))` si resuelto, si no `aciertos/2`; nivel 4 `max(0.6, 1 − 0.05·max(0, pulsaciones − 3))`.

### 3.9 Balanza Justa (detalle)

1. **Solo gatos negros** — el dataset se muestra con conteos por pelaje y los aciertos de AI CAT con gatos nuevos (✓/✗); el niño toca el pelaje que falta en los ejemplos.
2. **Equilibra la balanza** — mover tarjetas de una reserva al dataset hasta que cada pelaje tenga ≥ k ejemplos (k = 2, maestro 3); la balanza 3D se inclina con la brecha.
3. **Mantenlo privado** — decidir qué datos guarda una app: **solo si el juego lo necesita Y no es privado** (minimización de datos: "tu color favorito" no es privado, pero tampoco necesario).
4. **Maestro juez** — 2–4 casos reales (un gato naranja "perro", juguetes por género, caras guardadas para avatares, nadie leyó el ensayo…): causa + remedio.

**La IA real detrás**: el simulador de reconocimiento es `rec(g) = min(1, n_g / k)` por grupo y la **brecha de justicia** `max_g rec(g) − min_g rec(g)` (una métrica de igualdad de oportunidades simplificada); la balanza del escenario rota `−0.35·brecha` rad. Las pruebas garantizan que en el nivel 1 falta exactamente un pelaje y que en el nivel 2 la reserva alcanza para todos. Puntuación: nivel 1 `max(0.5, 1 − 0.25·fallos)`; nivel 2 `max(0.7, 1 − 0.05·tarjetas de más)`; niveles 3 y 4, fracción de aciertos.

### 3.10 Laboratorio Creativo (detalle)

1. **Semillas de historia** — elegir quién/dónde/qué entre fichas (nunca texto libre) y "hacer crecer" la historia; hay que producir 2–3 historias con semillas distintas.
2. **Remezcla** — tocar una oración la cambia por otra variante; cambiar ≥ 2–3 y elegir título.
3. **Diseña un ayudante** — objetivo, datos y reglas para "mi IA ayudante" contra una lista de 6 comprobaciones (objetivo claro, datos que ayudan, sin datos privados, regla de privacidad, una persona revisa, sin reglas riesgosas).
4. **Graduación** — examen de 3–6 preguntas sobre los diez mundos + diploma con el nombre del gato y las estadísticas.

**La IA real detrás**: la historia sale de un **modelo generativo mínimo**: una gramática de 3 oraciones × 3 variantes con huecos (%1 personaje, %2 lugar, %3 objeto) muestreada con semilla (`SeededGenerator`): mismas semillas ⇒ misma historia; cambiar una palabra cambia la historia. Con **modo creativo** (opt-in parental) y Apple Intelligence disponible, el modelo on-device escribe las tres oraciones (`@Generable ModelStory`, 8 s de tope, cada oración por `KidSafeFilter`; si algo falla, queda la historia de patrones) y la tarjeta dice quién la escribió. Las plantillas evitan concordancias de género en español (sin pronombres ni adjetivos tras los huecos).

### 3.7 Ojos de AI CAT (detalle)

1. **Píxeles** — una imagen de 10×10 dígitos (0 negro … 9 blanco) que también se construye en el escenario con cubitos; el niño acerca (imagen → cuadrícula → números) y toca los píxeles con 9.
2. **Bordes** — un **detector de bordes**: `g(p) = max_{q vecino} |I(q) − I(p)|`; la perilla es el umbral `t` y se iluminan los píxeles con `g ≥ t`. Se mide con **F1** contra el contorno real (píxeles junto a un píxel del otro lado del nivel 5); con sombreado interno 6–8 y fondo 0–2, solo `t ≈ 4` da F1 ≥ 0.8 (probado para 12 semillas).
3. **Formas** — emparejado por plantilla: la consulta es una plantilla con 7–13 píxeles cambiados; las **pistas** son los píxeles que coinciden (|Δ| ≤ 2); gana la plantilla con más pistas (probado).
4. **Maestro de la vista** — cámara trasera + `VNClassifyImageRequest` (Vision, on-device) a ~1 fotograma/s; el niño marca cada conjetura como acierto/fallo. Sin cámara, sin permiso o en simulador: imágenes de muestra (emoji renderizado y clasificado por Vision). Puerta parental antes de la cámara; nada se guarda.

### 3.8 Voz de AI CAT (detalle)

1. **Tokens** — tokenizador **greedy de prefijo más largo** sobre un vocabulario pequeño (WordPiece de juguete): el niño reconstruye la palabra con fichas (piezas + distractores) en el orden del tokenizador; las letras sin pieza se vuelven trozos de ≤ 3 caracteres.
2. **Adivina la siguiente palabra** — **modelo de bigramas** `P(w'|w) = c(w,w')/c(w,·)` sobre 8 oraciones visibles; el niño elige entre 3 opciones y compara con el argmax (empates en orden alfabético); después se muestran los conteos.
3. **Háblame** — `SFSpeechRecognizer` con `requiresOnDeviceRecognition` (solo en el dispositivo, nunca se graba), 7 s por oración; la transcripción se tokeniza. Puerta parental antes del micrófono; sin soporte o permiso, fichas "imagina que dijiste…".
4. **Maestro de las palabras** — conversación con respuestas **mal plantadas** (araña de seis patas, luna de queso, "nunca me equivoco"): el niño marca cada respuesta como bien/mal. Extra con modo creativo: tres preguntas fijas al modelo on-device (respuesta filtrada por `KidSafeFilter`, rotulada "puede sonar seguro y aun así equivocarse").

## 4. Modelos matemáticos

### 4.1 Crecimiento

- XP por reto: `xp = 100 · tier · clamp(precisión, 0.5, 1)` (reto fallido: 25 XP de consuelo).
- Crecimiento normalizado: `ĝ = clamp(XP / 7200, 0, 1)` (7200 = 80 % del máximo teórico de 9000, para que un juego imperfecto también llegue a adulto). Etapa visible `s = ⌊10·ĝ⌋`; un mundo completo ≈ una etapa.
- *Nota de diseño*: se evaluó primero una logística `g(x)=1/(1+e^{-k(x-x₀)})`; se descartó porque mantenía al gato en etapa 0 durante ~2.4 mundos. El modelo lineal con `smoothstep` en la morfología da progreso visible en cada reto.
- Morfología: `p(ĝ) = p_gatito + (p_adulto − p_gatito)·smoothstep(ĝ)` para longitud del cuerpo (0.18→0.45 m), razón cabeza/cuerpo (0.42→0.30), patas (0.05→0.16 m), orejas (1.3→1.0), cola (0.10→0.30 m), ojos/cabeza (0.28→0.18). La cámara se reencuadra con la altura resultante.

### 4.2 Dificultad adaptativa

`d_{n+1} = clamp(d_n + 0.15·(s_n − 0.75), 0, 1)`; el número de elementos de un reto es `n(d) = ⌊n_min + (n_max − n_min)·d + 0.5⌋`. Cada banda fija `d₀`.

### 4.3 Valores dorados

`Tools/reference_model.py` implementa estos modelos en Python, valida invariantes (monotonía, límites, bordes de etapa) y genera `GoldenValues.swift`; las pruebas de `AICatCore` (`swift test`) verifican que Swift produce exactamente los mismos números.

## 5. AI CAT

- **Personalidad**: curioso, amable, celebra el esfuerzo, admite cuando no está seguro.
- **Emociones** (ojos, orejas, cola): happy, curious, proud, thinking, sleepy, excited, sad. **Gestos**: nod, jump, tailWag, headTilt, stretch, pounce, sit, shake.
- **Guion**: 46 líneas por momento (saludo, inicio de reto, acierto, error, pista, aprendió, necesita más, reto completo, mundo completo, subió de etapa, inactividad, ánimo, bloqueado, trampa) + una intro por mundo. `ScriptedBrain` es el juego completo.
- **Apple Intelligence** (`FoundationModelsBrain`, iOS 26): por defecto el modelo on-device solo **elige** entre las líneas del guion; con "AI CAT creativo" (opt-in del adulto) puede escribir una frase corta que pasa por `KidSafeFilter`. `BrainRouter` serializa, aplica un tiempo máximo de 4 s y vuelve al guion ante cualquier error.
- **Voz**: `AVSpeechSynthesizer` on-device (es-MX / en-US), tono infantil. La escucha (escenario 8) se implementará con reconocimiento on-device cuando ese mundo sea jugable; hasta entonces no se pide el micrófono.

## 6. iPhone Duo

| Postura | Señal | Layout |
|---|---|---|
| Bolsillo (`pocket`) | ancho compacto (cerrado o iPhone en vertical) | escenario arriba (42 %), tablero abajo |
| Mundo (`world`) | ancho regular, sin división activa | `ArrangementView` (split) con tablero y escenario |
| Laboratorio (`lab`) | división activa más ancha que alta (pose mesa) | escenario sobre el pliegue, controles debajo |
| Libro (`book`) | división activa más alta que ancha | tablero en una página, escenario en la otra |

- El layout usa **regiones reservadas** (`reservedRegions(kind: .division)`); el **ángulo de bisagra** (`onHingeChange`) solo produce efectos: amanecer del sol (`θ = clamp((ángulo − 90°)/90°)`), vistazo del gato al cambiar de plegado, insignia de depuración.
- Todo está en `AICat/Layout/Duo/` bajo `#if AICAT_DUO` y `#available(iOS 27.1, *)`; sin el flag el juego compila con Xcode 26 y usa clases de tamaño.
- Reducir movimiento (sistema o zona de padres) desactiva amanecer, partículas y gestos por plegado.

## 7. Arquitectura

```
AICatApp → AppModel (@Observable, MainActor): perfil, navegación, voz, cerebro, línea actual
RootView → Onboarding | NavigationStack(ScenarioMap → ScenarioHost → ChallengeHost) + hoja Zona de padres
ChallengeHost → PostureReader → AdaptiveStage(StageView(WorldModel), Board)
WorldModel → RealityKit: set por tema, luces, cámara, CatRig (procedural o USDZ), props, tick por frame
Controladores de reto (PatternGarden, DataLibrary) → AICatCore (estado puro) + WorldModel (3D) + ChallengeSession (XP)
AICatCore (SwiftPM, solo Foundation) → currículo, crecimiento, dificultad, puntuación, learners, máquinas de estado
```

- La animación por frame usa la suscripción `SceneEvents.Update` (verificada en la documentación) en lugar de un `System` ECS, para reducir riesgo de compilación a ciegas.
- La física es cosmética: la puntuación se decide por distancia XZ a la canasta en `DragPlaneMath` (probado).
- Persistencia: `PlayerProfile` como JSON atómico en Application Support. Sin red, sin analítica, sin anuncios.

## 8. Seguridad y privacidad (categoría Kids)

- No se pide nombre ni fecha de nacimiento del niño. Se nombra al gato.
- Zona de padres tras puerta parental; política de privacidad como texto dentro de la app.
- `PrivacyInfo.xcprivacy` sin seguimiento ni datos recolectados; `ITSAppUsesNonExemptEncryption = NO`.
- El niño nunca escribe texto libre hacia el modelo; el modo generativo requiere opt-in del adulto y filtro.

## 9. Hoja de ruta

- M8 ✅: escenarios 3 (tablero 2D: umbral, recta, centroides, atípicos) y 4 (bloques de instrucciones ejecutados por el gato), reutilizando `ChallengeSession` y `AdaptiveStage`.
- M9 ✅: 5 (Q-learning tabular visible, el niño diseña el laberinto) y 6 (neuronas ternarias por perillas, dos capas, red sigmoide que se entrena sola).
- M10 ✅: 9 (sesgo, balance, privacidad, juez) y 10 (historias generativas, remezcla, ayudante, graduación). Se adelantó a 7 y 8 porque se verifica por completo sin dispositivo.
- M11 ✅: 7 (píxeles, bordes, formas, Vision on-device) y 8 (tokens, bigramas, voz on-device, conversación), con permisos localizados (`InfoPlist.xcstrings`) y puerta parental antes de cámara y micrófono.
- Pendiente: pruebas en dispositivo (Xcode 26/27.1), arte USDZ (`Docs/ART_PIPELINE.md`), pulido de audio y accesibilidad.
