-- name: CreateSession :one
INSERT INTO sessions (id, user_id, expires_at)
VALUES ($1, $2, $3)
RETURNING id::uuid;

-- name: GetSessionById :one
SELECT id, user_id FROM sessions
WHERE expires_at > $1;
