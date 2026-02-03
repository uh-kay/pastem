-- name: CreateSnippet :exec
INSERT INTO snippets (author, title, content, expires_at, updated_at, created_at)
VALUES ($1, $2, $3, $4, $5, $6);

-- name: GetSnippets :many
SELECT id, author, title, content, expires_at, updated_at, created_at from snippets
limit $1 offset $2;

-- name: GetSnippet :one
SELECT id, author, title, content, expires_at, updated_at, created_at
FROM snippets
WHERE id = $1;

-- name: UpdateSnippet :exec
UPDATE snippets
SET title = COALESCE($1, title), content = COALESCE($2, content)
WHERE id = $3;

-- name: DeleteSnippet :exec
DELETE from snippets where id = $1;
