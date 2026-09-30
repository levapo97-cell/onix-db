-- OnixGuard — migración base (0001).
-- Crea el esquema completo del §3 del plan. Estilo golang-migrate (up/down).
-- Enums implementados como TEXT + CHECK (flexibles de migrar; los valores coinciden con onix-contracts).
-- Todos los id = uuid; todos los timestamps = timestamptz.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- gen_random_uuid()

-- ─────────────────────────────────────────────────────────────
-- projects: cada proyecto monitoreado por el equipo de agentes.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE projects (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name        text NOT NULL,
    status      text NOT NULL DEFAULT 'activo'
                  CHECK (status IN ('activo', 'pausado', 'cerrado')),
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────
-- stages: el plan de 12 etapas de cada proyecto.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE stages (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id  uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    number      int  NOT NULL CHECK (number BETWEEN 1 AND 12),
    name        text NOT NULL,
    status      text NOT NULL DEFAULT 'pendiente'
                  CHECK (status IN ('pendiente', 'activa', 'hecha')),
    started_at  timestamptz,
    ended_at    timestamptz,
    UNIQUE (project_id, number)
);

-- ─────────────────────────────────────────────────────────────
-- agents: 1 por skill/rol, auto-registrado en SessionStart.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE agents (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id    uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    role          text NOT NULL
                    CHECK (role IN ('project_lead', 'fullstack', 'designer', 'growth', 'sales', 'gm')),
    display_name  text,
    avatar_key    text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (project_id, role)
);

-- ─────────────────────────────────────────────────────────────
-- sessions: una sesión de Claude Code, auto-registrada en SessionStart.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE sessions (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id           uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    project_id         uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    claude_session_id  text NOT NULL UNIQUE,
    status             text NOT NULL DEFAULT 'activa'
                         CHECK (status IN ('activa', 'pausada', 'cerrada')),
    started_at         timestamptz NOT NULL DEFAULT now(),
    ended_at           timestamptz
);

-- ─────────────────────────────────────────────────────────────
-- events: cada acción del agente (tool call, error, reporte...).
-- Denormaliza project_id, agent_id y stage_id para filtros rápidos de Logs/vivo.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE events (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id     uuid NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    project_id     uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    agent_id       uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    stage_id       uuid REFERENCES stages(id) ON DELETE SET NULL,
    ts             timestamptz NOT NULL,
    type           text NOT NULL
                     CHECK (type IN ('tool', 'error', 'repeticion', 'credencial', 'tarea', 'reporte', 'nota')),
    tool           text,
    summary        text,
    duration_ms    int,
    tokens         int,
    cost_usd       numeric(12,6),
    is_error       boolean NOT NULL DEFAULT false,
    is_repetition  boolean NOT NULL DEFAULT false
);

-- ─────────────────────────────────────────────────────────────
-- tool_calls: detalle de la tool para la regla de repetición.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE tool_calls (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id           uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    tool               text NOT NULL,
    params_normalized  jsonb,
    params_hash        text,
    exit_code          int,
    duration_ms        int
);

-- ─────────────────────────────────────────────────────────────
-- alerts: error / repetición / ineficiencia que se ven en el panel.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE alerts (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  uuid REFERENCES sessions(id) ON DELETE CASCADE,
    stage_id    uuid REFERENCES stages(id) ON DELETE SET NULL,
    type        text NOT NULL
                  CHECK (type IN ('error', 'repeticion', 'ineficiencia')),
    severity    text NOT NULL DEFAULT 'media'
                  CHECK (severity IN ('baja', 'media', 'alta')),
    message     text,
    ts          timestamptz NOT NULL DEFAULT now(),
    resolved    boolean NOT NULL DEFAULT false
);

-- ─────────────────────────────────────────────────────────────
-- credentials_detected: SOLO el hash del secreto, jamás el valor.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE credentials_detected (
    id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id  uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    kind      text NOT NULL
                CHECK (kind IN ('api_key', 'token', 'password', 'conn_string', 'env')),
    sha256    text NOT NULL,
    label     text,
    ts        timestamptz NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────
-- reports: el reporte de cierre de etapa / petición al jefe.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE reports (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id    uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    stage_id      uuid REFERENCES stages(id) ON DELETE SET NULL,
    agent_id      uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    title         text NOT NULL,
    status        text NOT NULL DEFAULT 'espera'
                    CHECK (status IN ('espera', 'aprobado', 'cambios', 'respondido')),
    summary       text,
    deliverables  jsonb,
    decisions     jsonb,
    tokens        int,
    cost_usd      numeric(12,6),
    errors        int,
    repetitions   int,
    created_at    timestamptz NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────
-- messages: el chat de la pantalla Reportes (jefe ↔ agente).
-- ─────────────────────────────────────────────────────────────
CREATE TABLE messages (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id   uuid NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    sender      text NOT NULL CHECK (sender IN ('jefe', 'agente')),
    body        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────
-- exports: exportaciones para análisis (JSONL/CSV).
-- ─────────────────────────────────────────────────────────────
CREATE TABLE exports (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id  uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    scope       text NOT NULL CHECK (scope IN ('todas', 'etapa_actual')),
    format      text NOT NULL CHECK (format IN ('jsonl', 'csv')),
    path        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────
-- Índices (filtros de Logs + empuje en vivo).
-- ─────────────────────────────────────────────────────────────
CREATE INDEX idx_events_project_ts ON events (project_id, ts DESC);
CREATE INDEX idx_events_agent_ts   ON events (agent_id, ts DESC);
CREATE INDEX idx_events_stage_ts   ON events (stage_id, ts DESC);
CREATE INDEX idx_events_type_ts    ON events (type, ts DESC);
CREATE INDEX idx_events_tool       ON events (tool);
CREATE INDEX idx_tool_calls_hash   ON tool_calls (params_hash);
CREATE INDEX idx_cred_sha256       ON credentials_detected (sha256);
CREATE INDEX idx_reports_status    ON reports (status, created_at DESC);

COMMIT;
