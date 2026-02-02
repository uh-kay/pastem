-- name: CreateNewToken :exec
INSERT INTO user_tokens (hash, user_id, expiry, scope)
VALUES ($1, $2, $3, $4);

-- name: DeleteToken :exec
DELETE FROM user_tokens
WHERE scope = $1 AND user_id = $2;
