# Plan de QA manual en la Mac

Guion para la primera sesión con Xcode: cada bloque dice qué tocar y qué debe pasar. Idioma: prueba todo una vez en español y una vez en inglés (zona de padres → idioma). Dispositivo de referencia: iPhone 17 (simulador) y, con Xcode 27.1, iPhone Duo en Device Hub (poses cerrado, abierto, mesa y libro).

## 0. Arranque

> Estado: la app compila para simulador en GitHub Actions con Xcode 26.6 (`AICAT_DUO` off) y se lanza en un simulador iPhone con `-AICatSmoke tour`: los 40 retos abren, preparan su mundo, crean su controlador y renderizan, con posturas y crecimiento probados (job `ios-app`). Lo que sigue siendo manual: iPhone Duo real (Xcode 27.1), Foundation Models, cámara y micrófono reales, y el juicio visual de este documento. En la Mac, `Tools/xcode_smoke.sh --no-duo` debería pasar a la primera; `Tools/xcode_smoke.sh` (Duo on) requiere Xcode 27.1 y es la única parte sin compilar.

- `Tools/xcode_smoke.sh` (Xcode 27.1) o `Tools/xcode_smoke.sh --no-duo` (Xcode 26): pruebas del paquete en verde y build del simulador sin errores.
- Primer arranque: onboarding pide solo el nombre del gato (nunca el del niño) y el idioma. AI CAT saluda en voz alta.
- Zona de padres: mantener la pata 2 s + suma correcta → ajustes. Cambiar banda de edad, idioma, voz, modo creativo y "reducir efectos" se reflejan al instante.
- Mapa: solo el mundo 1 abierto; los demás con candado y mensaje de AI CAT.

## 1. Jardín de Patrones

- Nivel 1: arrastrar frutas a canastas; soltar fuera de una canasta la deja caer (física). El medidor sube con cada acierto.
- Nivel 2–3: tras los primeros ejemplos AI CAT dice que aprendió la regla y lleva el resto él mismo.
- Maestro: regla de dos atributos. Al terminar: estrellas, XP y el gato crece un poco.

## 2. Biblioteca de Datos

- Etiquetar tarjetas gato/perro/ave; el medidor k-NN sube; una etiqueta errónea (ratón) brilla en rojo y baja el medidor hasta corregirla.

## 3. Taller de Clasificación

- Nivel 1: arrastrar la línea roja hasta separar; medidor ≥ 90 % habilita "¡Listo!"; después se ven los animales de prueba con ✓/✗.
- Nivel 2: dos manijas rojas forman una recta. Nivel 3: tres centroides de color. Maestro: tocar un animal raro lo marca ❌ (marcar uno real baja la precisión).
- Las esferas del taller en 3D brillan cuando el clasificador separa bien.

## 4. Sendero de Instrucciones

- Bloques: avanzar, girar, saltar, SI charco, REPETIR n (selector 2–5). El presupuesto se descuenta (bloques de control cuestan 2).
- "¡Corre, AI CAT!": el gato camina celda a celda en 3D; charco → splash y vuelve al inicio; pez → celebración.
- Un programa con muchos REPETIR termina con "ese programa nunca termina".

## 5. Laberinto de Recompensas

- Nivel 1: poner el premio (a ≥ 2 casillas; muy cerca avisa), "¡Explora!": el gatito deambula en 3D, las casillas se calientan, luego prueba el mejor camino. 2–3 exploraciones hasta resolver.
- Nivel 2: poner 1 charco en el camino corto; el camino aprendido lo rodea. Cambiar el mapa borra el calor (AI CAT olvida).
- Maestro: bloquear el pasillo con charcos; el selector de curiosidad cambia cuánto deambula. Camino largo y seguro → resuelto; camino corto → aviso "hazlo peligroso".

## 6. Fábrica de Neuronas

- Niveles 1–3: tocar cables ⚪→🟢→🔴, perilla "al menos k"; cada fila de ejemplos marca ✓/✗ y las lámparas de la máquina 3D siguen la fila seleccionada. Todos ✓ → celebración automática.
- Maestro: 🐢/🐇/🚀 + "Entrenar": barras de error bajan; 🚀 suele rebotar; "pesos nuevos" reinicia.

## 7. Ojos de AI CAT

- Nivel 1: con zoom "Imagen" o "Cuadrícula" tocar un píxel avisa que falta acercar; en "Números" tocar los 9 los ilumina (también los cubitos en 3D).
- Nivel 2: perilla − / +; "coincidencia con el contorno" llega a ≥ 80 % cerca de 4.
- Nivel 3: la plantilla con más pistas es la correcta; 3–4 rondas.
- Maestro: "Llamar a un adulto" → puerta parental → "Abrir los ojos de AI CAT" → permiso de cámara (texto localizado) → vista en vivo con conjeturas y botones Acertó/Falló. Negar el permiso o usar simulador → imágenes de muestra. Al salir del nivel la cámara se apaga.

## 8. Voz de AI CAT

- Nivel 1: fichas en orden; ficha equivocada avisa sin avanzar.
- Nivel 2: la respuesta es la palabra que más veces sigue en las oraciones visibles; después se muestran los conteos.
- Nivel 3: puerta parental → "¡Escucha, AI CAT!" → permisos de micrófono y reconocimiento (textos localizados) → hablar una oración → texto + tokens. Sin permiso/soporte: fichas "imagina que dijiste…" completan el nivel.
- Maestro: marcar cada respuesta como bien/mal; las plantadas (araña de seis patas, luna de queso, "nunca me equivoco") son "mal". Con modo creativo: tres preguntas al modelo; la respuesta va rotulada.

## 9. Balanza Justa

- Nivel 1: el pelaje con 0 ejemplos es el que falla en los gatos nuevos; tocarlo resuelve.
- Nivel 2: mover tarjetas a los ejemplos; la balanza 3D se nivela cuando la brecha llega a 0 %.
- Nivel 3: Guardar / No guardar; "tu color favorito" es "no guardar" (no es necesario).
- Maestro: causa + remedio por caso; "Dar mi veredicto".

## 10. Laboratorio Creativo

- Nivel 1: elegir quién/dónde/qué, "¡Haz crecer la historia!"; cambiar una palabra y repetir hasta 2–3 historias distintas. Con modo creativo y Apple Intelligence: "AI CAT está imaginando…" y la tarjeta dice "escrita por el modelo"; sin ello, "del libro de patrones".
- Nivel 2: tocar oraciones las cambia; título; "Guardar mi historia".
- Nivel 3: la lista de 6 chequeos guía; "¡Construirla!" con ≥ 4.
- Maestro: examen; diploma con el nombre del gato; al terminar el mundo 10 el gato lleva birrete.

## Transversales

- Duo: cerrado → pocket; abierto → dos paneles; mesa → mundo arriba y tablero abajo; libro → tablero en una página. Nunca controles sobre el pliegue; sin letterbox.
- Reducir movimiento: sin partículas ni amanecer.
- Cerrar y reabrir la app conserva progreso; "Reiniciar progreso" pide confirmación.
- VoiceOver lee casillas, píxeles, cables y tarjetas con su etiqueta; Dynamic Type grande no rompe los tableros (son ScrollView).

### Visual (texturas y sombras)

- Al entrar a cada mundo, el suelo muestra grano (pasto, losas, tablones, metal, arena, alfombra, azulejo) y no un color plano; si queda plano, `TextureLibrary.prepare` falló al subir la textura (revisar consola: `TextureResource(image:withName:options:)`).
- Troncos con corteza, copas/setos/arbustos con hojas, canastas de mimbre **del color de su canasta** (el niño sigue distinguiéndolas), pedestales de piedra apoyados sobre el suelo (no medio enterrados), bancos/estantes/escenario de madera, engranajes y chimeneas metálicas.
- Bajo el gato y bajo cada prop hay una sombra suave que no parpadea al mover la cámara (planos decorativos 0.003 m, sombras de props 0.006 m, sombra del gato 0.008 m); el sendero del mundo 4 y la alfombra de la biblioteca no "cortan" las sombras.
- El gato se lee como negro carbón con hebras visibles bajo la luz de contorno, nunca como una silueta plana ni como gris. Las hebras deben correr de la cabeza a la cola; si se ven como anillos alrededor del cuerpo, girar la textura 90° (`rotation: .pi / 2` en el `textureCoordinateTransform` de `Materials.fur`).
- Primera carga de un mundo con todas sus texturas: menos de 1 s en iPhone (medido en Linux -O: ≈ 400 ms en serie para el set del Jardín; se generan en paralelo y en segundo plano, 512² el suelo, 256² los props); cambiar de postura en el Duo o de mundo con texturas ya vistas no vuelve a generarlas.
- Modo claro/oscuro del sistema no cambia el mundo 3D (la iluminación es propia).
- El cielo muestra degradado, sol y nubes (no un degradado plano); las sombras del sol caen en la misma dirección que el sol del cielo. Si no hay sombras del sol en ningún mundo, cambiar la proyección fija por `.automatic(maximumDistance: 10)` en `Lighting.swift`.
- Las frutas del mundo 1 tienen poros finos y brillo; su color sigue siendo inequívoco (rojo, amarillo, verde, morado).
- El sol del cielo está del mismo lado que de donde vienen las sombras del sol. Si está en el lado opuesto o girado 90°, cambiar `ProceduralSky.equirectAzimuthOrigin` (0, 0.25, 0.5, 0.75) en el núcleo.
- Los biseles de las losas de piedra y las juntas de los tablones se ven hundidos/levantados de forma coherente con el sol. Si el relieve parece al revés, poner `ProceduralTextures.greenSign = -1`.
- El cuerpo y la cola del gato muestran hebras como la cabeza y las patas (cápsulas con UV); las frutas largas muestran poros.
- La cara en sombra del gato y de los props no es negra: se ve el relleno teñido del cielo.
- Los suelos texturizados se ven algo más oscuros que el color plano de la paleta (la textura multiplica en luz lineal: media 0.85–0.92 sRGB ≈ 0.70–0.82 lineal). Si un mundo queda apagado, subir la media de su textura en `NoiseField` o aclarar `palette.ground` en `Theme.swift`; `Tools/render_textures.sh` muestra las texturas tal cual se generan.
- Dentro de un reto, canastas, pedestales, frutas y props del controlador salen texturizados (el controlador se crea tras preparar texturas); no hay cuadrados negros bajo nada.

## Regresiones a vigilar (corregidas tras las revisiones adversariales)

- Mundo 1: tras aprender la regla, AI CAT **camina y lleva** las frutas restantes antes de que aparezca el resultado.
- Mundos 1 y 2: tocar "pista" mientras una pista brilla no gasta otra pista; soltar mal una fruta y volver a agarrarla de inmediato no la hace temblar.
- Mundo 3: arrastrar una manija o un centroide **hacia arriba o abajo** mueve la manija (el tablero no se desplaza).
- Mundo 4: llegar al pez en la cuarta ejecución o después aprueba (nunca "celebrar y reprobar"); una pista con REPETIR pone el selector en el número correcto; pedir pista con un programa ya correcto no lo borra; tocar "Corre" dos veces seguidas no teletransporta al gato.
- Mundo 5: la barra de progreso empieza en 0 y sube con lo cerca que llega el mejor camino.
- Mundo 6: las pistas respetan un diseño distinto pero válido (p. ej. neuronas ocultas intercambiadas) y siempre convergen.
- Mundo 7: con cámara negra o fallida aparece "usar imágenes de muestra"; girar el teléfono no apaga la cámara; en horizontal la vista previa no sale de lado.
- Mundo 8: con una llamada en curso, "Escucha" no cierra la app (muestra "no disponible"); dos escuchas seguidas no se cortan; girar el teléfono no cancela la escucha.
- Mundo 9: tocar el pelaje correcto en el nivel 1 **termina el reto** y desbloquea el nivel 2; las pistas de privacidad siguen disponibles mientras haya respuestas mal.
- Mundo 10: con modo creativo y Apple Intelligence, la historia sí la escribe el modelo (tarjeta "escrita por el modelo"), no siempre el libro de patrones.
- Todos: AI CAT dice una frase si el niño pasa 35 s sin avanzar; cambiar de postura en el Duo no reinicia cámara, micrófono ni ejecuciones.
- Puerta parental: mantener 2 s, luego escribir la suma; una respuesta mala bloquea 5 s y cambia la pregunta; Cancelar cierra.
- Al tocar "Siguiente" en el resultado, la frase de inicio del nuevo reto se oye completa (no se corta).
- Girar el teléfono o plegar el Duo mientras carga un reto no deja el escenario vacío ni congelado.
- Con el interruptor de silencio activado, AI CAT sigue hablando (contenido hablado); la voz se apaga desde la zona de padres.
- Visual: el suelo de cada mundo tiene textura (pasto, madera, piedra, metal, arena, alfombra, azulejo) con relieve; el gato tiene pelaje con brillo y una sombra suave bajo las patas; hay una luz de contorno fría; el cielo muestra sol y nubes suaves.
