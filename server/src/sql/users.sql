-- name: CreateUser :exec
INSERT INTO users (username, email, created_at)
VALUES ($1, $2, $3);

-- name: GetUserByEmail :one
select u.id, u.username, u.email, r.level as role_level, u.created_at
from users u
join roles r on r.id = u.role_id
where email = $1;

-- name: GetUserByToken :one
SELECT u.id, u.username, u.email, r.level as role_level, u.created_at
FROM users u
JOIN auth_tokens t ON t.user_id = u.id
JOIN roles r ON r.id = u.role_id
WHERE t.hash = $1;

-- name: GetUserBySession :one
SELECT u.id, u.username, u.email, r.level as role_level, u.created_at
FROM users u
JOIN sessions s ON s.user_id = u.id
JOIN roles r ON r.id = u.role_id
WHERE s.id = $1 AND s.expires_at > $2;
