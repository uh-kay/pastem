-- name: CreateUser :exec
INSERT INTO users (username, email, password_hash, created_at)
VALUES ($1, $2, $3, $4);

-- name: GetUserByEmail :one
select u.id, u.username, u.email, u.password_hash, r.level as role_level, u.created_at
from users u
join roles r on r.id = u.role_id
where email = $1;

-- name: GetUserByToken :one
SELECT u.id, u.username, u.email, u.password_hash, r.level as role_level, u.created_at
FROM users u
JOIN user_tokens t ON t.user_id = u.id
JOIN roles r ON r.id = u.role_id
WHERE t.hash = $1;
