-- name: CreateNewToken :exec
INSERT INTO auth_tokens (hash, user_id, expiry)
VALUES ($1, $2, $3);

-- name: DeleteToken :exec
DELETE FROM auth_tokens
WHERE user_id = $1;
