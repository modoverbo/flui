---
name: visual-quality
description: "Disparador: revisión visual, responsive, regresión visual, interfaz bonita. Verifica jerarquía, estados y consistencia."
license: Apache-2.0
metadata:
  author: "gentleman-programming"
  version: "1.0"
---

## Activation Contract / Contrato de activación

Usa esta skill al terminar una UI, revisar una pantalla o preparar una demo de producto.

## Hard Rules / Reglas estrictas

- Revisa flujo completo, no solo el estado feliz.
- Compara móvil, tablet, escritorio, zoom y contenido corto/largo.
- Verifica contraste, foco, teclado, carga, error, vacío y éxito.
- Separa defecto visual de defecto funcional para priorizar y corregir con claridad.

## Decision Gates / Puertas de decisión

| Hallazgo | Acción |
| --- | --- |
| Jerarquía o siguiente acción confusa | Corregir composición y copy antes de decorar. |
| Desborde o pérdida de contexto responsive | Ajustar layout y probar extremos. |
| Estado async inexistente | Diseñar carga, error, vacío y reintento. |
| Diferencia visual repetida | Corregir sistema de diseño, no parche local. |

## Execution Steps / Pasos de ejecución

1. Captura o inspecciona cada viewport y estado.
2. Evalúa jerarquía, legibilidad, contraste, espaciado y consistencia.
3. Prueba interacción por teclado y movimiento reducido.
4. Registra defectos con evidencia, gravedad y componente responsable.

## Output Contract / Contrato de salida

Entrega lista priorizada de hallazgos, evidencia visual, estados cubiertos y criterios de corrección.

## References / Referencias

- `skills/design-system/SKILL.md`
- `skills/ux-design/SKILL.md`
