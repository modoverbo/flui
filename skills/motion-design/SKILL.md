---
name: motion-design
description: "Disparador: animación, transición, microinteracción, efecto visual. Diseña movimiento útil, accesible y eficiente."
license: Apache-2.0
metadata:
  author: "gentleman-programming"
  version: "1.0"
---

## Activation Contract / Contrato de activación

Usa esta skill al añadir transiciones, animaciones o efectos visuales a una interfaz.

## Hard Rules / Reglas estrictas

- Cada animación comunica causa, cambio de estado, jerarquía o continuidad; decoración sola no justifica coste.
- Respeta `prefers-reduced-motion` con una alternativa estable y sin movimiento esencial.
- No animes propiedades que fuerzan layout cuando `transform` u `opacity` resuelvan el caso.
- Nunca ocultes latencia, errores ni bloqueo de interacción detrás de una animación.

## Decision Gates / Puertas de decisión

| Objetivo | Movimiento |
| --- | --- |
| Confirmar respuesta inmediata | Microinteracción breve. |
| Explicar cambio espacial | Transformación con origen claro. |
| Indicar trabajo en curso | Progreso honesto y cancelable si aplica. |
| Sin propósito verificable | No animar. |

## Execution Steps / Pasos de ejecución

1. Escribe qué entiende el usuario gracias al movimiento.
2. Define inicio, fin, duración, curva y alternativa reducida.
3. Prueba teclado, foco, bajo rendimiento y contenido dinámico.
4. Mide rendimiento y elimina movimiento que perjudique comprensión o respuesta.

## Output Contract / Contrato de salida

Entrega propósito, especificación de movimiento, alternativa reducida y presupuesto de rendimiento.

## References / Referencias

- `skills/design-system/SKILL.md`
- `skills/accessibility/SKILL.md`
