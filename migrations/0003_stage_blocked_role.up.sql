-- OnixGuard — migración 0003: pausa en cascada por dependencias (Fase 7).
-- Las fases pueden quedar 'bloqueada' cuando la fase de la que dependen está esperando al jefe.
-- Cada fase puede tener un rol asignado (qué agente la trabaja), para pausar su sesión en cascada.

BEGIN;

ALTER TABLE stages DROP CONSTRAINT IF EXISTS stages_status_check;
ALTER TABLE stages ADD CONSTRAINT stages_status_check
    CHECK (status IN ('pendiente', 'activa', 'hecha', 'bloqueada'));

ALTER TABLE stages ADD COLUMN agent_role text;

COMMIT;
