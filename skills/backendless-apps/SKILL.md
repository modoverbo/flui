---
name: backendless-apps
description: "Disparador: sin backend, BaaS, PWA, Supabase, RLS, edge function. Diseña validaciones seguras sin servidor dedicado."
license: Apache-2.0
metadata:
  author: "gentleman-programming"
  version: "1.0"
---

## Activation Contract / Contrato de activación

Usa esta skill al validar una app con frontend, almacenamiento local, PWA, BaaS o funciones edge. Carga `free-first-architecture`, `security` y `database-design` cuando haya datos reales.

## Hard Rules / Reglas estrictas

- Empieza por estático, datos falsos o almacenamiento local si permiten aprender.
- No envíes secretos, claves de servicio ni cadenas de conexión al navegador.
- Toda tabla accesible desde cliente usa RLS o una política equivalente de mínimo privilegio.
- Una función edge es breve, sin estado y con timeout; no la conviertas en backend permanente.
- Mantén SDK y consultas del proveedor en un adaptador de infraestructura.

## Decision Gates / Puertas de decisión

| Necesidad | Opción |
| --- | --- |
| Demo, contenido o flujo validable | Sitio estático y datos falsos. |
| Trabajo offline o instalación | PWA y almacenamiento local. |
| Usuarios, datos o archivos compartidos | BaaS gestionado con RLS. |
| Webhook, secreto o acción privilegiada | Función edge/serverless. |
| Proceso duradero o cómputo pesado | Escalar mediante excepción `free-first`. |

## Execution Steps / Pasos de ejecución

1. Define qué aprendizaje requiere persistencia real.
2. Diseña tablas y políticas antes de exponer el cliente.
3. Modela acceso por usuario, rol y recurso; prueba denegación y pertenencia.
4. Encapsula SDK, errores y transformaciones detrás de puertos.
5. Documenta límites, exportación de datos y condición de salida del proveedor.

## Output Contract / Contrato de salida

Entrega nivel elegido, modelo de permisos, adaptadores, secretos protegidos y disparador para backend dedicado.

## References / Referencias

- `skills/free-first-architecture/SKILL.md`
- `skills/security/SKILL.md`
