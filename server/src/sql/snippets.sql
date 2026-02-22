-- name: CreateSnippet :exec
INSERT INTO snippets (author, title, content, expires_at, updated_at, created_at)
VALUES ($1, $2, $3, $4, $5, $6);

-- name: GetSnippets :many
SELECT s.id, s.author as author_id, u.username as author_name, title, content, version, expires_at, s.updated_at, s.created_at
FROM snippets s
INNER JOIN users u ON s.author = u.id
WHERE expires_at > $1 LIMIT $2 OFFSET $3;

-- name: GetSnippet :one
SELECT s.id, s.author as author_id, u.username as author_name, title, content, version, expires_at, s.updated_at, s.created_at
FROM snippets s
INNER JOIN users u ON s.author = u.id
WHERE s.id = $1 AND expires_at > $2;

-- name: UpdateSnippet :exec
UPDATE snippets
SET title = $1, content = $2, version = version + 1
WHERE id = $3 AND version = $4;

-- name: DeleteSnippet :exec
DELETE FROM snippets WHERE id = $1;
