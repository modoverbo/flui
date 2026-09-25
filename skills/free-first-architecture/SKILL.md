---
name: free-first-architecture
description: "Disparador: coste, hosting, backend, proveedor, free tier. Decide infraestructura con estrategia gratuita obligatoria."
license: Apache-2.0
metadata:
  author: "gentleman-programming"
  version: "1.0"
---

## Activation Contract / Contrato de activación

Usa esta skill al elegir infraestructura, proveedor, backend o coste operativo. La estrategia *free-first* es obligatoria para validación de ideas.

## Hard Rules / Reglas estrictas

- Agota el nivel inferior de la escalera antes de subir.
- Un servicio pagado, backend dedicado o autoalojamiento exige excepción escrita y aprobada.
- No confundas precio cero con coste cero: incluye operación, seguridad, copias, fiabilidad y tiempo humano.
- Verifica condiciones vigentes, cuota, pausa, retención y uso comercial desde fuentes oficiales antes de elegir proveedor.

## Decision Gates / Puertas de decisión

| Necesidad probada | Nivel permitido |
| --- | --- |
| Landing, contenido, demo o datos ficticios | Estático, local o PWA. |
| Datos, auth o archivos con políticas claras | BaaS gratuito gestionado. |
| Secreto, webhook o operación breve privilegiada | Función edge/serverless. |
| Proceso duradero, trabajo largo o integración privada compleja | Backend dedicado con excepción. |
| Control total con operador disponible | Autoalojamiento con plan operativo. |

## Execution Steps / Pasos de ejecución

1. Define la hipótesis y el requisito que no puede cumplir el nivel actual.
2. Compara la opción más simple y gratuita con sus límites verificables.
3. Si escalas, registra excepción: requisito, alternativas descartadas, coste, operador, seguridad, respaldo y salida/migración.
4. Aísla SDK y proveedor detrás de un adaptador y conserva exportación de datos.
5. Revisa cuota y coste antes de lanzamiento y ante crecimiento.

## Output Contract / Contrato de salida

Entrega nivel seleccionado, evidencia, límites, coste total, riesgos, excepción si aplica y disparadores de migración.

## References / Referencias

- `skills/backendless-apps/SKILL.md` — opciones sin backend dedicado.
- `skills/deployment-strategy/SKILL.md` — verificación de proveedores y operación.
