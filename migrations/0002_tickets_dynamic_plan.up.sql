-- OnixGuard — migración 0002: tickets + plan de ejecución DINÁMICO por ticket.
-- Cambia el modelo: las "etapas" dejan de ser 12 fijas por proyecto y pasan a ser
-- las fases del plan que el agente genera para un ticket (N fases, con dependencias).

BEGIN;

-- ─────────────── tickets ───────────────
CREATE TABLE tickets (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id      uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    source          text NOT NULL DEFAULT 'plataforma'
                      CHECK (source IN ('plataforma', 'archivo', 'subida', 'externo')),
    title           text NOT NULL,
    body            text,
    attachment_path text,
    status          text NOT NULL DEFAULT 'nuevo'
                      CHECK (status IN ('nuevo', 'en_plan', 'plan_espera', 'aprobado', 'en_curso', 'hecho', 'cancelado')),
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_tickets_project ON tickets (project_id, created_at DESC);

-- ─────────────── stages: plan dinámico por ticket ───────────────
ALTER TABLE stages ADD COLUMN ticket_id   uuid REFERENCES tickets(id) ON DELETE CASCADE;
ALTER TABLE stages ADD COLUMN description text;
ALTER TABLE stages ADD COLUMN depends_on  int;  -- número de fase de la que depende (opcional)

-- Quitar el tope de 12 y la unicidad por proyecto (ahora es por ticket).
ALTER TABLE stages DROP CONSTRAINT IF EXISTS stages_number_check;
ALTER TABLE stages DROP CONSTRAINT IF EXISTS stages_project_id_number_key;
CREATE UNIQUE INDEX IF NOT EXISTS stages_ticket_number ON stages (ticket_id, number) WHERE ticket_id IS NOT NULL;

-- Enlazar reportes a su ticket (p. ej. el reporte "Plan de ejecución").
ALTER TABLE reports ADD COLUMN ticket_id uuid REFERENCES tickets(id) ON DELETE SET NULL;

COMMIT;
