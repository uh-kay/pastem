-- name: CreateSnippet :exec
INSERT INTO snippets (author, title, content, expires_at, updated_at, created_at)
VALUES ($1, $2, $3, $4, $5, $6);

-- name: GetSnippets :many
SELECT id, author, title, content, version, expires_at, updated_at, created_at from snippets
LIMIT $1 OFFSET $2;

-- name: GetSnippet :one
SELECT id, author, title, content, version, expires_at, updated_at, created_at
FROM snippets
WHERE id = $1;

-- name: UpdateSnippet :exec
UPDATE snippets
SET title = $1, content = $2, version = version + 1
WHERE id = $3 AND version = $4;

-- name: DeleteSnippet :exec
DELETE FROM snippets WHERE id = $1;
