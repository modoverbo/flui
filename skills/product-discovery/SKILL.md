---
name: product-discovery
description: "Disparador: MVP, hipótesis, validación, experimento, métrica. Reduce alcance para aprender antes de construir."
license: Apache-2.0
metadata:
  author: "gentleman-programming"
  version: "1.0"
---

## Activation Contract / Contrato de activación

Usa esta skill antes de crear una funcionalidad nueva, elegir infraestructura o ampliar el alcance de un MVP.

## Hard Rules / Reglas estrictas

- Un MVP prueba una hipótesis, no una lista de funcionalidades.
- No construyas automatización, roles, integraciones o escalabilidad sin evidencia de aprendizaje que lo requiera.
- Define métrica, umbral y fecha de decisión antes del experimento.
- Diferencia señal de vanidad de comportamiento que cambiaría la decisión.

## Decision Gates / Puertas de decisión

| Pregunta | Acción |
| --- | --- |
| ¿Quién tiene el problema y con qué frecuencia? | Define usuario, contexto y dolor observable. |
| ¿Qué debe ser cierto para continuar? | Formula una hipótesis falsable. |
| ¿Cuál es la prueba más barata? | Elige prototipo, landing, entrevista, prueba manual o flujo mínimo. |
| ¿Qué resultado cambia el rumbo? | Fija métrica, umbral, ventana y responsable. |

## Execution Steps / Pasos de ejecución

1. Escribe problema, usuario y resultado deseado.
2. Formula hipótesis: “creemos que…; sabremos que… cuando…”.
3. Elimina todo elemento que no produzca aprendizaje.
4. Define experimento, métrica, umbral y fecha de revisión.
5. Decide perseverar, iterar o detener con evidencia registrada.

## Output Contract / Contrato de salida

Entrega hipótesis, experimento mínimo, métrica, umbral, riesgos y alcance explícitamente excluido.

## References / Referencias

- `skills/free-first-architecture/SKILL.md`
- `skills/ux-design/SKILL.md`
