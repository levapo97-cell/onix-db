-- Reversa de 0002.
BEGIN;

ALTER TABLE reports DROP COLUMN IF EXISTS ticket_id;

DROP INDEX IF EXISTS stages_ticket_number;
ALTER TABLE stages DROP COLUMN IF EXISTS depends_on;
ALTER TABLE stages DROP COLUMN IF EXISTS description;
ALTER TABLE stages DROP COLUMN IF EXISTS ticket_id;
-- Restaura (best-effort) las restricciones originales de 0001.
ALTER TABLE stages ADD CONSTRAINT stages_number_check CHECK (number BETWEEN 1 AND 12);
ALTER TABLE stages ADD CONSTRAINT stages_project_id_number_key UNIQUE (project_id, number);

DROP TABLE IF EXISTS tickets CASCADE;

COMMIT;
