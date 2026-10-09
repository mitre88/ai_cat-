# Bitácora de hitos

Resumen legible de lo que se construyó, por hito. El detalle está en `git log`.

| Hito | Qué entrega |
|---|---|
| M0–M2 | Proyecto Xcode escrito a mano (+ `project.yml` de respaldo), Info.plist, manifiesto de privacidad, catálogos de cadenas ES/EN, núcleo `AICatCore` (currículo de 10 mundos, crecimiento, dificultad adaptativa, puntuación, aprendices), app 2D (mapa, onboarding, zona de padres con puerta parental, voz, guion). |
| M3–M5 | Mundo 3D en RealityKit (luz con sombras, cámara, gato procedural que respira, parpadea, camina y crece), escenario 1 (frutas con física + árbol de decisión de un nivel) y escenario 2 (etiquetado + k-NN). |
| M6–M7 | iPhone Duo (posturas por bisagra y regiones, `ArrangementView`, amanecer con el ángulo), Foundation Models con filtro kid-safe y modo creativo opt-in, cielo IBL, partículas, slot USDZ, GDD y pipeline de arte. |
| V1–V3 | Verificación en Linux: toolchain Swift 6.1 extraído de la imagen oficial, `swift test`, `swiftc -parse` de toda la app y typecheck completo contra marcos sombra (simd, UIKit, SwiftUI, RealityKit). |
| M8 | Escenarios 3 (umbral, recta, centroides, atípicos) y 4 (bloques con SI y REPETIR, caminata 3D). |
| M9 | Escenarios 5 (Q-learning tabular visible, el niño diseña el laberinto) y 6 (neuronas ternarias por perillas, dos capas, red sigmoide que se entrena sola). |
| M10 | Escenarios 9 (grupo faltante, balanza, privacidad, juez) y 10 (gramática generativa o modelo on-device, remezcla, ayudante, graduación). |
| M11 | Escenarios 7 (píxeles, bordes por umbral, formas, cámara con Vision) y 8 (tokens, bigramas, voz on-device, conversación con errores plantados), permisos localizados y puerta parental antes de cámara y micrófono. |
| M12 | Accesibilidad (VoiceOver en controles con emoji), script de humo para Mac, tabla de riesgos del primer build. |
| Endurecimiento | Paridad de especificadores `%lld`/`%@` entre idiomas en el validador, decoración procedural de los 10 mundos, CI en GitHub Actions (Linux + macOS), referencia Python con valores dorados para Q-learning, red neuronal y gramática, reporte de progreso por mundo para padres, plan de QA manual, APIs verificadas contra la referencia de Apple, AI CAT habla si el niño se queda quieto, filtro kid-safe en el núcleo con pruebas. |

## Cómo verificar

- Linux o CI: `python3 Tools/validate_project.py` y `Tools/verify_linux.sh`.
- Mac: `Tools/xcode_smoke.sh` (Xcode 27.1) o `Tools/xcode_smoke.sh --no-duo` (Xcode 26), luego `Docs/QA_PLAN.md`.
