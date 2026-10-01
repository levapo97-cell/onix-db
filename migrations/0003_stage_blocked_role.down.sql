BEGIN;
ALTER TABLE stages DROP COLUMN IF EXISTS agent_role;
ALTER TABLE stages DROP CONSTRAINT IF EXISTS stages_status_check;
ALTER TABLE stages ADD CONSTRAINT stages_status_check CHECK (status IN ('pendiente', 'activa', 'hecha'));
COMMIT;
