---
name: software-architecture
description: "Disparador: arquitectura de software, Clean Architecture, Hexagonal, límites, ADR. Diseña dependencias y módulos mantenibles."
license: Apache-2.0
metadata:
  author: "gentleman-programming"
  version: "1.0"
---

## Activation Contract / Contrato de activación

Usa esta skill al crear un sistema, módulo, integración o cambio que altere dependencias públicas. Lee primero las skills del dominio afectado.

## Hard Rules / Reglas estrictas

- Minimiza el acoplamiento innecesario; no prometas acoplamiento cero.
- Mantén una responsabilidad y una razón de cambio por módulo.
- El dominio y los casos de uso no importan framework, base de datos, SDK ni transporte.
- Invierte dependencias en fronteras volátiles mediante puertos; los adaptadores implementan esos puertos.
- No agregues capas, eventos o patrones sin un problema y una alternativa simple evaluada.

## Decision Gates / Puertas de decisión

| Situación | Decisión |
| --- | --- |
| Regla estable de negocio | Entidad, value object o caso de uso independiente de infraestructura. |
| Servicio externo o proveedor | Puerto propio y adaptador anticorrupción. |
| Dos módulos cambian juntos por el mismo motivo | Colócalos juntos por capacidad. |
| Dependencia cruza una capacidad de negocio | Expón un contrato pequeño o comunica mediante evento. |
| Cambio con consecuencias duraderas | Registra un ADR con contexto, decisión, alternativas y consecuencias. |

## Execution Steps / Pasos de ejecución

1. Nombra la capacidad, sus actores y el flujo principal.
2. Dibuja dependencias: solo pueden apuntar hacia política estable.
3. Define puertos con lenguaje de dominio, no con nombres de proveedor.
4. Implementa adaptadores en el borde y compónlos en el punto de arranque.
5. Prueba los casos de uso con dobles de los puertos; prueba adaptadores en su frontera real.

## Output Contract / Contrato de salida

Entrega límites, dirección de dependencias, puertos, adaptadores, riesgos y un ADR cuando corresponda. Explica la alternativa más simple descartada.

## References / Referencias

- `AGENTS.md` — principios SOLID y Clean Architecture.
- `skills/frontend-architecture/SKILL.md` — aplicación de estos límites en cliente.
