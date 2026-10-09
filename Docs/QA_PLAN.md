# Plan de QA manual en la Mac

Guion para la primera sesión con Xcode: cada bloque dice qué tocar y qué debe pasar. Idioma: prueba todo una vez en español y una vez en inglés (zona de padres → idioma). Dispositivo de referencia: iPhone 17 (simulador) y, con Xcode 27.1, iPhone Duo en Device Hub (poses cerrado, abierto, mesa y libro).

## 0. Arranque

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
