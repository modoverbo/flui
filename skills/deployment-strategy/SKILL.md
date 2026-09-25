---
name: deployment-strategy
description: "Disparador: despliegue, hosting, Vercel, Netlify, Cloudflare, cuota, migración. Elige y opera plataformas con coste controlado."
license: Apache-2.0
metadata:
  author: "gentleman-programming"
  version: "1.0"
---

## Activation Contract / Contrato de activación

Usa esta skill antes de desplegar o cambiar proveedor. Consulta documentación oficial vigente, no precios recordados.

## Hard Rules / Reglas estrictas

- Verifica uso comercial, cuota, pausa, retención, límites de runtime, observabilidad y exportación de datos.
- No vincules la lógica de dominio a la plataforma de despliegue.
- No declares una plataforma “gratis” sin límites y condiciones verificadas.
- Un servidor doméstico requiere operador, parches, respaldo, monitorización, red segura y recuperación.

## Decision Gates / Puertas de decisión

| Caso | Estrategia |
| --- | --- |
| Contenido o SPA | Hosting estático y CDN gratuitos. |
| Datos y autenticación | BaaS con políticas, cuota y exportación evaluadas. |
| Código privilegiado breve | Edge/serverless con límites documentados. |
| Procesos permanentes | Backend dedicado solo con excepción. |
| Crecimiento sostenido | Define disparador de migración antes de sobrepasar cuota. |

## Execution Steps / Pasos de ejecución

1. Compara fuentes oficiales para requisitos y límites actuales.
2. Registra proveedor, región, cuota, alertas, dueño y plan de salida.
3. Automatiza build, preview y rollback sin guardar secretos en repositorio.
4. Configura health checks, logs sin PII y copia/exportación de datos.
5. Revisa cuota antes de lanzamiento y al cruzar cada umbral.

## Output Contract / Contrato de salida

Entrega matriz de proveedores, evidencia oficial, límites, configuración segura, observabilidad y criterios de migración.

## References / Referencias

- `skills/free-first-architecture/SKILL.md`
- `skills/error-handling-observability/SKILL.md`
