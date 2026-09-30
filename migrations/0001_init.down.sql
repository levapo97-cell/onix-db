-- Reversa de 0001_init. Borra todo el esquema base.
-- Orden inverso por dependencias (o CASCADE). Idempotente con IF EXISTS.

BEGIN;

DROP TABLE IF EXISTS exports               CASCADE;
DROP TABLE IF EXISTS messages              CASCADE;
DROP TABLE IF EXISTS reports               CASCADE;
DROP TABLE IF EXISTS credentials_detected  CASCADE;
DROP TABLE IF EXISTS alerts                CASCADE;
DROP TABLE IF EXISTS tool_calls            CASCADE;
DROP TABLE IF EXISTS events                CASCADE;
DROP TABLE IF EXISTS sessions              CASCADE;
DROP TABLE IF EXISTS agents                CASCADE;
DROP TABLE IF EXISTS stages                CASCADE;
DROP TABLE IF EXISTS projects              CASCADE;

COMMIT;
