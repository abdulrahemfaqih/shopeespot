-- +goose Up
CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         text NOT NULL,
  password_hash text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX users_email_key ON users (lower(email));

CREATE TABLE refresh_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  family_id  uuid NOT NULL,
  token_hash text NOT NULL UNIQUE,            -- sha256 hex dari token mentah
  expires_at timestamptz NOT NULL,
  rotated_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX refresh_tokens_family_idx ON refresh_tokens (family_id);
CREATE INDEX refresh_tokens_user_idx   ON refresh_tokens (user_id);

CREATE SEQUENCE sync_seq;

CREATE TABLE spots (
  user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  id               uuid NOT NULL,
  name             text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 80),
  category         text NOT NULL CHECK (category IN ('shopeefood','spx')),
  latitude         double precision NOT NULL CHECK (latitude  BETWEEN -90  AND 90),
  longitude        double precision NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  notes            text NOT NULL DEFAULT '' CHECK (char_length(notes) <= 500),
  peak_hours       jsonb NOT NULL DEFAULT '[]',
  last_verified_at timestamptz,
  created_at       timestamptz NOT NULL,
  updated_at       timestamptz NOT NULL,
  deleted_at       timestamptz,
  seq              bigint NOT NULL DEFAULT nextval('sync_seq'),
  PRIMARY KEY (user_id, id)
);
CREATE INDEX spots_user_seq_idx ON spots (user_id, seq);

CREATE TABLE orders (
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  id         uuid NOT NULL,
  spot_id    uuid NOT NULL,                   -- tanpa FK: urutan tiba di batch tidak dijamin
  ordered_at timestamptz NOT NULL,
  local_dow  smallint NOT NULL CHECK (local_dow  BETWEEN 1 AND 7),   -- 1=Senin ... 7=Minggu
  local_hour smallint NOT NULL CHECK (local_hour BETWEEN 0 AND 23),  -- jam lokal saat dicatat
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  deleted_at timestamptz,
  seq        bigint NOT NULL DEFAULT nextval('sync_seq'),
  PRIMARY KEY (user_id, id)
);
CREATE INDEX orders_user_seq_idx ON orders (user_id, seq);

-- +goose Down
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS spots;
DROP SEQUENCE IF EXISTS sync_seq;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS users;
