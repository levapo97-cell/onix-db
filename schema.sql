-- OnixGuard — schema.sql (REFERENCIA CONSOLIDADA)
-- Este archivo NO se aplica en producción: las migraciones de migrations/ son la fuente de verdad.
-- Sirve como vista consolidada del esquema actual. Regenerar con:
--   pg_dump --schema-only --no-owner --no-privileges "$DATABASE_URL" > schema.sql
-- Estado: refleja 0001_init.
--
-- Tablas: projects, stages, agents, sessions, events, tool_calls,
--         alerts, credentials_detected, reports, messages, exports.
-- Convenciones: id = uuid (gen_random_uuid); timestamps = timestamptz; enums = TEXT + CHECK.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE projects (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name        text NOT NULL,
    status      text NOT NULL DEFAULT 'activo' CHECK (status IN ('activo','pausado','cerrado')),
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE stages (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id  uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    number      int  NOT NULL CHECK (number BETWEEN 1 AND 12),
    name        text NOT NULL,
    status      text NOT NULL DEFAULT 'pendiente' CHECK (status IN ('pendiente','activa','hecha')),
    started_at  timestamptz,
    ended_at    timestamptz,
    UNIQUE (project_id, number)
);

CREATE TABLE agents (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id    uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    role          text NOT NULL CHECK (role IN ('project_lead','fullstack','designer','growth','sales','gm')),
    display_name  text,
    avatar_key    text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (project_id, role)
);

CREATE TABLE sessions (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id           uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    project_id         uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    claude_session_id  text NOT NULL UNIQUE,
    status             text NOT NULL DEFAULT 'activa' CHECK (status IN ('activa','pausada','cerrada')),
    started_at         timestamptz NOT NULL DEFAULT now(),
    ended_at           timestamptz
);

CREATE TABLE events (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id     uuid NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    project_id     uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    agent_id       uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    stage_id       uuid REFERENCES stages(id) ON DELETE SET NULL,
    ts             timestamptz NOT NULL,
    type           text NOT NULL CHECK (type IN ('tool','error','repeticion','credencial','tarea','reporte','nota')),
    tool           text,
    summary        text,
    duration_ms    int,
    tokens         int,
    cost_usd       numeric(12,6),
    is_error       boolean NOT NULL DEFAULT false,
    is_repetition  boolean NOT NULL DEFAULT false
);

CREATE TABLE tool_calls (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id           uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    tool               text NOT NULL,
    params_normalized  jsonb,
    params_hash        text,
    exit_code          int,
    duration_ms        int
);

CREATE TABLE alerts (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  uuid REFERENCES sessions(id) ON DELETE CASCADE,
    stage_id    uuid REFERENCES stages(id) ON DELETE SET NULL,
    type        text NOT NULL CHECK (type IN ('error','repeticion','ineficiencia')),
    severity    text NOT NULL DEFAULT 'media' CHECK (severity IN ('baja','media','alta')),
    message     text,
    ts          timestamptz NOT NULL DEFAULT now(),
    resolved    boolean NOT NULL DEFAULT false
);

CREATE TABLE credentials_detected (
    id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id  uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    kind      text NOT NULL CHECK (kind IN ('api_key','token','password','conn_string','env')),
    sha256    text NOT NULL,
    label     text,
    ts        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE reports (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id    uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    stage_id      uuid REFERENCES stages(id) ON DELETE SET NULL,
    agent_id      uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    title         text NOT NULL,
    status        text NOT NULL DEFAULT 'espera' CHECK (status IN ('espera','aprobado','cambios','respondido')),
    summary       text,
    deliverables  jsonb,
    decisions     jsonb,
    tokens        int,
    cost_usd      numeric(12,6),
    errors        int,
    repetitions   int,
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE messages (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id   uuid NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    sender      text NOT NULL CHECK (sender IN ('jefe','agente')),
    body        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE exports (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id  uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    scope       text NOT NULL CHECK (scope IN ('todas','etapa_actual')),
    format      text NOT NULL CHECK (format IN ('jsonl','csv')),
    path        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_events_project_ts ON events (project_id, ts DESC);
CREATE INDEX idx_events_agent_ts   ON events (agent_id, ts DESC);
CREATE INDEX idx_events_stage_ts   ON events (stage_id, ts DESC);
CREATE INDEX idx_events_type_ts    ON events (type, ts DESC);
CREATE INDEX idx_events_tool       ON events (tool);
CREATE INDEX idx_tool_calls_hash   ON tool_calls (params_hash);
CREATE INDEX idx_cred_sha256       ON credentials_detected (sha256);
CREATE INDEX idx_reports_status    ON reports (status, created_at DESC);
