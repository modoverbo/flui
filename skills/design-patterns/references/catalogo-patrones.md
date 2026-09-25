# Catálogo de patrones profesionales

Cada selección exige: problema, fuerzas, beneficio, coste, señales de mal uso, cuándo no usar y alternativa simple.

## GoF creacionales

| Patrón | Problema | Alternativa simple |
| --- | --- | --- |
| Factory Method | variar creación | constructor directo |
| Abstract Factory | familias compatibles | factory única |
| Builder | construcción con muchos pasos | objeto de opciones |
| Prototype | clonar configuración costosa | constructor explícito |
| Singleton | recurso único controlado | inyección de dependencia |

## GoF estructurales

| Patrón | Problema | Alternativa simple |
| --- | --- | --- |
| Adapter | contrato incompatible | traducción local |
| Bridge | dos dimensiones de variación | composición directa |
| Composite | tratar árbol y hoja igual | recorrido explícito |
| Decorator | añadir conducta apilable | función envolvente |
| Facade | simplificar subsistema | módulo de aplicación |
| Flyweight | repetir estado inmutable | caché medida |
| Proxy | controlar acceso | servicio explícito |

## GoF de comportamiento

| Patrón | Problema | Alternativa simple |
| --- | --- | --- |
| Chain of Responsibility | pipeline extensible | función secuencial |
| Command | representar acción | función/callback |
| Interpreter | gramática pequeña | parser existente |
| Iterator | recorrer sin exponer estructura | bucle nativo |
| Mediator | demasiadas dependencias entre pares | composición raíz |
| Memento | restaurar estado | snapshot simple |
| Observer | notificar suscriptores | callback único |
| State | conducta según estado | unión discriminada |
| Strategy | algoritmo intercambiable | condicional pequeño |
| Template Method | esqueleto con pasos variables | función de orden superior |
| Visitor | operación sobre jerarquía estable | switch localizado |

## Patrones de empresa, integración y datos

Repository, Unit of Work, DTO, Value Object, Specification, Service Layer, CQRS, Event Sourcing, Outbox, Saga, Anti-Corruption Layer, Strangler Fig, API Gateway, BFF, Circuit Breaker, Retry con jitter, Bulkhead, Rate Limiting, Cache-Aside, Idempotency Key y Dead Letter Queue se justifican solo ante fronteras, consistencia, volumen o fallos demostrados.

## Concurrencia y sistemas distribuidos

Actor, Worker Pool, Producer-Consumer, Leader Election, Sharding, Read Replica, Consistent Hashing y Backpressure requieren medir contención, latencia, consistencia y coste operativo. En una validación MVP, preferir proceso único, cola gestionada o una operación síncrona antes de distribuir.
