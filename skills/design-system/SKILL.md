---
name: design-system
description: "Disparador: sistema de diseño, tokens, componentes, temas, variantes. Construye consistencia visual escalable."
license: Apache-2.0
metadata:
  author: "gentleman-programming"
  version: "1.0"
---

## Activation Contract / Contrato de activación

Usa esta skill al crear componentes reutilizables, definir identidad visual o corregir inconsistencia entre pantallas.

## Hard Rules / Reglas estrictas

- Usa tokens semánticos; prohíbe colores, espacios y radios ad-hoc en features.
- Un componente expone intención y composición, no una explosión de booleanos.
- Diseña todos los estados: base, hover, foco, deshabilitado, carga, error y vacío cuando aplique.
- Accesibilidad y contraste son parte del contrato visual.

## Decision Gates / Puertas de decisión

| Necesidad | Decisión |
| --- | --- |
| Valor visual repetido | Token semántico. |
| Patrón repetido con conducta estable | Componente base. |
| Variación de estructura | Composición o slot, no flag. |
| Variación de marca/tema | Tokens por tema, no estilos duplicados. |

## Execution Steps / Pasos de ejecución

1. Define fundamentos: color, tipografía, espacio, elevación y movimiento.
2. Nombra tokens por propósito, no por valor literal.
3. Define API mínima, estados y criterios de accesibilidad de cada componente.
4. Documenta ejemplos y anti-patrones; revisa consistencia visual antes de ampliar catálogo.

## Output Contract / Contrato de salida

Entrega tokens, contrato de componentes, estados, reglas de composición y plan de adopción.

## References / Referencias

- `skills/ui-design/SKILL.md`
- `skills/accessibility/SKILL.md`
