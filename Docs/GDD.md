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
| 5 | Laberinto de Recompensas | Aprendizaje | Aprendizaje por refuerzo | premios/castigos, Q-valores como calor | definido |
| 6 | Fábrica de Neuronas | Aprendizaje | Redes neuronales, pesos | perillas, activaciones visibles | definido |
| 7 | Ojos de AI CAT | Percepción | Visión por computadora | píxeles, bordes, cámara on-device | definido |
| 8 | Voz de AI CAT | Interacción natural | Lenguaje natural, tokens | hablarle al gato (voz + modelo on-device) | definido |
| 9 | Balanza Justa | Impacto social | Sesgo, justicia, privacidad | arreglar un dataset sesgado | definido |
| 10 | Laboratorio Creativo | Interacción natural | IA generativa, proyecto final | crear con el modelo on-device; graduación | definido |

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
- M9: 5 (Q-learning tabular visible) y 6 (red de 2 capas con perillas).
- M10: 7 (Vision on-device) y 8 (reconocimiento de voz on-device + Foundation Models), con permisos localizados y puerta parental.
- M11: 9 y 10, exportación de "mi mini IA", graduación.
- Arte: sustituir el gato y los mundos procedurales por USDZ (`Docs/ART_PIPELINE.md`).
