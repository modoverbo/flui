---
name: design-patterns
description: "Disparador: patrón de diseño, GoF, integración, resiliencia, sistema distribuido. Selecciona patrones por problema y coste."
license: Apache-2.0
metadata:
  author: "gentleman-programming"
  version: "1.0"
---

## Activation Contract / Contrato de activación

Usa esta skill cuando un comportamiento recurrente necesita una colaboración explícita entre objetos, módulos o servicios. No la uses para añadir nombres de patrones sin presión de diseño real.

## Hard Rules / Reglas estrictas

- Empieza por el problema, sus fuerzas y la alternativa más simple; el patrón es la consecuencia.
- No uses herencia cuando composición resuelva el cambio con menor rigidez.
- No introduzcas distribuido, colas, CQRS, event sourcing o sagas sin necesidad de escala, consistencia o autonomía demostrada.
- Un patrón debe reducir acoplamiento o clarificar responsabilidades; si solo añade indirección, elimínalo.

## Decision Gates / Puertas de decisión

| Problema | Patrón candidato | Coste a validar |
| --- | --- | --- |
| Algoritmo intercambiable | Strategy | Más tipos y selección explícita. |
| API externa incompatible | Adapter / Anti-Corruption Layer | Traducción y mantenimiento de contrato. |
| Construcción compleja | Builder / Factory | Abstracción innecesaria si hay pocos casos. |
| Eventos dentro de un límite | Observer / Command | Orden, errores e idempotencia. |
| Fallos transitorios remotos | Retry, Circuit Breaker, Bulkhead | Latencia, carga y observabilidad. |
| Consistencia entre servicios | Outbox, Saga, idempotencia | Complejidad operacional y compensación. |

## Execution Steps / Pasos de ejecución

1. Describe el problema sin nombrar un patrón.
2. Enumera fuerzas, invariantes, cambios esperados y alternativa simple.
3. Selecciona el patrón mínimo y define colaboradores y contratos.
4. Prueba el comportamiento observable y sus fallos.
5. Documenta beneficio, coste, señales de mal uso y criterio para retirarlo.

## Output Contract / Contrato de salida

Para cada decisión entrega problema, patrón, alternativa simple, beneficios, costes, límites y pruebas requeridas.

## References / Referencias

- eferences/catalogo-patrones.md — catálogo de familias y alternativas.

- `AGENTS.md` — catálogo GoF y arquitecturas.
- `skills/software-architecture/SKILL.md` — límites y dirección de dependencias.
