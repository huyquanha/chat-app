-- Added for testing purposes, otherwise the GRANT statement will fail.
-- In production, the role is created and managed by CloudNativePG.
CREATE ROLE user_rpc;

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    username VARCHAR(50) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE users TO user_rpc;

